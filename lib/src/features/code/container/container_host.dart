import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/container/container_image.dart';
import 'package:finn_ai/src/features/code/container/container_protocol.dart';

/// Where the container is in its life.
enum ContainerPhase { stopped, starting, ready, failed }

/// One command's result, before it becomes a `ShellResult`.
class ContainerRun {
  const ContainerRun({
    required this.exitCode,
    required this.output,
    this.truncated = false,
    this.timedOut = false,
    this.tar,
  });

  final int exitCode;
  final String output;
  final bool truncated;
  final bool timedOut;

  /// The project as the container left it; null if it could not be read.
  final Uint8List? tar;
}

class ContainerUnavailable implements Exception {
  const ContainerUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs the Linux container and speaks to it.
///
/// The machine is v86, an x86 emulator compiled to WebAssembly, inside a
/// WebView that nobody sees (`ContainerView`). That WebView loads a page from
/// this host: a loopback HTTP server on a random port, every path behind a
/// random token, serving only the page, the emulator and the downloaded
/// image. The page opens a WebSocket back here and relays the serial console
/// and the shared folder; everything else is decided in Dart.
///
/// The host is lazy. Nothing listens and no WebView exists until a command
/// needs the container, and [stop] tears both down.
class ContainerHost extends ChangeNotifier {
  ContainerHost({
    required this.loadAsset,
    required this.imageDirectory,
    this.bootTimeout = const Duration(seconds: 90),
    this.memoryMb = 128,
  });

  /// Reads a file from `assets/code_container/`.
  final Future<List<int>> Function(String name) loadAsset;

  /// Where the installer put the downloaded image.
  final Future<Directory> Function() imageDirectory;
  final Duration bootTimeout;
  final int memoryMb;

  final _random = Random.secure();
  HttpServer? _server;
  WebSocket? _socket;
  String _token = '';
  ContainerPhase _phase = ContainerPhase.stopped;
  String? _failure;
  Completer<void>? _starting;
  StringBuffer _console = StringBuffer();
  void Function(String chunk)? _consoleListener;
  final Map<String, Completer<Map<String, Object?>>> _replies = {};
  int _nextId = 0;
  Future<void> _queue = Future.value();

  ContainerPhase get phase => _phase;
  String? get failure => _failure;

  /// The page a hidden WebView should load, or null when none is needed.
  Uri? get viewUrl {
    final server = _server;
    if (server == null) return null;
    if (_phase != ContainerPhase.starting && _phase != ContainerPhase.ready) {
      return null;
    }
    return Uri.parse(
        'http://127.0.0.1:${server.port}/$_token/runtime.html#$_token');
  }

  String _nonce() =>
      List.generate(8, (_) => _random.nextInt(36).toRadixString(36)).join();

  /// Boots the machine if it is not running. Completes once a command can
  /// be sent.
  Future<void> start() {
    if (_phase == ContainerPhase.ready) return Future.value();
    final pending = _starting;
    if (pending != null) return pending.future;
    final completer = _starting = Completer<void>();
    unawaited(_boot().then((_) {
      completer.complete();
    }, onError: (Object error) {
      _failure = '$error';
      _phase = ContainerPhase.failed;
      notifyListeners();
      unawaited(_teardown());
      completer.completeError(error);
    }).whenComplete(() => _starting = null));
    return completer.future;
  }

  Future<void> _boot() async {
    _failure = null;
    _console = StringBuffer();
    _token =
        List.generate(24, (_) => _random.nextInt(36).toRadixString(36)).join();
    final server = _server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    final connected = Completer<void>();
    server.listen((request) => _serve(request, connected));
    _phase = ContainerPhase.starting;
    notifyListeners();

    await connected.future.timeout(bootTimeout,
        onTimeout: () => throw const ContainerUnavailable(
            'The container view did not load.'));
    _send({'op': 'boot', 'memoryMb': memoryMb});
    await _waitFor(
      (console) => ContainerProtocol.looksLikePrompt(console),
      bootTimeout,
      settle: const Duration(milliseconds: 400),
    );
    final nonce = _nonce();
    _console = StringBuffer();
    _send({'op': 'send', 'data': ContainerProtocol.initLine(nonce)});
    await _waitFor(
      (console) => console.contains(ContainerProtocol.readyMarker(nonce)),
      const Duration(seconds: 20),
    );
    // The init line made the folder these go in.
    await _put(ContainerProtocol.runScript,
        utf8.encode(ContainerProtocol.runScriptBody));
    await _put(ContainerProtocol.pullScript,
        utf8.encode(ContainerProtocol.pullScriptBody));
    _phase = ContainerPhase.ready;
    notifyListeners();
  }

  Future<void> _serve(HttpRequest request, Completer<void> connected) async {
    final response = request.response;
    // The token is the path's first segment; it is not logged.
    debugPrint('FINN_CONTAINER serve '
        '${request.uri.pathSegments.skip(1).join('/')}');
    try {
      final parts = request.uri.pathSegments;
      // Every path is /<token>/<name>; anything else is not ours to answer.
      if (parts.length != 2 || parts.first != _token) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final name = parts[1];
      if (name == 'socket' && WebSocketTransformer.isUpgradeRequest(request)) {
        if (_socket != null) {
          response.statusCode = HttpStatus.conflict;
          await response.close();
          return;
        }
        final socket = _socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (data) => _onMessage(data, connected),
          onDone: _onSocketClosed,
          cancelOnError: true,
        );
        return;
      }
      final List<int> bytes;
      if (ContainerImage.bundled.contains(name)) {
        bytes = await loadAsset(name);
      } else if (ContainerImage.artifacts.any((a) => a.fileName == name)) {
        final dir = await imageDirectory();
        bytes = await File('${dir.path}/$name').readAsBytes();
      } else {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      response.headers
        ..contentType = _typeOf(name)
        ..set('Cache-Control', 'no-store');
      response.add(bytes);
      await response.close();
    } catch (error) {
      debugPrint('FINN_CONTAINER serve failed: $error');
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {
        // The client went away.
      }
    }
  }

  static ContentType _typeOf(String name) {
    if (name.endsWith('.html')) return ContentType.html;
    if (name.endsWith('.js')) {
      return ContentType('text', 'javascript', charset: 'utf-8');
    }
    if (name.endsWith('.wasm')) return ContentType('application', 'wasm');
    return ContentType.binary;
  }

  void _onMessage(Object? data, Completer<void> connected) {
    if (data is! String) return;
    final Map<String, Object?> message;
    try {
      message = (jsonDecode(data) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    switch (message['ev']) {
      case 'ready':
        debugPrint('FINN_CONTAINER page connected');
        if (!connected.isCompleted) connected.complete();
      case 'out':
        final chunk = '${message['data'] ?? ''}';
        _console.write(chunk);
        _consoleListener?.call(chunk);
      case 'put' || 'file':
        _replies.remove('${message['id']}')?.complete(message);
      case 'error':
        final id = message['id'];
        if (id != null) {
          _replies.remove('$id')?.complete(message);
        } else if (_phase == ContainerPhase.starting) {
          _failure = '${message['message']}';
        }
    }
  }

  void _onSocketClosed() {
    _socket = null;
    for (final reply in _replies.values) {
      if (!reply.isCompleted) {
        reply.completeError(
            const ContainerUnavailable('The container stopped.'));
      }
    }
    _replies.clear();
    if (_phase == ContainerPhase.ready) {
      _phase = ContainerPhase.stopped;
      unawaited(_teardown());
      notifyListeners();
    }
  }

  void _send(Map<String, Object?> message) {
    final socket = _socket;
    if (socket == null) {
      throw const ContainerUnavailable('The container is not running.');
    }
    socket.add(jsonEncode(message));
  }

  Future<Map<String, Object?>> _request(Map<String, Object?> message) {
    final id = '${_nextId++}';
    final completer = _replies[id] = Completer<Map<String, Object?>>();
    _send({...message, 'id': id});
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<void> _put(String path, List<int> bytes) async {
    final reply =
        await _request({'op': 'put', 'path': path, 'b64': base64Encode(bytes)});
    if (reply['error'] != null) {
      throw ContainerUnavailable('Could not share a file: ${reply['error']}');
    }
  }

  Future<Uint8List?> _get(String path) async {
    try {
      final reply = await _request({'op': 'get', 'path': path});
      final b64 = reply['b64'];
      return b64 is String ? base64Decode(b64) : null;
    } catch (_) {
      return null;
    }
  }

  /// Waits until [test] holds for the console, polling; [settle] demands it
  /// still holds that much later (a prompt can be followed by more boot
  /// noise).
  Future<void> _waitFor(
    bool Function(String console) test,
    Duration limit, {
    Duration settle = Duration.zero,
  }) async {
    final deadline = DateTime.now().add(limit);
    while (DateTime.now().isBefore(deadline)) {
      if (_socket == null) {
        throw ContainerUnavailable(_failure ?? 'The container stopped.');
      }
      if (test(_console.toString())) {
        if (settle == Duration.zero) return;
        final length = _console.length;
        await Future<void>.delayed(settle);
        if (_console.length == length && test(_console.toString())) return;
        continue;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw ContainerUnavailable(
        _failure ?? 'The container did not start in time.');
  }

  /// Runs [command] over [projectTar] and returns its output and the
  /// project afterwards. One at a time: a second call waits for the first.
  Future<ContainerRun> run(
    String command, {
    required Uint8List projectTar,
    required Duration timeout,
    int maxOutputBytes = 32 * 1024,
  }) {
    final result = _queue.then((_) =>
        _run(command, projectTar, timeout, maxOutputBytes: maxOutputBytes));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<ContainerRun> _run(
    String command,
    Uint8List projectTar,
    Duration timeout, {
    required int maxOutputBytes,
  }) async {
    await start();
    await _put(ContainerProtocol.inTar, projectTar);
    await _put(ContainerProtocol.commandFile, utf8.encode('$command\n'));
    final nonce = _nonce();
    final capture = SerialCapture(nonce, maxOutputBytes: maxOutputBytes);
    _consoleListener = capture.add;
    _console = StringBuffer();
    try {
      _send({'op': 'send', 'data': ContainerProtocol.runLine(nonce)});
      final deadline = DateTime.now().add(timeout);
      var timedOut = false;
      while (!capture.synced) {
        if (_socket == null) {
          throw const ContainerUnavailable('The container stopped.');
        }
        capture.scan();
        if (capture.synced) break;
        if (!capture.finished && DateTime.now().isAfter(deadline)) {
          timedOut = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      if (timedOut) return await _interrupt(nonce, capture);
      final (:output, :truncated) = capture.output();
      return ContainerRun(
        exitCode: capture.exitCode ?? 1,
        output: output,
        truncated: truncated,
        tar: await _get(ContainerProtocol.outTar),
      );
    } finally {
      _consoleListener = null;
    }
  }

  /// Stops a command that ran out of time, then brings the project back as
  /// it was when it stopped. If the console does not answer, the machine is
  /// restarted and the project is taken from the device as it was before.
  Future<ContainerRun> _interrupt(String nonce, SerialCapture capture) async {
    final (:output, :truncated) = capture.output();
    _send({'op': 'send', 'data': ContainerProtocol.interrupt});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final pull = _nonce();
    _console = StringBuffer();
    _send({'op': 'send', 'data': ContainerProtocol.pullLine(pull)});
    Uint8List? tar;
    try {
      await _waitFor(
        (console) => console.contains(ContainerProtocol.syncedMarker(pull)),
        const Duration(seconds: 8),
      );
      tar = await _get(ContainerProtocol.outTar);
    } on ContainerUnavailable {
      await restart();
    }
    return ContainerRun(
      exitCode: 124,
      output: output,
      truncated: truncated,
      timedOut: true,
      tar: tar,
    );
  }

  /// Reboots the machine. The project is safe: it lives on the device.
  Future<void> restart() async {
    await _teardown();
    _phase = ContainerPhase.stopped;
    notifyListeners();
  }

  /// Shuts the machine down and closes the server.
  Future<void> stop() => restart();

  Future<void> _teardown() async {
    final socket = _socket;
    _socket = null;
    final server = _server;
    _server = null;
    try {
      await socket?.close();
    } catch (_) {}
    try {
      await server?.close(force: true);
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_teardown());
    super.dispose();
  }
}

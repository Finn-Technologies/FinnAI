import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/code/linux/linux_installer.dart';
import 'package:finn_ai/src/features/code/sandbox/shell_sandbox.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

/// Where proot is on this device, or null where the sandbox cannot run.
typedef ProotLocator = Future<ProotBinaries?> Function();

/// The two executables the sandbox needs, from the app's native-library
/// folder (the only place Android lets an app execute files from).
class ProotBinaries {
  const ProotBinaries({required this.proot, required this.loader});

  final String proot;
  final String loader;
}

/// Runs commands in a real Linux userland — Alpine, aarch64 — on the phone's
/// own CPU, through proot (ADR 0012).
///
/// proot intercepts the commands' system calls and maps paths, so the
/// commands see Alpine's `/` and the session's project folder at
/// `/workspace`; nothing else of the device's files is mounted. The network
/// is the phone's, so `apk add`, `pip install`, `npm install` and
/// `git clone` work. Everything runs as the app's own unprivileged user
/// (proot only pretends to be root), with a time limit.
///
/// The filesystem persists between commands and sessions: what one session
/// installs, the next can use. The project folder is mounted, not copied.
class LinuxSandbox {
  LinuxSandbox({required this.installer, ProotLocator? locate})
      : _locate = locate ?? _fromNativeLibraryDir;

  final LinuxInstaller installer;
  final ProotLocator _locate;
  ProotBinaries? _binaries;
  bool _located = false;

  /// Whether this device can run the sandbox at all. Known after [prepare].
  bool get platformSupported => _binaries != null;

  /// Can run a command now.
  bool get ready => platformSupported && installer.installed;

  /// Finds proot and reads the install state. Cheap; safe to call often.
  Future<void> prepare() async {
    if (!_located) {
      _binaries = await _locate();
      _located = true;
    }
    // Where the sandbox cannot run there is nothing on disk to look at.
    if (_binaries != null) await installer.refresh();
  }

  static const MethodChannel _profile = MethodChannel('finn_ai/device_profile');

  static Future<ProotBinaries?> _fromNativeLibraryDir() async {
    if (!Platform.isAndroid) return null;
    try {
      final profile =
          await _profile.invokeMapMethod<String, Object?>('getDeviceProfile');
      final dir = profile?['nativeLibraryDir'] as String?;
      if (dir == null) return null;
      final binaries = ProotBinaries(
        proot: '$dir/libproot.so',
        loader: '$dir/libproot-loader.so',
      );
      if (!await File(binaries.proot).exists() ||
          !await File(binaries.loader).exists()) {
        return null;
      }
      return binaries;
    } catch (_) {
      return null;
    }
  }

  /// The environment a command sees inside: nothing from the app's own.
  static const Map<String, String> guestEnvironment = {
    'HOME': '/root',
    'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    'TERM': 'dumb',
    'LANG': 'C.UTF-8',
    'TMPDIR': '/tmp',
    'PYTHONUNBUFFERED': '1',
    // Alpine's Python refuses system-wide pip installs (PEP 668); in a
    // throwaway sandbox that is what the user wants.
    'PIP_BREAK_SYSTEM_PACKAGES': '1',
    'PIP_ROOT_USER_ACTION': 'ignore',
    'PIP_DISABLE_PIP_VERSION_CHECK': '1',
    'npm_config_update_notifier': 'false',
    'npm_config_fund': 'false',
    'GIT_TERMINAL_PROMPT': '0',
  };

  /// The proot command line for [command] in [projectRoot].
  static List<String> arguments({
    required String rootfs,
    required String projectRoot,
    required String command,
  }) =>
      [
        '--kill-on-exit',
        // Fake root: apk and friends insist on it. Nothing is really root.
        '-0',
        // Android's app storage refuses hard links; fake them.
        '--link2symlink',
        '-r', rootfs,
        '-b', '/dev',
        '-b', '/proc',
        '-b', '/sys',
        '-b', '$projectRoot:/workspace',
        '-w', '/workspace',
        '/usr/bin/env', '-i',
        for (final entry in guestEnvironment.entries)
          '${entry.key}=${entry.value}',
        '/bin/sh', '-c', command,
      ];

  /// Runs [command] in [workspace]'s folder. [onOutput] receives output as it
  /// arrives (decoded text), for a live view; the result holds it all, up to
  /// [maxOutputBytes].
  Future<ShellResult> run(
    CodeWorkspace workspace,
    String command, {
    required Duration timeout,
    int maxOutputBytes = 32 * 1024,
    void Function(String chunk)? onOutput,
  }) async {
    final binaries = _binaries;
    if (binaries == null || !installer.installed) {
      return const ShellResult(
        exitCode: 127,
        output: 'The Linux sandbox is not set up on this device.',
      );
    }
    await workspace.ensureCreated();
    final dir = await installer.directory();
    final tmp = Directory('${dir.path}/proot-tmp');
    await tmp.create(recursive: true);
    final started = DateTime.now();
    final Process process;
    try {
      process = await Process.start(
        binaries.proot,
        arguments(
          rootfs: '${dir.path}/rootfs',
          projectRoot: workspace.root.path,
          command: command,
        ),
        workingDirectory: workspace.root.path,
        environment: {
          'PROOT_LOADER': binaries.loader,
          'PROOT_TMP_DIR': tmp.path,
          'HOME': '/root',
        },
        includeParentEnvironment: false,
      );
    } on ProcessException catch (error) {
      return ShellResult(exitCode: 127, output: error.message);
    }
    unawaited(process.stdin.close().catchError((Object _) {}));

    final buffer = BytesBuilder(copy: false);
    var truncated = false;
    void collect(List<int> chunk) {
      final room = maxOutputBytes - buffer.length;
      if (room <= 0) {
        truncated = true;
        return;
      }
      if (chunk.length > room) {
        buffer.add(chunk.sublist(0, room));
        truncated = true;
      } else {
        buffer.add(chunk);
      }
    }

    Future<void> drain(Stream<List<int>> stream) async {
      final decoder = const Utf8Decoder(allowMalformed: true)
          .startChunkedConversion(_Callback(onOutput));
      await for (final chunk in stream) {
        collect(chunk);
        if (onOutput != null) decoder.add(chunk);
      }
      decoder.close();
    }

    final drained = Future.wait([drain(process.stdout), drain(process.stderr)]);
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      // proot ends everything it traces when it goes (--kill-on-exit and
      // PTRACE_O_EXITKILL), so the whole command tree stops with it.
      process.kill(ProcessSignal.sigkill);
    });
    final exitCode = await process.exitCode;
    timer.cancel();
    try {
      await drained.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // A background child kept a pipe open; what arrived is what we have.
    }
    return ShellResult(
      exitCode: timedOut ? 124 : exitCode,
      output: utf8.decode(buffer.takeBytes(), allowMalformed: true),
      truncated: truncated,
      timedOut: timedOut,
      duration: DateTime.now().difference(started),
    );
  }
}

class _Callback implements Sink<String> {
  _Callback(this.onOutput);

  final void Function(String chunk)? onOutput;

  @override
  void add(String data) {
    if (data.isNotEmpty) onOutput?.call(data);
  }

  @override
  void close() {}
}

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// The Alpine Linux root filesystem FinnAI Code's sandbox runs (ADR 0012).
///
/// Pinned like the model: a mismatch in size or SHA-256 is a failed install,
/// never a sandbox that runs something else. Values from Alpine's own
/// `latest-releases.yaml` for the release, checked against the download.
abstract final class LinuxImage {
  static const String version = '3.24.2';
  static const String url = 'https://dl-cdn.alpinelinux.org/alpine/v3.24/'
      'releases/aarch64/alpine-minirootfs-3.24.2-aarch64.tar.gz';
  static const int bytes = 4028030;
  static const String sha256 =
      '9bf70a7f18ea44094cbb5f70c58f9af129c8214745743db0e68e5502cc2ce773';
}

enum LinuxInstallState {
  unknown,
  missing,
  downloading,

  /// Unpacking and setting up the filesystem.
  preparing,
  installed,
  failed,
}

enum LinuxInstallError { network, verification, storage }

/// Downloads, verifies, unpacks and removes the sandbox's filesystem.
///
/// The archive streams to `alpine.tar.gz.part` and is hashed as it arrives;
/// only a file with the right size and digest is unpacked. The filesystem is
/// unpacked into `rootfs.new` and renamed into place, so a stopped install
/// never leaves half a system that looks installed.
class LinuxInstaller extends ChangeNotifier {
  LinuxInstaller({
    this.directoryProvider,
    http.Client Function()? clientFactory,
    this.tarPath = 'tar',
  }) : _clientFactory = clientFactory ?? http.Client.new;

  static final instance = LinuxInstaller();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  final http.Client Function() _clientFactory;

  /// The device's own tar (toybox on Android), which keeps symbolic links and
  /// modes. Overridable for tests on a desktop host.
  final String tarPath;

  LinuxInstallState _state = LinuxInstallState.unknown;
  LinuxInstallError? _error;
  int _received = 0;
  http.Client? _client;

  LinuxInstallState get state => _state;
  LinuxInstallError? get error => _error;
  bool get installed => _state == LinuxInstallState.installed;
  int get totalBytes => LinuxImage.bytes;

  /// Between 0 and 1 while downloading.
  double get progress => (_received / LinuxImage.bytes).clamp(0.0, 1.0);

  /// Where the sandbox lives: `<support>/code/linux`.
  Future<Directory> directory() async {
    final base = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return Directory('${base.path}/code/linux');
  }

  Future<Directory> rootfs() async =>
      Directory('${(await directory()).path}/rootfs');

  File _marker(Directory dir) => File('${dir.path}/rootfs/.finn-installed');

  Future<void> refresh() async {
    if (_state == LinuxInstallState.downloading ||
        _state == LinuxInstallState.preparing) {
      return;
    }
    final dir = await directory();
    final marker = _marker(dir);
    _state = await marker.exists() &&
            (await marker.readAsString()).trim() == LinuxImage.version
        ? LinuxInstallState.installed
        : LinuxInstallState.missing;
    notifyListeners();
  }

  /// Downloads and sets up the filesystem. Returns true when installed.
  Future<bool> install() async {
    if (_state == LinuxInstallState.downloading ||
        _state == LinuxInstallState.preparing) {
      return false;
    }
    _error = null;
    _received = 0;
    _state = LinuxInstallState.downloading;
    notifyListeners();
    final dir = await directory();
    final archive = File('${dir.path}/alpine.tar.gz');
    try {
      await dir.create(recursive: true);
      await _download(archive);
      _state = LinuxInstallState.preparing;
      notifyListeners();
      await _unpack(dir, archive);
      await archive.delete();
      _state = LinuxInstallState.installed;
      notifyListeners();
      return true;
    } on _Cancelled {
      _state = LinuxInstallState.missing;
    } on _VerificationFailed {
      _error = LinuxInstallError.verification;
      _state = LinuxInstallState.failed;
    } on FileSystemException {
      _error = LinuxInstallError.storage;
      _state = LinuxInstallState.failed;
    } on ProcessException {
      _error = LinuxInstallError.storage;
      _state = LinuxInstallState.failed;
    } catch (_) {
      _error = LinuxInstallError.network;
      _state = LinuxInstallState.failed;
    } finally {
      _client?.close();
      _client = null;
    }
    notifyListeners();
    return false;
  }

  void cancel() {
    final client = _client;
    _client = null;
    client?.close();
  }

  Future<void> _download(File target) async {
    final part = File('${target.path}.part');
    final client = _client = _clientFactory();
    final response = await client
        .send(http.Request('GET', Uri.parse(LinuxImage.url)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    final sink = part.openWrite();
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    try {
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        if (_client == null) throw const _Cancelled();
        sink.add(chunk);
        hasher.add(chunk);
        _received += chunk.length;
        notifyListeners();
      }
    } on http.ClientException {
      if (_client == null) throw const _Cancelled();
      rethrow;
    } finally {
      await sink.close();
    }
    hasher.close();
    if (_received != LinuxImage.bytes ||
        digest.value.toString() != LinuxImage.sha256) {
      await part.delete();
      throw const _VerificationFailed();
    }
    await part.rename(target.path);
  }

  Future<void> _unpack(Directory dir, File archive) async {
    final fresh = Directory('${dir.path}/rootfs.new');
    if (await fresh.exists()) await fresh.delete(recursive: true);
    await fresh.create(recursive: true);
    final result =
        await Process.run(tarPath, ['xzf', archive.path, '-C', fresh.path]);
    if (result.exitCode != 0) {
      throw ProcessException(tarPath, const [], '${result.stderr}');
    }
    await LinuxSetup.configure(fresh);
    final current = Directory('${dir.path}/rootfs');
    if (await current.exists()) await current.delete(recursive: true);
    await fresh.rename(current.path);
    await File('${current.path}/.finn-installed')
        .writeAsString(LinuxImage.version);
  }

  /// Removes the filesystem and everything installed into it. Returns what
  /// could not be removed.
  Future<List<String>> deleteStorage() async {
    cancel();
    final failed = <String>[];
    try {
      final dir = await directory();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      failed.add('linux');
    }
    _state = LinuxInstallState.missing;
    notifyListeners();
    return failed;
  }
}

/// The files FinnAI adds to a fresh Alpine filesystem.
abstract final class LinuxSetup {
  /// Public resolvers: Android's own DNS is not reachable from a resolv.conf.
  static const String resolvConf = 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n';

  /// `apt`/`apt-get` mapped onto Alpine's apk, because models (and people)
  /// type them out of habit. Package names mostly match (python3, git,
  /// nodejs, npm); build-essential is build-base here.
  static const String aptShim = r'''#!/bin/sh
# FinnAI: apt on Alpine. Maps the common verbs onto apk.
verb="$1"; [ $# -gt 0 ] && shift
args=""
for a in "$@"; do
  case "$a" in
    -y|--yes|-q|--quiet|--no-install-recommends) ;;
    build-essential) args="$args build-base" ;;
    python3-pip) args="$args py3-pip" ;;
    python3-venv) args="$args python3" ;;
    *) args="$args $a" ;;
  esac
done
case "$verb" in
  update) exec apk update ;;
  upgrade) exec apk upgrade ;;
  install) exec apk add $args ;;
  remove|purge) exec apk del $args ;;
  search) exec apk search $args ;;
  list) exec apk list --installed ;;
  *) echo "apt on FinnAI's Alpine supports: update, upgrade, install, remove, search" >&2; exit 1 ;;
esac
''';

  /// `sudo` that just runs the command: the sandbox already acts as root,
  /// and a model's `sudo apt-get install` should work, not fail.
  static const String sudoShim = '#!/bin/sh\n'
      '# FinnAI: everything here already runs as (pretend) root.\n'
      'while [ \$# -gt 0 ]; do case "\$1" in -*) shift ;; *) break ;; esac; done\n'
      'exec "\$@"\n';

  /// Bumped when the files below change, so an existing install gets them.
  static const int shimVersion = 2;

  /// Writes the shims if this filesystem has an older set. Cheap when
  /// current: one small file read.
  static Future<void> ensureShims(Directory root) async {
    final stamp = File('${root.path}/usr/local/share/finn-shims');
    try {
      if (await stamp.exists() &&
          (await stamp.readAsString()).trim() == '$shimVersion') {
        return;
      }
    } catch (_) {}
    for (final (name, body) in [
      ('apt', aptShim),
      ('apt-get', aptShim),
      ('sudo', sudoShim),
    ]) {
      final file = File('${root.path}/usr/local/bin/$name');
      await file.parent.create(recursive: true);
      await file.writeAsString(body);
      await Process.run('chmod', ['755', file.path]);
    }
    await stamp.parent.create(recursive: true);
    await stamp.writeAsString('$shimVersion');
  }

  static Future<void> configure(Directory root) async {
    final etc = Directory('${root.path}/etc');
    await etc.create(recursive: true);
    await File('${etc.path}/resolv.conf').writeAsString(resolvConf);
    await File('${etc.path}/hosts')
        .writeAsString('127.0.0.1 localhost\n::1 localhost\n');
    await ensureShims(root);
    await Directory('${root.path}/workspace').create(recursive: true);
    await Directory('${root.path}/tmp').create(recursive: true);
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

class _VerificationFailed implements Exception {
  const _VerificationFailed();
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

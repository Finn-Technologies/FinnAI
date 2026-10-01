import 'dart:io';

import 'package:crypto/crypto.dart';

/// Downloads one file to [target]: resumable, size-checked and SHA-256
/// verified, and the file only appears under its final name once it is right.
///
/// Shared by the speech-recognition model and the text-to-speech voices, which
/// are both optional, pinned downloads that must survive a bad connection.
class VerifiedFetcher {
  VerifiedFetcher({HttpClient Function()? clientFactory})
      : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  HttpClient? _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  /// Call before a new download so an earlier [cancel] does not carry over.
  void reset() => _cancelled = false;

  Future<void> fetch({
    required String name,
    required String url,
    required int bytes,
    required String sha256Digest,
    required File target,
    void Function(int received)? onProgress,
  }) async {
    final partial = File('${target.path}.part');
    var existing = await partial.exists() ? await partial.length() : 0;
    if (existing > bytes) {
      await partial.delete();
      existing = 0;
    }
    if (existing < bytes) {
      final client = _client = _clientFactory()
        ..connectionTimeout = const Duration(seconds: 20);
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw HttpException(
          'Download failed (${response.statusCode})',
          uri: uri,
        );
      }
      // A server that ignored the Range header sent the whole file again.
      if (response.statusCode == HttpStatus.ok && existing > 0) existing = 0;
      final sink = partial.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      var received = existing;
      try {
        await for (final chunk in response) {
          if (_cancelled) throw const HttpException('Download cancelled');
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    }
    final length = await partial.length();
    if (length < bytes) {
      // The connection ended early. What arrived is good; keep it so the
      // next attempt resumes instead of starting over.
      throw HttpException('$name ended early ($length/$bytes)');
    }
    if (length != bytes ||
        (await sha256.bind(partial.openRead()).first).toString() !=
            sha256Digest) {
      // Wrong bytes can never be resumed into right ones.
      await partial.delete();
      throw HttpException('$name failed verification');
    }
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
  }
}

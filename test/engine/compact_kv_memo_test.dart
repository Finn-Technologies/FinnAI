import 'dart:convert';
import 'dart:io';

import 'package:finn_ai/src/engine/adaptive/adaptive.dart';
import 'package:finn_ai/src/engine/profiler/device_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// llama.cpp returns a null context when a quantized KV cache is unsupported,
/// so the engine retries with F16. That fallback used to repeat on every cold
/// start (seconds of delay plus a native error before each first reply), so the
/// device's KV capability is now remembered per device+model fingerprint.
void main() {
  late Directory tempDir;
  const modelSha =
      '8186364a4e7c3ad30f6dd3d3b7a4e0074c77dd91eed6cad5d8be9090ce285804';

  const profile = DeviceProfile(
    totalRamBytes: 8 * 1024 * 1024 * 1024,
    availableRamBytes: 4 * 1024 * 1024 * 1024,
    processor: ProcessorClass.balanced,
    soc: 'SM8650',
    cores: 8,
    lowMemory: false,
    supportedAbis: ['arm64-v8a'],
    nativeLibraryDir: '/data/app/lib/arm64',
  );

  final adaptive = AdaptiveInferenceEngine.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finn_kv_memo_');
    adaptive.debugCacheDirectory = tempDir;
  });

  tearDown(() async {
    adaptive.debugCacheDirectory = null;
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  File cacheFile() => File(
        '${tempDir.path}${Platform.pathSeparator}adaptive_backend.json',
      );

  test('a device starts out without a recorded KV limitation', () async {
    expect(
      await adaptive.isCompactKvUnsupported(
        profile: profile,
        modelSha256: modelSha,
      ),
      isFalse,
    );
  });

  test('recording a fallback survives a restart', () async {
    await adaptive.recordCompactKvUnsupported(
      profile: profile,
      modelSha256: modelSha,
    );
    expect(
      await adaptive.isCompactKvUnsupported(
        profile: profile,
        modelSha256: modelSha,
      ),
      isTrue,
    );

    // Simulate the next cold start: drop in-memory state and read it back.
    adaptive.debugResetCacheState();
    expect(
      await adaptive.isCompactKvUnsupported(
        profile: profile,
        modelSha256: modelSha,
      ),
      isTrue,
      reason: 'the fallback must not have to be re-learned every launch',
    );
  });

  test('the memory is scoped to the model that failed', () async {
    await adaptive.recordCompactKvUnsupported(
      profile: profile,
      modelSha256: modelSha,
    );
    adaptive.debugResetCacheState();
    expect(
      await adaptive.isCompactKvUnsupported(
        profile: profile,
        modelSha256: 'a-different-model-digest',
      ),
      isFalse,
    );
  });

  test('the memory survives an app update', () async {
    await adaptive.recordCompactKvUnsupported(
      profile: profile,
      modelSha256: modelSha,
    );
    adaptive.debugResetCacheState();

    // Android installs each build under a fresh random `/data/app/~~<id>==`
    // directory, so the native library path recorded before an update is never
    // the path seen after it. Keying the memory off that path would make every
    // user pay the doomed quantized-KV init again after each release.
    const afterUpdate = DeviceProfile(
      totalRamBytes: 8 * 1024 * 1024 * 1024,
      availableRamBytes: 4 * 1024 * 1024 * 1024,
      processor: ProcessorClass.balanced,
      soc: 'SM8650',
      cores: 8,
      lowMemory: false,
      supportedAbis: ['arm64-v8a'],
      nativeLibraryDir: '/data/app/~~reinstalled==/base/lib/arm64',
    );

    expect(
      await adaptive.isCompactKvUnsupported(
        profile: afterUpdate,
        modelSha256: modelSha,
      ),
      isTrue,
      reason: 'an app update must not reintroduce the cold-start fallback',
    );
  });

  test('recording preserves the other contents of the cache file', () async {
    await cacheFile().writeAsString(
      jsonEncode({'fingerprint': 'kept', 'backend': 'cpu'}),
    );
    await adaptive.recordCompactKvUnsupported(
      profile: profile,
      modelSha256: modelSha,
    );
    final data =
        jsonDecode(await cacheFile().readAsString()) as Map<String, Object?>;
    expect(data['fingerprint'], 'kept');
    expect(data['backend'], 'cpu');
    expect(data['compactKvUnsupported'], isA<List<Object?>>());
    expect((data['compactKvUnsupported']! as List<Object?>), hasLength(1));
  });

  test('a corrupt cache does not break recording', () async {
    await cacheFile().writeAsString('not json at all');
    await adaptive.recordCompactKvUnsupported(
      profile: profile,
      modelSha256: modelSha,
    );
    adaptive.debugResetCacheState();
    expect(
      await adaptive.isCompactKvUnsupported(
        profile: profile,
        modelSha256: modelSha,
      ),
      isTrue,
    );
  });
}

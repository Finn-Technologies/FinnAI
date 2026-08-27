import 'package:finn_ai/src/inference/adaptive/adaptive.dart';
import 'package:finn_ai/src/inference/device_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('balanced Snapdragon with 8 GB runs an 8K context', () {
    const profile = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 5000000000,
      processor: ProcessorClass.balanced,
      soc: 'Qualcomm SM7250 Snapdragon 765G',
      cores: 8,
      lowMemory: false,
    );

    final plan = DeviceProfiler.plan(profile);

    expect(plan.contextSize, 8192);
    // Decode is bandwidth-bound and pinned to the 4 fast cores (52 ms/token
    // on SM7325). Batch/lookahead passes are compute-bound and the native
    // AAR now spills oversized threadpools onto the small cores, so batch
    // uses all cores.
    expect(plan.threads, 4);
    expect(plan.batchThreads, 8);
  });

  test('entry processor caps context and threads even with ample RAM', () {
    const profile = DeviceProfile(
      totalRamBytes: 12000000000,
      availableRamBytes: 8000000000,
      processor: ProcessorClass.entry,
      soc: 'Entry SoC',
      cores: 8,
      lowMemory: false,
    );

    final plan = DeviceProfiler.plan(profile);

    expect(plan.contextSize, 4096);
    expect(plan.threads, 4);
    expect(plan.batchThreads, 8);
    expect(plan.batchSize, 256);
    expect(plan.tokenPaintIntervalMs, 80);
  });

  test('minimum supported hardware receives the compact runtime', () {
    const profile = DeviceProfile(
      totalRamBytes: 3000000000,
      availableRamBytes: 1200000000,
      processor: ProcessorClass.entry,
      soc: 'Qualcomm SM6115',
      cores: 8,
      lowMemory: true,
    );

    final plan = DeviceProfiler.plan(profile);

    expect(plan.contextSize, 2048);
    expect(plan.batchSize, 128);
    expect(plan.microBatchSize, 64);
  });

  test('flagship with RAM headroom runs an 8K context', () {
    const profile = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 5000000000,
      processor: ProcessorClass.flagship,
      soc: 'Qualcomm SM8650',
      cores: 8,
      lowMemory: false,
    );

    expect(DeviceProfiler.plan(profile).contextSize, 8192);
  });

  test(
    'Galaxy Tab A8 3GB RAM (Unisoc T618 / ums512) is supported as entry device',
    () {
      // 3GB physical RAM reports ~2.53GB to Android kernel due to hardware reservations
      const profile = DeviceProfile(
        totalRamBytes: 2534920 * 1024,
        availableRamBytes: 576000 * 1024,
        processor: ProcessorClass.entry,
        soc: 'Spreadtrum T618 ums512_25c10',
        cores: 8,
        lowMemory: false,
        supportedAbis: ['arm64-v8a', 'armeabi-v7a', 'armeabi'],
      );

      expect(profile.supported, isTrue);
      final plan = DeviceProfiler.plan(profile);
      expect(plan.contextSize, 2048);
      expect(plan.threads, 2);
      expect(plan.batchThreads, 4);
      expect(plan.batchSize, 128);
      expect(plan.microBatchSize, 64);
      expect(plan.compactKv, isTrue);
      expect(plan.flashAttention, isFalse);
    },
  );

  test(
    'Motorola with Dimensity 7025 (MT6855) 8GB is supported with balanced plan',
    () {
      const profile = DeviceProfile(
        totalRamBytes: 8000000000,
        availableRamBytes: 4500000000,
        processor: ProcessorClass.balanced,
        soc: 'MediaTek Dimensity 7025 MT6855',
        cores: 8,
        lowMemory: false,
      );

      expect(profile.supported, isTrue);
      final plan = DeviceProfiler.plan(profile);
      expect(plan.contextSize, 8192);
      expect(plan.threads, 4);
      expect(plan.batchThreads, 8);
    },
  );

  test(
    'OnePlus with Snapdragon 7+ Gen 3 (SM7675) 8GB is supported with flagship plan',
    () {
      const profile = DeviceProfile(
        totalRamBytes: 8000000000,
        availableRamBytes: 5000000000,
        processor: ProcessorClass.flagship,
        soc: 'Qualcomm Snapdragon 7+ Gen 3 SM7675',
        cores: 8,
        lowMemory: false,
      );

      expect(profile.supported, isTrue);
      final plan = DeviceProfiler.plan(profile);
      expect(plan.contextSize, 8192);
      expect(plan.threads, 4);
      expect(plan.batchThreads, 8);
    },
  );

  test(
    'runtimeConfigFromPlan selects high-performance TurboQuant Q4_0 KV for all device tiers',
    () {
      const flagshipProfile = DeviceProfile(
        totalRamBytes: 8000000000,
        availableRamBytes: 5000000000,
        processor: ProcessorClass.flagship,
        soc: 'Qualcomm SM8650',
        cores: 8,
        lowMemory: false,
      );
      final flagshipPlan = DeviceProfiler.plan(flagshipProfile);
      final flagshipConfig = runtimeConfigFromPlan(
        flagshipPlan,
        flagshipProfile,
      );
      expect(flagshipConfig.kvType.name, 'q4_0');
      expect(flagshipConfig.contextSize, 8192);

      const entryProfile = DeviceProfile(
        totalRamBytes: 2800000000,
        availableRamBytes: 800000000,
        processor: ProcessorClass.entry,
        soc: 'Qualcomm SM6115',
        cores: 8,
        lowMemory: true,
      );
      final entryPlan = DeviceProfiler.plan(entryProfile);
      final entryConfig = runtimeConfigFromPlan(entryPlan, entryProfile);
      expect(entryConfig.kvType.name, 'q4_0');
      expect(entryConfig.contextSize, 2048);
      expect(entryConfig.batchSize, 128);
    },
  );
}

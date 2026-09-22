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

    expect(plan.contextSize, 4096);
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

    expect(plan.contextSize, 2048);
    expect(plan.threads, 4);
    expect(plan.batchThreads, 8);
    expect(plan.batchSize, 256);
    expect(plan.tokenPaintIntervalMs, 32);
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

    expect(DeviceProfiler.plan(profile).contextSize, 4096);
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
      expect(plan.compactKv, isFalse);
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
      expect(plan.contextSize, 4096);
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
      expect(plan.contextSize, 4096);
      expect(plan.threads, 4);
      expect(plan.batchThreads, 8);
    },
  );

  test(
    'runtimeConfigFromPlan keeps KV lossless because f16 measured faster on CPU',
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
      expect(flagshipConfig.kvType.name, 'f16');
      expect(flagshipConfig.contextSize, 4096);

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
      expect(entryConfig.kvType.name, 'f16');
      expect(entryConfig.contextSize, 2048);
      expect(entryConfig.batchSize, 128);
    },
  );

  test('a big.LITTLE part caps both thread pools at its fast cluster', () {
    // SM6225: 4x A73 at 2.4 GHz plus 4x A53 at 1.8 GHz. On this reference
    // device the same 327-token prompt reached first token in 11.9 s with 8
    // batch threads, 13.0 s with 6, and 7.0 s with 4.
    const profile = DeviceProfile(
      totalRamBytes: 6000000000,
      availableRamBytes: 3000000000,
      processor: ProcessorClass.balanced,
      soc: 'Qualcomm SM6225 Snapdragon 680',
      cores: 8,
      lowMemory: false,
      performanceCores: 4,
    );

    final plan = DeviceProfiler.plan(profile);

    expect(plan.threads, 4);
    expect(plan.batchThreads, 4);
  });

  test('a 2+6 part never puts a worker on a little core', () {
    const profile = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 5000000000,
      processor: ProcessorClass.balanced,
      soc: 'Heterogeneous 2+6',
      cores: 8,
      lowMemory: false,
      performanceCores: 2,
    );

    final plan = DeviceProfiler.plan(profile);

    expect(plan.threads, 2);
    expect(plan.batchThreads, 2);
  });

  test('a tri-cluster part keeps both of its fast clusters for prefill', () {
    // 1x prime + 3x performance + 4x efficiency: only the efficiency cluster
    // is excluded, so prefill still gets four workers.
    const profile = DeviceProfile(
      totalRamBytes: 12000000000,
      availableRamBytes: 7000000000,
      processor: ProcessorClass.flagship,
      soc: 'Qualcomm SM8650',
      cores: 8,
      lowMemory: false,
      performanceCores: 4,
    );

    final plan = DeviceProfiler.plan(profile);

    expect(plan.threads, 4);
    expect(plan.batchThreads, 4);
    expect(plan.compactKv, isFalse);
  });
}

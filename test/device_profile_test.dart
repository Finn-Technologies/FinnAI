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
    // Threadpools are affinity-pinned to the fastest cluster by the native
    // AAR, so the plan matches that cluster size: 4 decode threads measured
    // 52 ms/token decode on SM7325 with full CPU (vs 8.5 s when a background
    // cgroup throttled the big cores and threads spilled onto A55s).
    expect(plan.threads, 4);
    expect(plan.batchThreads, 4);
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
    expect(plan.batchThreads, 4);
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
}

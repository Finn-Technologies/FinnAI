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
}

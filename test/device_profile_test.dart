import 'package:finn_ai/src/inference/bonsai_inference.dart';
import 'package:finn_ai/src/inference/device_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('older balanced Snapdragon with 8 GB defaults to responsive Lite', () {
    const profile = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 5000000000,
      processor: ProcessorClass.balanced,
      soc: 'Qualcomm SM7250 Snapdragon 765G',
      cores: 8,
      lowMemory: false,
    );

    final plan = DeviceProfiler.plan(profile);

    expect(plan.tier, BonsaiTier.lite);
    expect(plan.contextSize, 4096);
    expect(plan.threads, 5);
    expect(plan.batchThreads, 8);
  });

  test('newer balanced Snapdragon with 8 GB still selects Plus', () {
    const profile = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 5000000000,
      processor: ProcessorClass.balanced,
      soc: 'Qualcomm SM7550 Snapdragon 7 Gen 3',
      cores: 8,
      lowMemory: false,
    );

    expect(DeviceProfiler.plan(profile).tier, BonsaiTier.plus);
  });

  test('processor tier caps model even when RAM is plentiful', () {
    const profile = DeviceProfile(
      totalRamBytes: 12000000000,
      availableRamBytes: 8000000000,
      processor: ProcessorClass.entry,
      soc: 'Entry SoC',
      cores: 8,
      lowMemory: false,
    );

    final plan = DeviceProfiler.plan(profile);
    expect(plan.tier, BonsaiTier.lite);
    expect(plan.contextSize, 4096);
    expect(plan.threads, 3);
    expect(plan.batchSize, 256);
    expect(plan.maxOutputTokens, 2048);
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

    expect(plan.tier, BonsaiTier.lite);
    expect(plan.contextSize, 2048);
    expect(plan.batchSize, 128);
    expect(plan.microBatchSize, 64);
  });

  test('flagship with sufficient RAM selects 8B', () {
    const profile = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 5000000000,
      processor: ProcessorClass.flagship,
      soc: 'Qualcomm SM8650',
      cores: 8,
      lowMemory: false,
    );

    expect(DeviceProfiler.plan(profile).tier, BonsaiTier.pro);
  });

  test(
    'clear complex requests bypass generative routing at the right tier',
    () {
      final inference = BonsaiInference.instance;
      expect(
        inference.fastRouteForTest('Write a careful launch plan.'),
        BonsaiTier.plus,
      );
      expect(
        inference.fastRouteForTest(
          'Perform a rigorous proof with deep reasoning.',
          highestTier: BonsaiTier.pro,
        ),
        BonsaiTier.pro,
      );
      expect(inference.fastRouteForTest('Hello!'), BonsaiTier.lite);
      expect(
        inference.fastRouteForTest('Translate this sentence into Italian.'),
        BonsaiTier.plus,
      );
      expect(
        inference.fastRouteForTest(
          'Can you tell me how to upgrade the RAM in my laptop?',
        ),
        BonsaiTier.plus,
      );
    },
  );

  test('explicit model requests bypass Lite routing', () {
    final inference = BonsaiInference.instance;
    expect(
      inference.explicitTierRequestForTest(
        'Use Finn AI Plus to make a new joke.',
      ),
      BonsaiTier.plus,
    );
    expect(
      inference.explicitTierRequestForTest(
        'Please use Finn Pro for this.',
        highestTier: BonsaiTier.plus,
      ),
      isNull,
    );
  });
}

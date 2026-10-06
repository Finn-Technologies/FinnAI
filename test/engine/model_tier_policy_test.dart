import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/catalog/model_catalog.dart';
import 'package:finn_ai/src/engine/profiler/model_tier_policy.dart';

const _gb8 = 7630000000; // what an "8 GB" phone reports (Mi 11 Lite: 7.63e9)
const _gb6 = 5700000000;

List<CpuCore> _cores(List<(int part, double ghz, int count)> clusters,
        {int implementer = 0x41}) =>
    [
      for (final (part, ghz, count) in clusters)
        for (var i = 0; i < count; i++)
          CpuCore(implementer: implementer, part: part, maxGhz: ghz),
    ];

void main() {
  test('chipsets named in the bar get the 3B with 8 GB', () {
    for (final soc in [
      'QTI SM7325 qcom', // Snapdragon 778G (the user's Mi 11 Lite)
      'QTI SDM845 qcom', // Snapdragon 845
      'Mediatek MT6878', // Dimensity 7300
      'HiSilicon Kirin 8000',
      'Google Tensor G3 zuma',
    ]) {
      expect(
        ModelTierPolicy.recommend(totalRamBytes: _gb8, soc: soc, cores: []),
        FinnModelTier.plus,
        reason: soc,
      );
    }
  });

  test('below 7.3 GB stays on the 1.6B, whatever the chip', () {
    expect(
      ModelTierPolicy.recommend(
          totalRamBytes: _gb6, soc: 'QTI SM8650', cores: []),
      FinnModelTier.standard,
    );
    expect(
      ModelTierPolicy.recommend(totalRamBytes: null, soc: 'SM8650', cores: []),
      FinnModelTier.standard,
    );
  });

  test('an unknown chip is judged by its cores against the 845', () {
    // Snapdragon 845: 4x Kryo 385 Gold 2.8 GHz + 4x Silver 1.77 GHz.
    final sd845 = [
      ..._cores([(0x802, 2.8, 4)], implementer: 0x51),
      ..._cores([(0x803, 1.77, 4)], implementer: 0x51),
    ];
    expect(ModelTierPolicy.cpuScore(sd845), closeTo(13.5, .4));
    // Snapdragon 778G: 1x A78 2.4 + 3x A78 2.2 + 4x A55 1.9 → above.
    final sd778 = _cores([(0xd41, 2.4, 1), (0xd41, 2.2, 3), (0xd05, 1.9, 4)]);
    expect(
      ModelTierPolicy.recommend(totalRamBytes: _gb8, soc: '?', cores: sd778),
      FinnModelTier.plus,
    );
    // Snapdragon 720G: 2x A76 2.3 + 6x A55 1.8 → below the 845.
    final sd720 = _cores([(0xd0b, 2.3, 2), (0xd05, 1.8, 6)]);
    expect(
      ModelTierPolicy.recommend(totalRamBytes: _gb8, soc: '?', cores: sd720),
      FinnModelTier.standard,
    );
    // Unreadable clocks: no guess, the 1.6B.
    expect(
      ModelTierPolicy.recommend(
        totalRamBytes: _gb8,
        soc: '?',
        cores: const [CpuCore(implementer: 0x41, part: 0xd41)],
      ),
      FinnModelTier.standard,
    );
  });

  test('parses /proc/cpuinfo blocks', () {
    const text = 'processor\t: 0\nCPU implementer\t: 0x41\nCPU part\t: 0xd05\n'
        '\nprocessor\t: 7\nCPU implementer\t: 0x41\nCPU part\t: 0xd41\n';
    expect(ModelTierPolicy.parseCpuInfo(text),
        [(0, 0x41, 0xd05), (7, 0x41, 0xd41)]);
  });

  test('each tier carries its own pinned projector', () {
    for (final model in finnModels) {
      expect(model.projector, isNotNull);
      expect(model.projector!.sha256Digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    }
    expect(finnModels.map((m) => m.projector!.fileName).toSet().length,
        finnModels.length);
    expect(finnModelFor(FinnModelTier.plus).name, 'LFM2.5-VL 3B');
  });
}

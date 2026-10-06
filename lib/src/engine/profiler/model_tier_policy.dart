import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/engine/catalog/model_catalog.dart';

/// One CPU core as the kernel describes it: who designed it, which design,
/// and its top clock.
@immutable
class CpuCore {
  const CpuCore({required this.implementer, required this.part, this.maxGhz});

  /// `CPU implementer` (0x41 Arm, 0x51 Qualcomm, 0x48 HiSilicon…).
  final int implementer;

  /// `CPU part`, the core design within the implementer.
  final int part;
  final double? maxGhz;
}

/// Which model a device gets: the 3B (`plus`) where it runs at a pace people
/// accept, the 1.6B (`standard`) everywhere else.
///
/// The bar is "a Snapdragon 845 or better, with 8 GB of RAM". It is decided
/// three ways, in order:
///
/// 1. RAM: at least [minimumRamBytes]. An "8 GB" phone reports 7.3–7.7 GB,
///    because the kernel and carve-outs take their share before Android
///    counts it.
/// 2. A chipset this list knows by name is enough on its own.
/// 3. Otherwise, the cores themselves: each core's design weight times its
///    clock, summed ([cpuScore]). A Snapdragon 845 scores about 13.7; chips
///    that clear [scoreThreshold] are at its level or better whatever their
///    name, which keeps the rule right for chipsets released after it.
///
/// Measured on a Snapdragon 778G (Mi 11 Lite 5G NE, 8 GB), the entry point
/// of the tier: the 3B decodes at 9.4 tok/s against the 1.6B's 21.3, and
/// answers about one more question in 49 correctly
/// (`eval/RESULTS_2026-10-06_models.md`).
abstract final class ModelTierPolicy {
  static const int minimumRamBytes = 7300 * 1000 * 1000;
  static const double scoreThreshold = 13.5;

  /// Chipsets at Snapdragon 845 level or better, by the names Android and
  /// OpenHarmony report (SoC model, hardware or board).
  static final RegExp _knownFast = RegExp(
    [
      // Qualcomm: 845, 855/860, 865/870, 888, 8 Gen 1–3, 8 Elite…
      r'sdm845', r'sm8150', r'sm8250', r'sm8350', r'sm84[57]5', r'sm8550',
      r'sm8635', r'sm8650', r'sm8735', r'sm8750', r'sm8850',
      // Qualcomm 7-series from the 778G up: 778G/G+, 780G, 782G, 7 Gen 1–4.
      r'sm7325', r'sm7350', r'sm7450', r'sm7475', r'sm7550', r'sm7635',
      r'sm7675', r'sm7750',
      // MediaTek: Dimensity 1100/1200, 7200/7300, 8000–8400, 9000+.
      r'mt689[1-7]', r'mt6886', r'mt6878', r'mt698[3-9]', r'mt699\d',
      r'dimensity ?(1[12]00|7[23]00|8[0-4]\d0|9[0-4]\d0)',
      // HiSilicon Kirin 980 and later flagships, Kirin 8000 / 9000 series.
      r'kirin ?(98[05]|990|8000|9000|9006|9010|9020|9030)',
      // Samsung Exynos 2100 and later, Google Tensor.
      r'exynos ?(2[1-5]00)', r's5e99[2-5]5', r'gs[1-9]01', r'zuma',
      r'laguna', r'tensor',
    ].join('|'),
    caseSensitive: false,
  );

  /// How much one core of a design is worth, per GHz, against a Cortex-A75
  /// (the Snapdragon 845's big core) at 1.0. Single-core throughput on
  /// llama.cpp-like work; unknown designs count as a small core.
  static double _weight(int implementer, int part) {
    if (implementer == 0x41 || implementer == 0x48) {
      return switch (part) {
        0xd03 => .25, // A53
        0xd04 => .3, // A35
        0xd05 => .35, // A55
        0xd46 => .4, // A510
        0xd80 => .45, // A520
        0xd07 => .6, // A57
        0xd08 => .75, // A72
        0xd09 => .85, // A73
        0xd0a => 1.0, // A75
        0xd0b => 1.35, // A76
        0xd0d => 1.5, // A77
        0xd41 => 1.6, // A78
        0xd47 => 1.7, // A710
        0xd4d => 1.85, // A715
        0xd81 => 2.0, // A720
        0xd87 => 2.2, // A725
        0xd44 => 2.0, // X1
        0xd48 => 2.2, // X2
        0xd4e => 2.4, // X3
        0xd82 => 2.7, // X4
        0xd85 => 3.0, // X925
        0xd40 => 1.6, // HiSilicon TaiShan (Kirin 9000s)
        _ => .4,
      };
    }
    if (implementer == 0x51) {
      return switch (part) {
        0x800 || 0x802 => 1.0, // Kryo 2xx/385 Gold (A73/A75 class)
        0x801 || 0x803 || 0x805 => .33, // Kryo Silver (A53/A55 class)
        0x804 => 1.35, // Kryo 485 Gold (A76 class)
        0x001 => 3.0, // Oryon
        _ => .4,
      };
    }
    return .4;
  }

  /// The summed design-weight × clock of every core; null when the cores or
  /// their clocks could not be read.
  static double? cpuScore(List<CpuCore> cores) {
    if (cores.isEmpty || cores.any((core) => core.maxGhz == null)) {
      return null;
    }
    return cores.fold<double>(
      0,
      (sum, core) => sum + _weight(core.implementer, core.part) * core.maxGhz!,
    );
  }

  static FinnModelTier recommend({
    required int? totalRamBytes,
    required String soc,
    required List<CpuCore> cores,
  }) {
    if (totalRamBytes == null || totalRamBytes < minimumRamBytes) {
      return FinnModelTier.standard;
    }
    if (_knownFast.hasMatch(soc)) return FinnModelTier.plus;
    final score = cpuScore(cores);
    return score != null && score >= scoreThreshold
        ? FinnModelTier.plus
        : FinnModelTier.standard;
  }

  /// The cores of this device, from `/proc/cpuinfo` and each core's
  /// `cpuinfo_max_freq`. Empty where the kernel does not say.
  static Future<List<CpuCore>> readCores() async {
    try {
      final info = await File('/proc/cpuinfo').readAsString();
      final cores = <CpuCore>[];
      for (final block in parseCpuInfo(info)) {
        final freq = File(
          '/sys/devices/system/cpu/cpu${block.$1}/cpufreq/cpuinfo_max_freq',
        );
        double? ghz;
        try {
          final khz = int.tryParse((await freq.readAsString()).trim());
          if (khz != null && khz > 0) ghz = khz / 1e6;
        } catch (_) {}
        cores.add(CpuCore(implementer: block.$2, part: block.$3, maxGhz: ghz));
      }
      return cores;
    } catch (_) {
      return const [];
    }
  }

  /// (processor index, implementer, part) for every core block in
  /// `/proc/cpuinfo`.
  @visibleForTesting
  static List<(int, int, int)> parseCpuInfo(String text) {
    final out = <(int, int, int)>[];
    int? index;
    int? implementer;
    int? part;
    void flush() {
      final (i, impl, p) = (index, implementer, part);
      if (i != null && impl != null && p != null) out.add((i, impl, p));
      index = implementer = part = null;
    }

    for (final line in text.split('\n')) {
      final colon = line.indexOf(':');
      if (line.trim().isEmpty) {
        flush();
        continue;
      }
      if (colon < 0) continue;
      final key = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      switch (key) {
        case 'processor':
          index = int.tryParse(value);
        case 'CPU implementer':
          implementer = int.tryParse(value.replaceFirst('0x', ''), radix: 16);
        case 'CPU part':
          part = int.tryParse(value.replaceFirst('0x', ''), radix: 16);
      }
    }
    flush();
    return out;
  }
}

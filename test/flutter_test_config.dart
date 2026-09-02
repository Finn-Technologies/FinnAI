import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final defaultComparator = goldenFileComparator;
  if (defaultComparator is LocalFileComparator) {
    goldenFileComparator = _CrossPlatformGoldenComparator(
      defaultComparator.basedir.resolve('flutter_test_config.dart'),
      precisionTolerance: 0.01,
    );
  }

  await testMain();
}

/// Allows the small rasterization differences produced by Flutter's Linux and
/// macOS test engines while still failing meaningful visual regressions.
class _CrossPlatformGoldenComparator extends LocalFileComparator {
  _CrossPlatformGoldenComparator(
    super.testFile, {
    required this.precisionTolerance,
  }) : assert(
          precisionTolerance >= 0 && precisionTolerance <= 1,
          'precisionTolerance must be between 0 and 1',
        );

  final double precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

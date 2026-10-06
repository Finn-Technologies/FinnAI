import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/container/container_image.dart';

/// Separate from container_test.dart: the binding this needs replaces
/// HttpClient with a fake, and the host tests there need a real one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled runtime file is in the asset bundle', () async {
    // The host serves these from rootBundle; one missing from pubspec.yaml
    // makes the container page fail to load on a device, nowhere else.
    for (final name in ContainerImage.bundled) {
      final data =
          await rootBundle.load('${ContainerImage.assetDirectory}/$name');
      expect(data.lengthInBytes, greaterThan(0), reason: name);
    }
  });
}

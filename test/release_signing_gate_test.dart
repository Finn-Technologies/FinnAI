import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Release Signing Gate Configuration Tests', () {
    test('android/app/build.gradle.kts configures release signing block', () async {
      final buildGradleFile = File('android/app/build.gradle.kts');
      expect(await buildGradleFile.exists(), isTrue, reason: 'build.gradle.kts must exist');

      final content = await buildGradleFile.readAsString();

      expect(content, contains('signingConfigs'), reason: 'signingConfigs block must be configured');
      expect(content, contains('getByName("release")'), reason: 'release signingConfig must exist');
      expect(content, contains('key.properties'), reason: 'release signing must load key.properties');
    });
  });
}

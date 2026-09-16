import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Release Signing Gate Configuration Tests', () {
    test(
      'android/app/build.gradle.kts configures release signing block',
      () async {
        final buildGradleFile = File('android/app/build.gradle.kts');
        expect(
          await buildGradleFile.exists(),
          isTrue,
          reason: 'build.gradle.kts must exist',
        );

        final content = await buildGradleFile.readAsString();

        expect(
          content,
          contains('signingConfigs'),
          reason: 'signingConfigs block must be configured',
        );
        expect(
          content,
          contains('getByName("release")'),
          reason: 'release signingConfig must exist',
        );
        expect(
          content,
          contains('key.properties'),
          reason: 'release signing must load key.properties',
        );
        expect(
          content,
          contains('isMinifyEnabled = true'),
          reason: 'R8 code minification must be enabled for release builds',
        );
        expect(
          content,
          contains('isShrinkResources = true'),
          reason: 'Resource shrinking must be enabled for release builds',
        );
        expect(
          content,
          contains('proguardFiles'),
          reason: 'proguardFiles must be configured for release builds',
        );
      },
    );

    test(
      'android/app/proguard-rules.pro exists and contains keep rules',
      () async {
        final proguardFile = File('android/app/proguard-rules.pro');
        expect(
          await proguardFile.exists(),
          isTrue,
          reason: 'android/app/proguard-rules.pro must exist',
        );

        final content = await proguardFile.readAsString();
        expect(content, contains('io.flutter'));
        expect(content, contains('com.abhiflex.finnai'));
        expect(content, contains('native <methods>'));
      },
    );
  });
}

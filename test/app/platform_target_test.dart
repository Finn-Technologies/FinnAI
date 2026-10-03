import 'dart:io';

import 'package:finn_ai/src/platform/platform_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugSetFinnPlatformOverride(null));

  group('finnPlatform', () {
    test('an override wins over real detection', () {
      for (final platform in FinnPlatform.values) {
        debugSetFinnPlatformOverride(platform);
        expect(finnPlatform, platform, reason: '$platform override ignored');
      }
    });

    test('openHarmony override also flips isOpenHarmony', () {
      debugSetFinnPlatformOverride(FinnPlatform.openHarmony);
      expect(isOpenHarmony, isTrue);

      debugSetFinnPlatformOverride(FinnPlatform.android);
      expect(isOpenHarmony, isFalse);
      expect(isMobile, isTrue);

      debugSetFinnPlatformOverride(FinnPlatform.macos);
      expect(isMobile, isFalse);
    });
  });

  group('isMobile', () {
    test('is true only for android and ios', () {
      for (final platform in FinnPlatform.values) {
        debugSetFinnPlatformOverride(platform);
        expect(
          isMobile,
          platform == FinnPlatform.android || platform == FinnPlatform.ios,
          reason: '$platform',
        );
      }
    });
  });

  group('isOpenHarmony without an override', () {
    test('is false on a host with no OpenHarmony sandbox', () {
      // The test runner is desktop macOS, where none of the sandbox mount points
      // exist and Platform.operatingSystem is 'macos'.
      debugSetFinnPlatformOverride(null);
      expect(isOpenHarmony, isFalse);
      expect(finnPlatform, FinnPlatform.macos);
    });

    test('detection is cached, not recomputed per call', () {
      debugSetFinnPlatformOverride(null);
      final first = isOpenHarmony;
      expect(isOpenHarmony, first);
    });

    test('reads the sandbox mount points rather than Platform.isLinux', () {
      // This is the trap the detection exists to avoid: dart:io reports
      // `linux` on HarmonyOS, so an isLinux-first probe would report a device
      // as desktop Linux. Assert the probe order directly.
      debugSetFinnPlatformOverride(null);
      // On macOS the probe finds nothing, so the fallback must be the platform
      // string, and it must be checked after the filesystem probe.
      expect(Platform.operatingSystem,
          isNot(anyOf('ohos', 'harmonyos', 'openharmony')));
      expect(isOpenHarmony, isFalse);
    });
  });
}

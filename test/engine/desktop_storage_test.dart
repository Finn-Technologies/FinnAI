import 'package:finn_ai/src/engine/profiler/desktop_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDfAvailableBytes', () {
    test('reads the Available column of POSIX df -Pk output', () {
      const out =
          'Filesystem     1024-blocks     Used Available Capacity Mounted on\n'
          '/dev/sda3         15728640 13000000   2728640      83% /\n';
      expect(DesktopProfile.parseDfAvailableBytes(out), 2728640 * 1024);
    });

    test('counts from the right, so a filesystem name with spaces works', () {
      const out = 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
          'my network share 1000 400 600 40% /mnt/share\n';
      expect(DesktopProfile.parseDfAvailableBytes(out), 600 * 1024);
    });

    test('garbage is not a number', () {
      expect(DesktopProfile.parseDfAvailableBytes(''), isNull);
      expect(DesktopProfile.parseDfAvailableBytes('only a header\n'), isNull);
      expect(
        DesktopProfile.parseDfAvailableBytes('h\nshort line\n'),
        isNull,
      );
    });
  });
}

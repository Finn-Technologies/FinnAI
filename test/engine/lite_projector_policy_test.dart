import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/profiler/device_profile.dart';

DeviceProfile _profile({
  required int ramGb,
  ProcessorClass processor = ProcessorClass.balanced,
  bool lowMemory = false,
}) =>
    DeviceProfile(
      totalRamBytes: ramGb * 1000 * 1000 * 1000,
      availableRamBytes: (ramGb - 1) * 1000 * 1000 * 1000,
      processor: processor,
      soc: 'test',
      cores: 8,
      lowMemory: lowMemory,
      supportedAbis: const ['arm64-v8a'],
    );

/// ADR 0004: the 854 MB projector is larger than the 696 MB language model and
/// is needed only for a turn with an image, so a Lite device loads text-only.
void main() {
  test('a 4 GB-or-less device is Lite and defers the projector', () {
    for (final ram in [2, 3]) {
      final profile = _profile(ramGb: ram);
      expect(DeviceProfiler.isLowEnd(profile), isTrue, reason: '$ram GB');
      expect(DeviceProfiler.loadsProjectorEagerly(profile), isFalse);
    }
  });

  test('an entry-class chip is Lite whatever its RAM', () {
    final profile = _profile(ramGb: 6, processor: ProcessorClass.entry);
    expect(DeviceProfiler.loadsProjectorEagerly(profile), isFalse);
  });

  test('the OS low-memory flag makes a device Lite', () {
    final profile = _profile(ramGb: 8, lowMemory: true);
    expect(DeviceProfiler.loadsProjectorEagerly(profile), isFalse);
  });

  test('a capable device keeps the single eager load', () {
    final profile = _profile(ramGb: 8);
    expect(DeviceProfiler.isLowEnd(profile), isFalse);
    expect(DeviceProfiler.loadsProjectorEagerly(profile), isTrue);
  });

  test('the Lite plan is small: 2048 context, two decode threads', () {
    final plan = DeviceProfiler.plan(_profile(ramGb: 3));
    expect(plan.contextSize, 2048);
    expect(plan.threads, lessThanOrEqualTo(2));
    expect(plan.sessionCacheEntries, 1);
  });
}

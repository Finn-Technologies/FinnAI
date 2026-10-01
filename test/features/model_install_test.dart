import 'dart:io';

import 'package:finn_ai/src/app/speech_model_addon.dart';
import 'package:finn_ai/src/app/tts_voices_addon.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';
import 'package:finn_ai/src/features/onboarding/model_install.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSource extends ChangeNotifier implements ModelInstallSource {
  _FakeSource({this.fail = false});

  final bool fail;
  final calls = <String>[];
  bool installed = false;

  @override
  List<FinnModelSpec> get requiredModels => finnModels;

  @override
  double? installProgress;

  @override
  Future<void> install(FinnModelSpec model) async {
    calls.add('model');
    if (fail) throw StateError('no network');
    installProgress = 0.5;
    notifyListeners();
    installProgress = 1;
    installed = true;
    notifyListeners();
  }

  @override
  Future<bool> isInstalled(FinnModelSpec model) async => installed;
}

class _FakeAddon implements InstallAddon {
  _FakeAddon({
    this.total = 100,
    this.alreadyInstalled = false,
    this.failInstall = false,
    this.log,
  });

  final int total;
  final bool alreadyInstalled;
  final bool failInstall;
  final List<String>? log;
  final value = ValueNotifier<double>(0);
  int installs = 0;
  int failures = 0;

  @override
  int get totalBytes => total;

  @override
  ValueListenable<double> get progress => value;

  @override
  Future<bool> isInstalled() async => alreadyInstalled;

  @override
  Future<bool> shouldOfferOnUpgrade() async => !alreadyInstalled;

  @override
  Future<void> install() async {
    installs++;
    log?.add('addon');
    value.value = 0.5;
    if (failInstall) throw StateError('offline');
    value.value = 1;
  }

  @override
  Future<void> markFailed() async => failures++;
}

void main() {
  final modelBytes = finnModels.single.expectedBytes + finnMmproj.expectedBytes;

  test('installs the language model first, then the add-on', () async {
    final source = _FakeSource();
    final order = <String>[];
    final addon = _FakeAddon(log: order);
    final install = ModelInstall(
      source: source,
      addons: [addon],
      onChanged: () {},
    )..attach();
    addTearDown(install.detach);

    await install.run(verificationFailedMessage: 'x');

    expect(source.calls, ['model']);
    expect(order, ['addon']);
    expect(addon.installs, 1);
    expect(install.progress, closeTo(1, 1e-6));
  });

  test('progress spans the model and the add-on, weighted by bytes', () async {
    final source = _FakeSource();
    final addon = _FakeAddon(total: modelBytes ~/ 4);
    final seen = <double>[];
    late ModelInstall install;
    install = ModelInstall(
      source: source,
      addons: [addon],
      onChanged: () => seen.add(install.progress),
    )..attach();
    addTearDown(install.detach);

    await install.run(verificationFailedMessage: 'x');

    // The model is 80% of the bytes, so when it finishes the bar is at 80%,
    // not 100%: it must not claim "done" while the add-on is still coming.
    expect(seen.any((p) => (p - 0.8).abs() < 0.01), isTrue);
    expect(seen, orderedEquals([...seen]..sort()));
    expect(seen.last, closeTo(1, 1e-9));
  });

  test('progress is only the model when there are no add-ons', () async {
    final source = _FakeSource();
    final install = ModelInstall(source: source, onChanged: () {})..attach();
    addTearDown(install.detach);

    await install.run(verificationFailedMessage: 'x');

    expect(install.progress, closeTo(1, 1e-9));
    expect(install.totalBytes, modelBytes);
  });

  test('an add-on that fails does not fail the install', () async {
    final source = _FakeSource();
    final addon = _FakeAddon(failInstall: true);
    final install = ModelInstall(
      source: source,
      addons: [addon],
      onChanged: () {},
    );

    await install.run(verificationFailedMessage: 'x');

    expect(addon.failures, 1,
        reason: 'remembered, so a later offline launch is not held up');
  });

  test('a failing language model still fails the install, add-on untouched',
      () async {
    final source = _FakeSource(fail: true);
    final addon = _FakeAddon();
    final install = ModelInstall(
      source: source,
      addons: [addon],
      onChanged: () {},
    );

    await expectLater(
      install.run(verificationFailedMessage: 'x'),
      throwsA(isA<StateError>()),
    );
    expect(addon.installs, 0);
  });

  test('an unverifiable language model throws the verification message',
      () async {
    final source = _FakeSource()..installed = false;
    final bad = _UnverifiedSource();
    final install = ModelInstall(source: bad, onChanged: () {});

    await expectLater(
      install.run(verificationFailedMessage: 'could not verify'),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', 'could not verify')),
    );
    expect(source.calls, isEmpty);
  });

  test('an add-on that is already installed is not downloaded again', () async {
    final addon = _FakeAddon(alreadyInstalled: true);
    final install = ModelInstall(
      source: _FakeSource(),
      addons: [addon],
      onChanged: () {},
    );

    await install.run(verificationFailedMessage: 'x');

    expect(addon.installs, 0);
  });

  test('leaving the screen stops further add-ons', () async {
    final addon = _FakeAddon();
    final install = ModelInstall(
      source: _FakeSource(),
      addons: [addon],
      onChanged: () {},
    );

    await install.run(
      verificationFailedMessage: 'x',
      isCancelled: () => true,
    );

    expect(addon.installs, 0);
  });

  group('SpeechModelAddon', () {
    test('is offered on upgrade only until it has failed once', () async {
      // An empty manifest counts as installed, so use a missing one.
      final missing = _MissingStore();
      final addon = SpeechModelAddon(store: missing);

      expect(await addon.shouldOfferOnUpgrade(), isTrue);

      await addon.markFailed();

      expect(await addon.shouldOfferOnUpgrade(), isFalse);
    });

    test('is not offered when it is already installed', () async {
      final root = Directory.systemTemp.createTempSync('addon_test');
      addTearDown(() => root.deleteSync(recursive: true));
      final addon = SpeechModelAddon(
        store: SttModelStore(root: root, files: const []),
      );

      expect(await addon.shouldOfferOnUpgrade(), isFalse);
    });

    test('mirrors the store download progress', () async {
      final missing = _MissingStore();
      final addon = SpeechModelAddon(store: missing);

      missing.status.value = const SpeechModelStatus(
        SpeechModelPhase.downloading,
        progress: 0.25,
      );

      expect(addon.progress.value, 0.25);
    });
  });

  group('TtsVoicesAddon', () {
    test('sizes itself for English plus the phone\'s language', () {
      final english = TtsVoicesAddon(
        deviceLanguage: 'en',
        store: _VoiceStore(),
      );
      final german = TtsVoicesAddon(
        deviceLanguage: 'de',
        store: _VoiceStore(),
      );

      expect(english.totalBytes, ttsVoiceFor('en')!.bytes);
      expect(
        german.totalBytes,
        ttsVoiceFor('en')!.bytes + ttsVoiceFor('de')!.bytes,
      );
    });

    test('installs every missing voice and reports progress to the end',
        () async {
      final store = _VoiceStore();
      final addon = TtsVoicesAddon(deviceLanguage: 'de', store: store);
      final seen = <double>[];
      addon.progress.addListener(() => seen.add(addon.progress.value));

      await addon.install();

      expect(store.installed, ['en', 'de']);
      expect(seen, orderedEquals([...seen]..sort()));
      expect(seen.last, closeTo(1, 1e-9));
      expect(await addon.isInstalled(), isTrue);
    });

    test('skips what is already there', () async {
      final store = _VoiceStore()..have.add('en');
      final addon = TtsVoicesAddon(deviceLanguage: 'de', store: store);

      await addon.install();

      expect(store.installed, ['de']);
    });

    test('is offered on upgrade until a failed attempt is remembered',
        () async {
      final store = _VoiceStore();
      final addon = TtsVoicesAddon(deviceLanguage: 'en', store: store);

      expect(await addon.shouldOfferOnUpgrade(), isTrue);
      await addon.markFailed();
      expect(await addon.shouldOfferOnUpgrade(), isFalse);
    });

    test('is not offered once installed, and a success clears the failure',
        () async {
      final store = _VoiceStore();
      final addon = TtsVoicesAddon(deviceLanguage: 'en', store: store);
      await addon.markFailed();

      await addon.install();

      expect(await addon.shouldOfferOnUpgrade(), isFalse);
      expect(store.failed, isFalse);
    });
  });
}

class _VoiceStore extends TtsVoiceStore {
  final have = <String>{};
  final installed = <String>[];
  bool failed = false;

  @override
  Future<bool> isInstalled(TtsVoice voice) async =>
      have.contains(voice.language);

  @override
  Future<void> install(
    TtsVoice voice, {
    void Function(int received)? onProgress,
  }) async {
    onProgress?.call(voice.bytes ~/ 2);
    onProgress?.call(voice.bytes);
    have.add(voice.language);
    installed.add(voice.language);
  }

  @override
  Future<bool> installFailedBefore() async => failed;

  @override
  Future<void> markInstallFailed() async => failed = true;

  @override
  Future<void> clearInstallFailed() async => failed = false;
}

class _UnverifiedSource extends ChangeNotifier implements ModelInstallSource {
  @override
  List<FinnModelSpec> get requiredModels => finnModels;

  @override
  double? get installProgress => null;

  @override
  Future<void> install(FinnModelSpec model) async {}

  @override
  Future<bool> isInstalled(FinnModelSpec model) async => false;
}

class _MissingStore extends SttModelStore {
  bool failed = false;

  @override
  Future<bool> isInstalled() async => false;

  @override
  Future<bool> installFailedBefore() async => failed;

  @override
  Future<void> markInstallFailed() async => failed = true;
}

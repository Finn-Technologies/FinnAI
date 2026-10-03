import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locales shipped by the app, with English as the template.
const List<String> _locales = ['en', 'de', 'es', 'fr', 'it'];
const String _arbDir = 'lib/l10n';

Map<String, Object?> _readArb(String locale) {
  final file = File('$_arbDir/app_$locale.arb');
  expect(file.existsSync(), isTrue, reason: '${file.path} should exist');
  final decoded = jsonDecode(file.readAsStringSync());
  return (decoded as Map).cast<String, Object?>();
}

/// Localizable entries only: `@@locale` and `@key` metadata are not strings.
Set<String> _keys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

/// Every `{token}` in [value], including those nested inside ICU plural and
/// select branches. `@key` metadata lives outside this map, so `placeholders`
/// blocks are never visited.
Set<String> _tokens(Object? value) {
  if (value is String) {
    return RegExp(r'\{(\w+)').allMatches(value).map((m) => m[1]!).toSet();
  }
  if (value is Map) {
    return value.values.expand(_tokens).toSet();
  }
  return const <String>{};
}

/// Strings that are legitimately identical to English: product and model
/// names, technology terms, format-only templates, and words that are spelled
/// the same in the target language (e.g. French "Instructions").
const Map<String, String> _identicalAllowlist = {
  'appBrandFinnAI': 'product name',
  'appTitle': 'product name',
  'chatFinnAI': 'product name',
  'settingsInferenceEngineValue': 'engine name',
  'settingsModelArchitectureValue': 'model name',
  'deviceScreenBluetooth': 'technology name',
  'deviceScreenNfc': 'technology name',
  'deviceScreenVpn': 'technology name',
  'deviceScreenWifi': 'technology name',
  'deviceScreenHotspot': 'loanword (de/it)',
  'deviceScreenDisplay': 'loanword (de)',
  'deviceScreenApplications': 'loanword (de)',
  'deviceActionVolume': 'cognate (fr/it)',
  'deviceActionsTitle': 'cognate (fr)',
  'settingsActionsRow': 'cognate (fr)',
  'attachmentPhotos': 'cognate (fr)',
  'chatSources': 'cognate (fr)',
  'flowsEditorInstructions': 'cognate (fr)',
  'flowsEditorName': 'cognate (de)',
  'flowsInstructionLabel': 'cognate (fr)',
  'youNameLabel': 'cognate (de)',
  'flowsTitle': 'feature name loanword',
  'chatHistory': 'loanword (de/es/fr/it)',
  'creationsKindApp': 'loanword',
  'creationsKindWidget': 'loanword',
  'creationsFilterApps': 'loanword',
  'creationsFilterWidgets': 'loanword',
  'onboardingInstallProgressStatus': 'placeholder-only template',
  'commonNo': 'cognate (es/it)',
  'creationsSlotTitle': 'cognate (de: Name)',
  'creationsSlotEmoji': 'loanword',
  'creationsAccentMint': 'cognate (de: Mint)',
  'creationsAccentRose': 'cognate (fr: Rose)',
  'flowsSlotMessage': 'cognate (fr: Message)',
  'creationsTemplateTracker': 'loanword (de: Tracker)',
  'flowsSlotPause': 'cognate (de: Pause)',
  'flowsParamText': 'cognate (de: Text)',
  'flowsFieldMessage': 'cognate (fr: Message)',
  'flowsFieldCondition': 'cognate (fr: Condition)',
  'flowsUnitMinutes': 'cognate (fr: minutes)',
  'flowsParamDirection': 'cognate (fr: Direction)',
  'flowsParamBody': 'cognate (fr: Message)',
  'creationsAccentLime': 'cognate (it: Lime)',
  'creationsAccentViolet': 'cognate (fr: Violet)',
  'dataChats': 'cognate or name',
  'dataModel': 'cognate or name',
  'hubAboutSub': 'cognate or name',
  'hubModelTitle': 'cognate or name',
  'modelVersion': 'cognate or name',
  'voiceSpeedNormal': 'cognate or name',
  'ctxContacts': 'cognate or name',
  'ctxNotifications': 'cognate or name',
  'ctxPhotos': 'cognate or name',
  'plusFlow': 'cognate or name',
  'plusWidget': 'cognate or name',
  'searchChatsHeading': 'cognate or name',
  'plusMiniApp': 'cognate or name',
  'plusPhoto': 'cognate or name',
  'youPrivacyTitle': 'cognate or name',
  'flowsGuidesTitle': 'cognate or name',
};

void main() {
  late Map<String, Map<String, Object?>> arbs;

  setUpAll(() {
    arbs = {for (final locale in _locales) locale: _readArb(locale)};
  });

  test('no ARB declares a key twice', () {
    // JSON parsers keep the last duplicate silently, so a second definition of
    // an existing key quietly replaces the first one's copy (it once changed a
    // button label with no error anywhere).
    for (final locale in _locales) {
      final text = File('lib/l10n/app_$locale.arb').readAsStringSync();
      final seen = <String>{};
      final duplicates = <String>[];
      for (final match
          in RegExp(r'^  "([^"]+)":', multiLine: true).allMatches(text)) {
        if (!seen.add(match.group(1)!)) duplicates.add(match.group(1)!);
      }
      expect(duplicates, isEmpty, reason: '$locale repeats $duplicates');
    }
  });

  test('each ARB declares its own locale', () {
    for (final locale in _locales) {
      expect(arbs[locale]!['@@locale'], locale);
    }
  });

  test('all five locales expose the same key set as the English template', () {
    final template = _keys(arbs['en']!);
    expect(template, isNotEmpty);
    for (final locale in _locales.where((l) => l != 'en')) {
      final keys = _keys(arbs[locale]!);
      expect(
        keys.difference(template),
        isEmpty,
        reason: '$locale has keys the template lacks',
      );
      expect(
        template.difference(keys),
        isEmpty,
        reason: '$locale is missing template keys',
      );
    }
  });

  test('every locale keeps the same ICU placeholders as the template', () {
    final template = arbs['en']!;
    for (final locale in _locales.where((l) => l != 'en')) {
      final arb = arbs[locale]!;
      for (final key in _keys(template)) {
        expect(
          _tokens(arb[key]),
          _tokens(template[key]),
          reason: '$locale.$key placeholder tokens diverge from en',
        );
      }
    }
  });

  test('no locale still holds English copy outside the allowlist', () {
    final template = arbs['en']!;
    for (final locale in _locales.where((l) => l != 'en')) {
      final arb = arbs[locale]!;
      final leftovers = <String>[
        for (final key in _keys(template))
          if (arb[key] == template[key] &&
              !_identicalAllowlist.containsKey(key))
            key,
      ];
      expect(
        leftovers,
        isEmpty,
        reason: '$locale still holds the English string for $leftovers',
      );
    }
  });
}

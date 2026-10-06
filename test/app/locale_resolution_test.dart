import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  test('a language FinnAI does not ship falls back to English, not German', () {
    expect(finnResolveLocale(const [Locale('zh', 'CN')], supported),
        const Locale('en'));
    expect(
        finnResolveLocale(const [Locale('ja')], supported), const Locale('en'));
    expect(finnResolveLocale(null, supported), const Locale('en'));
  });

  test('a regional variant gets its language', () {
    expect(finnResolveLocale(const [Locale('de', 'AT')], supported),
        const Locale('de'));
  });

  test('the first shipped language in the preference list wins', () {
    expect(
      finnResolveLocale(
          const [Locale('zh'), Locale('fr', 'CA'), Locale('en')], supported),
      const Locale('fr'),
    );
  });
}

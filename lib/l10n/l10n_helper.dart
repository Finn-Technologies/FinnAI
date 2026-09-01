import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// Never-null l10n accessor — falls back to English when no delegate
/// is present (e.g. tests pumping a widget without MaterialApp delegates).
/// Use [L10n.of(context).<key>] instead of AppLocalizations.of(context)!.
class L10n {
  static AppLocalizations of(BuildContext context) =>
      AppLocalizations.of(context) ?? AppLocalizationsEn();
}

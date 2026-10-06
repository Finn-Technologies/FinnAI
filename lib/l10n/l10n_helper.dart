import 'package:flutter/widgets.dart';
import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/app_localizations_en.dart';

/// Never-null l10n accessor — falls back to English when no delegate
/// is present (e.g. tests pumping a widget without MaterialApp delegates).
/// Use [L10n.of(context).<key>] instead of AppLocalizations.of(context)!.
class L10n {
  static AppLocalizations of(BuildContext context) =>
      AppLocalizations.of(context) ?? AppLocalizationsEn();
}

/// Picks the app's language from the system's preference list: the first
/// language FinnAI ships (by language code, so `de_AT` gets German), and
/// English when none of them is. Flutter's own fallback is the *first*
/// supported locale, which gen-l10n sorts alphabetically: a Chinese or
/// Japanese phone came up in German.
Locale finnResolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return supported.firstWhere(
    (locale) => locale.languageCode == 'en',
    orElse: () => supported.first,
  );
}

/// Maps an engine [FinnStatusKey] to a localized display string.
///
/// Values the engine composes from dynamic parts (artifact downloads) get the
/// label recovered from the English [status] text so the sentence can be
/// rebuilt in the active language; [FinnStatusKey.error] and any future
/// unmapped value fall back to the engine's friendly English text.
String localizedEngineStatus(
  BuildContext context,
  FinnStatusKey key,
  String status,
) {
  final l10n = L10n.of(context);
  switch (key) {
    case FinnStatusKey.ready:
      return l10n.statusReady;
    case FinnStatusKey.optimizedAutomatically:
      return l10n.statusOptimizedAutomatically;
    case FinnStatusKey.modelReady:
      return l10n.statusModelReady;
    case FinnStatusKey.downloadPaused:
      return l10n.statusDownloadPaused;
    case FinnStatusKey.modelRemoved:
      return l10n.statusModelRemoved;
    case FinnStatusKey.checkingWeb:
      return l10n.statusCheckingWeb;
    case FinnStatusKey.searchingBrowser:
      return l10n.statusSearchingBrowser;
    case FinnStatusKey.thinkingOnDevice:
      return l10n.statusThinkingOnDevice;
    case FinnStatusKey.generatedLocally:
      return l10n.statusGeneratedLocally;
    case FinnStatusKey.stopped:
      return l10n.statusStopped;
    case FinnStatusKey.readyAfterRuntimeReset:
      return l10n.statusReadyAfterRuntimeReset;
    case FinnStatusKey.optimizingForDevice:
      return l10n.statusOptimizingForDevice;
    case FinnStatusKey.optimizedForDevice:
      return l10n.statusOptimizedForDevice;
    case FinnStatusKey.checkingDownload:
      return l10n.statusCheckingDownload;
    case FinnStatusKey.downloadingModel:
      return l10n.statusDownloadingModel;
    case FinnStatusKey.downloadingArtifact:
      final artifact = status.replaceFirst(RegExp('^Downloading\\s+'), '');
      return l10n.statusDownloadingArtifact(artifact);
    case FinnStatusKey.verifyingArtifact:
      final artifact = status.replaceFirst(RegExp('^Verifying\\s+'), '');
      return l10n.statusVerifyingArtifact(artifact);
    case FinnStatusKey.loadingModel:
      return l10n.statusLoadingModel;
    case FinnStatusKey.error:
      return status;
  }
}

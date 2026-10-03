import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// The words FinnAI Code shows for things the code only knows as codes:
/// failures, refusals, permission modes and numbers.
abstract final class CodeText {
  /// What went wrong, in the user's language. [code] is a
  /// [CodeErrorCode] value; [detail] is the provider's or engine's own words.
  static String error(AppLocalizations l10n, String code, String detail) {
    if (code.startsWith(CodeErrorCode.providerPrefix)) {
      final name = code.substring(CodeErrorCode.providerPrefix.length);
      final failure = ProviderFailure.values
          .where((value) => value.name == name)
          .firstOrNull;
      return failureText(l10n, failure ?? ProviderFailure.unknown);
    }
    return switch (code) {
      CodeErrorCode.stepLimit => l10n.codeErrorStepLimit,
      CodeErrorCode.repeating => l10n.codeErrorRepeating,
      CodeErrorCode.empty => l10n.codeErrorEmpty,
      CodeErrorCode.cutOff => l10n.codeErrorCutOff,
      CodeErrorCode.malformed => l10n.codeErrorMalformedAction,
      _ => l10n.codeErrorEngine(detail.isEmpty ? '—' : detail),
    };
  }

  static String failureText(AppLocalizations l10n, ProviderFailure failure) =>
      switch (failure) {
        ProviderFailure.auth => l10n.codeErrorAuth,
        ProviderFailure.planNoApi => l10n.codeErrorPlanNoApi,
        ProviderFailure.paymentRequired => l10n.codeErrorPayment,
        ProviderFailure.rateLimited => l10n.codeErrorRate,
        ProviderFailure.wrongEndpoint => l10n.codeErrorWrongEndpoint,
        ProviderFailure.badRequest => l10n.codeErrorBadRequest,
        ProviderFailure.server => l10n.codeErrorServer,
        ProviderFailure.network => l10n.codeErrorNetwork,
        ProviderFailure.timeout => l10n.codeErrorTimeout,
        ProviderFailure.malformed => l10n.codeErrorMalformed,
        ProviderFailure.unknown => l10n.codeErrorUnknown,
      };

  /// Why an action was refused before it ran.
  static String denied(AppLocalizations l10n, CodeAction action) =>
      switch (action.deniedReason) {
        PolicyReason.blockedProgram =>
          l10n.codeDeniedBlockedProgram(action.deniedDetail),
        PolicyReason.network => l10n.codeDeniedNetwork,
        PolicyReason.outsideWorkspace =>
          l10n.codeDeniedOutside(action.deniedDetail),
        PolicyReason.parentPath => l10n.codeDeniedParent,
        _ => l10n.codeDeniedOther,
      };

  static String permission(AppLocalizations l10n, CodePermissionMode mode) =>
      switch (mode) {
        CodePermissionMode.askEveryTime => l10n.codePermissionAsk,
        CodePermissionMode.acceptEdits => l10n.codePermissionEdits,
        CodePermissionMode.autoRun => l10n.codePermissionAuto,
      };

  static String providerName(AppLocalizations l10n, CodeProvider provider) =>
      provider == CodeProvider.custom
          ? l10n.codeProviderCustomName
          : provider.displayName;

  static String providerDescription(
    AppLocalizations l10n,
    CodeProvider provider,
  ) =>
      switch (provider) {
        CodeProvider.finn => l10n.codeModelsOnDeviceSub,
        CodeProvider.openRouter => l10n.codeProviderDescOpenRouter,
        CodeProvider.commandCode => l10n.codeProviderDescCommandCode,
        CodeProvider.openCodeZen => l10n.codeProviderDescZen,
        CodeProvider.openCodeGo => l10n.codeProviderDescGo,
        CodeProvider.custom => l10n.codeProviderDescCustom,
      };

  /// `1.4 MB`, `820 KB`, `0 B`.
  static String bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).round()} KB';
    final mb = value / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  /// `$1.25`, `$0.0042` — more places for small amounts, so a cent of spend
  /// does not read as zero.
  static String dollars(double value) {
    if (value == 0) return r'$0';
    if (value.abs() < 0.01) return '\$${value.toStringAsFixed(4)}';
    return '\$${value.toStringAsFixed(2)}';
  }

  /// `8K`, `128K`, `1M` for a context window.
  static String tokens(int value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '${(value / 1000).round()}K';
    return '$value';
  }
}

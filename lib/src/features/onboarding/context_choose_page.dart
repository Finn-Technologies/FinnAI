import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/features/onboarding/wide_step.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// After "Yes": which kinds of device context FinnAI may see.
///
/// Every kind starts on, because the user just said yes; each can be switched
/// off here or later in Settings.
class ContextChoosePage extends StatelessWidget {
  const ContextChoosePage({
    super.key,
    required this.onBack,
    required this.onNext,
    this.store,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final ContextConsentStore? store;

  static const _icons = {
    'calendar': FluxIcons.calendar,
    'contacts': FluxIcons.you,
    'notifications': FluxIcons.alarm,
    'photos': FluxIcons.image,
    'files': FluxIcons.note,
    'location': FluxIcons.flag,
  };

  Widget _row(
    BuildContext context,
    ContextConsentStore consent,
    String key,
    Map<String, (String, String)> titles,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: FluxColors.tileOf(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FluxColors.controlOf(context),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FluxIcon(
                    icon: _icons[key]!,
                    size: 22,
                    color: FluxColors.actionOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titles[key]!.$1,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      titles[key]!.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FluxColors.actionOf(context),
                          ),
                    ),
                  ],
                ),
              ),
              FinnSwitch(
                value: consent.categoryOn(key),
                label: titles[key]!.$1,
                onChanged: (v) => consent.setCategory(key, v),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final consent = store ?? ContextConsentStore.instance;
    final titles = {
      'calendar': (l10n.ctxCalendar, l10n.ctxCalendarSub),
      'contacts': (l10n.ctxContacts, l10n.ctxContactsSub),
      'notifications': (l10n.ctxNotifications, l10n.ctxNotificationsSub),
      'photos': (l10n.ctxPhotos, l10n.ctxPhotosSub),
      'files': (l10n.ctxFiles, l10n.ctxFilesSub),
      'location': (l10n.ctxLocation, l10n.ctxLocationSub),
    };
    final wide = MediaQuery.sizeOf(context);
    if (wideStepFits(BoxConstraints.tight(wide))) {
      return ListenableBuilder(
        listenable: consent,
        builder: (context, _) => WideStepLayout(
          artwork: FigmaAssets.artworkConsent,
          title: l10n.onboardingChooseTitle,
          progress: 4,
          onBack: onBack,
          onNext: onNext,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingChooseBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FluxColors.actionOf(context),
                    ),
              ),
              const SizedBox(height: 20),
              for (final key in ContextConsentStore.categoryKeys)
                _row(context, consent, key, titles),
            ],
          ),
        ),
      );
    }
    final bottom = FluxBottomInset.bottomOf(context);
    // Matches _StepPage: the bar clears the nav bar plus a small lift so it
    // never sits on the glass, on small and large screens alike.
    const lift = 12.0;
    return ColoredBox(
      color: FluxColors.controlOf(context),
      child: ListenableBuilder(
        listenable: consent,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 32,
                  20,
                  10,
                ),
                children: [
                  Text(
                    l10n.onboardingChooseTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.onboardingChooseBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FluxColors.actionOf(context),
                        ),
                  ),
                  const SizedBox(height: 30),
                  for (final key in ContextConsentStore.categoryKeys)
                    _row(context, consent, key, titles),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottom + lift),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Circle(
                    key: const ValueKey('onboarding-back'),
                    label: l10n.commonBack,
                    onTap: onBack,
                    mirrored: true,
                  ),
                  _Circle(
                    key: const ValueKey('onboarding-next'),
                    label: l10n.commonNext,
                    onTap: onNext,
                    dark: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    super.key,
    required this.label,
    required this.onTap,
    this.dark = false,
    this.mirrored = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool dark;
  final bool mirrored;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color:
              dark ? FluxColors.actionOf(context) : FluxColors.tileOf(context),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 60,
              child: Center(
                child: Transform.flip(
                  flipX: mirrored,
                  child: FigmaSvg(
                    asset: FigmaAssets.stepNext,
                    width: 36,
                    height: 36,
                    color: dark
                        ? FluxColors.actionInkOf(context)
                        : FluxColors.inkOf(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

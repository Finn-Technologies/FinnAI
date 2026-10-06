import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The context kinds in the order the design lists them.
List<({String key, IconData icon, String title, String sub})> contextKinds(
        AppLocalizations l10n) =>
    [
      (
        key: 'calendar',
        icon: FluxIcons.calendar,
        title: l10n.ctxCalendar,
        sub: l10n.ctxCalendarSub,
      ),
      (
        key: 'contacts',
        icon: FluxIcons.contacts,
        title: l10n.ctxContacts,
        sub: l10n.ctxContactsSub,
      ),
      (
        key: 'notifications',
        icon: FluxIcons.notifications,
        title: l10n.ctxNotifications,
        sub: l10n.ctxNotificationsSub,
      ),
      (
        key: 'photos',
        icon: FluxIcons.image,
        title: l10n.ctxPhotos,
        sub: l10n.ctxPhotosSub,
      ),
      (
        key: 'files',
        icon: FluxIcons.file,
        title: l10n.ctxFiles,
        sub: l10n.ctxFilesSub,
      ),
      (
        key: 'location',
        icon: FluxIcons.location,
        title: l10n.ctxLocation,
        sub: l10n.ctxLocationSub,
      ),
    ];

class SettingsAccessPage extends StatelessWidget {
  const SettingsAccessPage({super.key, this.onOpenActions});

  final VoidCallback? onOpenActions;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final store = ContextConsentStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final kinds = contextKinds(l10n);
        return FinnPage(
          title: l10n.hubAccessTitle,
          children: [
            FinnCaption(l10n.accessIntro),
            FinnReveal(
              child: FinnTile(
                icon: FluxIcons.chip,
                title: l10n.accessMaster,
                subtitle: l10n.accessMasterSub,
                trailing: FinnSwitch(
                  value: store.granted,
                  label: l10n.accessMaster,
                  onChanged: (v) => unawaited(store.setGranted(v)),
                ),
              ),
            ),
            for (var i = 0; i < kinds.length; i++)
              FinnReveal(
                index: i + 1,
                child: Opacity(
                  opacity: store.granted ? 1 : .5,
                  child: FinnTile(
                    icon: kinds[i].icon,
                    title: kinds[i].title,
                    subtitle: kinds[i].sub,
                    trailing: FinnSwitch(
                      value: store.categoryOn(kinds[i].key),
                      label: kinds[i].title,
                      onChanged: store.granted
                          ? (v) => unawaited(
                                store.setCategory(kinds[i].key, v),
                              )
                          : null,
                    ),
                  ),
                ),
              ),
            if (onOpenActions != null)
              FinnReveal(
                index: kinds.length + 1,
                child: FinnTile(
                  icon: FluxIcons.magic,
                  title: l10n.accessActions,
                  subtitle: l10n.accessActionsSub,
                  onTap: onOpenActions,
                ),
              ),
          ],
        );
      },
    );
  }
}

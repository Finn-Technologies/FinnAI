import 'package:flutter/widgets.dart';
import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

String youCategoryLabel(AppLocalizations l10n, YouCategory category) =>
    switch (category) {
      YouCategory.people => l10n.youCatPeople,
      YouCategory.work => l10n.youCatWork,
      YouCategory.routines => l10n.youCatRoutines,
      YouCategory.preferences => l10n.youCatPreferences,
      YouCategory.places => l10n.youCatPlaces,
      YouCategory.interests => l10n.youCatInterests,
    };

IconData youCategoryIcon(YouCategory category) => switch (category) {
      YouCategory.people => FluxIcons.you,
      YouCategory.work => FluxIcons.task,
      YouCategory.routines => FluxIcons.alarm,
      YouCategory.preferences => FluxIcons.check,
      YouCategory.places => FluxIcons.flag,
      YouCategory.interests => FluxIcons.magic,
    };

/// "12 minutes ago", "3 days ago": how long since [time], in the user's words.
String youWhen(AppLocalizations l10n, DateTime time, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(time);
  if (age.inMinutes < 1) return l10n.youWhenJustNow;
  if (age.inMinutes < 60) return l10n.youWhenMinutes(age.inMinutes);
  if (age.inHours < 24) return l10n.youWhenHours(age.inHours);
  return l10n.youWhenDays(age.inDays);
}

/// Where a memory came from, as one short line.
String youSeenLine(AppLocalizations l10n, YouMemory memory) =>
    memory.sources.isEmpty
        ? l10n.youAddedByYou
        : l10n.youSeenIn(memory.sources.take(2).join(', '));

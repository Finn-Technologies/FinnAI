import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// Human-readable form of a conversation's last update, in the UI language.
///
/// Exactly three patterns are used, so the list stays compact and no new
/// wording is introduced: [DateFormat.Hm] for a time earlier today,
/// [DateFormat.MMMd] for another day in the same year, and [DateFormat.yMMMd]
/// for anything older. The pattern's locale comes from the active
/// [Localizations] scope, so month names and the clock format match the app's
/// language.
String formatConversationTimestamp(
  BuildContext context,
  DateTime updatedAt, {
  DateTime? now,
}) {
  final locale = Localizations.localeOf(context).toString();
  final local = updatedAt.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final sameDay = local.year == reference.year &&
      local.month == reference.month &&
      local.day == reference.day;
  if (sameDay) {
    return DateFormat.Hm(locale).format(local);
  }
  if (local.year == reference.year) {
    return DateFormat.MMMd(locale).format(local);
  }
  return DateFormat.yMMMd(locale).format(local);
}

/// The timestamp shown on a conversation row in the history list.
///
/// [now] is a test seam: production callers omit it and the widget falls back
/// to the wall clock.
class ConversationTimestamp extends StatelessWidget {
  const ConversationTimestamp({super.key, required this.updatedAt, this.now});

  final DateTime updatedAt;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatConversationTimestamp(context, updatedAt, now: now),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: FluxColors.mutedOf(context)),
    );
  }
}

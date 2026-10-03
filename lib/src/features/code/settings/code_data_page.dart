import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

/// Where FinnAI Code keeps things, and the one button that removes all of it.
class CodeDataPage extends StatelessWidget {
  const CodeDataPage({super.key, required this.services});

  final CodeServices services;

  Future<void> _delete(BuildContext context) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showFinnConfirm(
      context,
      title: l10n.codeDataDeleteTitle,
      body: l10n.codeDataDeleteBody,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (confirmed != true) return;
    final failures = await services.deleteAll();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failures.isEmpty
                ? l10n.codeDataDeleted
                : l10n.settingsDeleteAllDataPartialFailure(failures.join(', ')),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FinnPage(
      title: l10n.codeDataTitle,
      children: [
        FinnCaption(l10n.codeDataNote),
        FinnTile(
          icon: CodeIcons.trash,
          title: l10n.codeDataDelete,
          subtitle: l10n.codeDataDeleteSub,
          destructive: true,
          chevron: false,
          onTap: () => _delete(context),
        ),
      ],
    );
  }
}

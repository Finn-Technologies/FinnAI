import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

/// What the project folders take up, what the command sandbox is, and a way
/// to empty every folder.
class CodeWorkspacePage extends StatefulWidget {
  const CodeWorkspacePage({super.key, required this.services});

  final CodeServices services;

  @override
  State<CodeWorkspacePage> createState() => _CodeWorkspacePageState();
}

class _CodeWorkspacePageState extends State<CodeWorkspacePage> {
  int? _bytes;
  int _folders = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_measure());
  }

  Future<void> _measure() async {
    var bytes = 0;
    var folders = 0;
    for (final session in widget.services.sessions.sessions) {
      final workspace = await widget.services.sessions.workspaceOf(session.id);
      if (await workspace.root.exists()) folders++;
      bytes += await workspace.sizeBytes();
    }
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _folders = folders;
      });
    }
  }

  Future<void> _clear() async {
    final l10n = L10n.of(context);
    final confirmed = await showFinnConfirm(
      context,
      title: l10n.codeWorkspaceClearTitle,
      body: l10n.codeWorkspaceClearBody,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (confirmed != true) return;
    await widget.services.agent.stop();
    for (final session in widget.services.sessions.sessions) {
      final workspace = await widget.services.sessions.workspaceOf(session.id);
      try {
        await workspace.deleteAll();
      } on FileSystemException {
        // A folder in use is emptied next time.
      }
    }
    await _measure();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final bytes = _bytes;
    return FinnPage(
      title: l10n.codeWorkspaceTitle,
      children: [
        FinnCaption(
          widget.services.runner.environment == CommandEnvironment.container
              ? l10n.codeContainerIntro
              : l10n.codeSandboxNote,
        ),
        if (bytes != null)
          FinnTile(
            icon: CodeIcons.folder,
            title: l10n.codeWorkspaceUsed(CodeText.bytes(bytes), '$_folders'),
            chevron: false,
          ),
        FinnTile(
          icon: CodeIcons.trash,
          title: l10n.codeWorkspaceClear,
          destructive: true,
          chevron: false,
          onTap: bytes == null || bytes == 0 ? null : _clear,
        ),
      ],
    );
  }
}

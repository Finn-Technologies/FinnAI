import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The project folder of the session on screen: what the agent made, in
/// folders you can walk through, with each file readable and deletable.
class CodeFilesPage extends StatefulWidget {
  const CodeFilesPage({super.key, required this.services, this.onBack});

  final CodeServices services;
  final VoidCallback? onBack;

  @override
  State<CodeFilesPage> createState() => _CodeFilesPageState();
}

class _CodeFilesPageState extends State<CodeFilesPage> {
  CodeWorkspace? _workspace;
  List<WorkspaceEntry>? _entries;
  String _directory = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final session = widget.services.sessions.activeOrLatest;
    if (session == null) {
      if (mounted) setState(() => _entries = const []);
      return;
    }
    final workspace =
        _workspace ??= await widget.services.sessions.workspaceOf(session.id);
    List<WorkspaceEntry> entries;
    try {
      entries = await workspace.list(directory: _directory);
    } on WorkspaceEscape {
      entries = const [];
    }
    if (mounted) setState(() => _entries = entries);
  }

  void _enter(String directory) {
    _directory = directory;
    unawaited(_load());
  }

  String get _parent {
    final parts = _directory.split('/')..removeLast();
    return parts.join('/');
  }

  Future<void> _open(WorkspaceEntry entry) async {
    if (entry.isDirectory) {
      _enter(entry.path);
      return;
    }
    await Navigator.of(context).push(
      FinnPageRoute<void>(
        child: _FileViewPage(workspace: _workspace!, path: entry.path),
      ),
    );
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = widget.services.sessions.activeOrLatest;
    final entries = _entries;
    return FinnPage(
      title:
          _directory.isEmpty ? l10n.codeFilesTitle : _directory.split('/').last,
      onBack: _directory.isEmpty ? widget.onBack : () => _enter(_parent),
      children: [
        if (session == null)
          FinnCaption(l10n.codeFilesNoSession)
        else if (entries == null)
          const SizedBox.shrink()
        else ...[
          if (_directory.isNotEmpty)
            FinnReveal(
              child: FinnTile(
                icon: CodeIcons.back,
                title: '..',
                onTap: () => _enter(_parent),
                chevron: false,
              ),
            ),
          if (entries.isEmpty && _directory.isEmpty)
            FinnCaption(l10n.codeFilesEmpty),
          for (final (i, entry) in entries.indexed)
            FinnReveal(
              index: i + 1,
              child: FinnTile(
                icon: entry.isDirectory ? CodeIcons.folder : CodeIcons.file,
                title: entry.name,
                subtitle:
                    entry.isDirectory ? null : CodeText.bytes(entry.bytes),
                onTap: () => _open(entry),
              ),
            ),
        ],
      ],
    );
  }
}

/// One file, read-only, in a monospace face.
class _FileViewPage extends StatefulWidget {
  const _FileViewPage({required this.workspace, required this.path});

  final CodeWorkspace workspace;
  final String path;

  @override
  State<_FileViewPage> createState() => _FileViewPageState();
}

class _FileViewPageState extends State<_FileViewPage> {
  String? _text;

  /// Lines per block: the page builds a long file a block at a time instead
  /// of laying out one huge text.
  static const int _block = 60;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    String text;
    try {
      text = await widget.workspace.readFile(widget.path);
    } catch (_) {
      text = '';
    }
    if (mounted) setState(() => _text = text);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text ?? ''));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).codeFileCopied),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  Future<void> _delete() async {
    final l10n = L10n.of(context);
    final name = widget.path.split('/').last;
    final confirmed = await showFinnConfirm(
      context,
      title: l10n.codeFileDeleteTitle(name),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (confirmed != true) return;
    await widget.workspace.delete(widget.path);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final text = _text;
    final lines = text?.split('\n') ?? const <String>[];
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.4,
      color: FluxColors.inkOf(context),
    );
    return FinnPage(
      title: widget.path.split('/').last,
      spacing: 0,
      actions: [
        FinnCircleButton.icon(
          icon: FluxIcons.copy,
          label: l10n.codeFileCopy,
          onTap: text == null || text.isEmpty ? null : _copy,
        ),
        FinnCircleButton.icon(
          icon: CodeIcons.trash,
          label: l10n.codeFileDelete,
          onTap: _delete,
        ),
      ],
      children: [
        if (text != null && text.isEmpty)
          FinnCaption(l10n.codeFileEmpty)
        else
          for (var start = 0; start < lines.length; start += _block)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SelectableText(
                lines.skip(start).take(_block).join('\n'),
                style: style,
              ),
            ),
      ],
    );
  }
}

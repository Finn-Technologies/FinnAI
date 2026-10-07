import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_diff_view.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/line_diff.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// One file a session changed: how it was before the session first touched
/// it, how it is now, and the diff between the two.
@immutable
class CodeFileChange {
  const CodeFileChange({
    required this.path,
    required this.created,
    required this.lines,
    required this.added,
    required this.removed,
  });

  final String path;

  /// The file did not exist before the session wrote it.
  final bool created;
  final List<DiffLine> lines;
  final int added;
  final int removed;
}

/// Everything a session changed, one entry per file, as Cursor, Codex and
/// Claude Code review it on a phone: a file list, each file's net diff from
/// the start of the session. Worked out once per version of a session.
@immutable
class CodeChanges {
  const CodeChanges(this.files);

  final List<CodeFileChange> files;

  bool get isEmpty => files.isEmpty;
  int get added => files.fold(0, (sum, f) => sum + f.added);
  int get removed => files.fold(0, (sum, f) => sum + f.removed);

  static final Map<String, (DateTime, CodeChanges)> _cache = {};

  static CodeChanges of(CodeSession session) {
    final hit = _cache[session.id];
    if (hit != null && hit.$1 == session.updatedAt) return hit.$2;
    final changes = _compute(session);
    if (_cache.length > 100) _cache.clear();
    _cache[session.id] = (session.updatedAt, changes);
    return changes;
  }

  static CodeChanges _compute(CodeSession session) {
    // The first "before" and the last "after" of each path, in order.
    final before = <String, String?>{};
    final after = <String, String>{};
    for (final message in session.messages) {
      final action = message.action;
      if (action == null ||
          action.isShell ||
          action.status != CodeActionStatus.done) {
        continue;
      }
      before.putIfAbsent(action.path, () => action.previous);
      after[action.path] = action.newText;
    }
    final files = <CodeFileChange>[];
    for (final path in after.keys) {
      final lines = LineDiff.diff(before[path], after[path]!);
      final (added, removed) = LineDiff.stats(lines);
      if (added + removed == 0) continue;
      files.add(CodeFileChange(
        path: path,
        created: before[path] == null,
        lines: lines,
        added: added,
        removed: removed,
      ));
    }
    return CodeChanges(files);
  }
}

/// "+12 −3 · 2 files": what the session has changed so far, above the
/// composer. Tapping it opens the review ([showCodeChanges]). It arrives
/// with a small pop the first time there is something to show.
class CodeChangesChip extends StatefulWidget {
  const CodeChangesChip({super.key, required this.changes});

  final CodeChanges changes;

  @override
  State<CodeChangesChip> createState() => _CodeChangesChipState();
}

class _CodeChangesChipState extends State<CodeChangesChip> {
  final GlobalKey _surface = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final changes = widget.changes;
    final count = changes.files.length;
    final files =
        count == 1 ? l10n.codeSessionOneFile : l10n.codeSessionFileCount(count);
    final meta = CodeStyle.meta(context);
    void open() {
      HapticFeedback.selectionClick();
      showCodeChanges(context, changes, origin: globalRectOf(_surface));
    }

    return Semantics(
      button: true,
      label: l10n.codeChangesSemantic(
        files,
        '${changes.added}',
        '${changes.removed}',
      ),
      onTap: open,
      excludeSemantics: true,
      child: FluxPressScale(
        child: Material(
          key: _surface,
          color: FluxColors.controlOf(context),
          shape: StadiumBorder(
            side: BorderSide(color: FluxColors.lineOf(context)),
          ),
          child: InkWell(
            key: const ValueKey('code-changes-chip'),
            customBorder: const StadiumBorder(),
            onTap: open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FluxIcon(
                      icon: CodeIcons.fileEdit,
                      size: 16,
                      color: FluxColors.inkOf(context),
                    ),
                    const SizedBox(width: 8),
                    Text(files, style: CodeStyle.label(context)),
                    const SizedBox(width: 10),
                    Text(
                      '+${changes.added}',
                      style:
                          meta.copyWith(color: CodeStyle.addedSignOf(context)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '−${changes.removed}',
                      style: meta.copyWith(
                          color: CodeStyle.removedSignOf(context)),
                    ),
                    const SizedBox(width: 6),
                    FluxIcon(
                      icon: FluxIcons.chevronUp,
                      size: 14,
                      color: FluxColors.mutedOf(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The review: every changed file, each opening onto its diff. Grows out of
/// the chip that opened it.
Future<void> showCodeChanges(
  BuildContext context,
  CodeChanges changes, {
  Rect? origin,
}) {
  final l10n = L10n.of(context);
  return showFinnSheet<void>(
    context,
    title: l10n.codeChangesTitle,
    subtitle: l10n.codeChangesSubtitle,
    origin: origin,
    originColor: FluxColors.controlOf(context),
    children: (context) => [
      for (final (i, file) in changes.files.indexed)
        _FileChange(
          key: ValueKey('code-change-${file.path}'),
          file: file,
          // A short review opens everything; a long one opens the first.
          initiallyOpen: changes.files.length <= 2 || i == 0,
        ),
    ],
  );
}

class _FileChange extends StatefulWidget {
  const _FileChange({
    super.key,
    required this.file,
    required this.initiallyOpen,
  });

  final CodeFileChange file;
  final bool initiallyOpen;

  @override
  State<_FileChange> createState() => _FileChangeState();
}

class _FileChangeState extends State<_FileChange> {
  late bool _open = widget.initiallyOpen;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final file = widget.file;
    final meta = CodeStyle.meta(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: file.path,
            onTap: _toggle,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    FluxIcon(
                      icon: file.created ? CodeIcons.fileNew : CodeIcons.file,
                      size: 16,
                      color: FluxColors.mutedOf(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            file.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CodeStyle.code(context).copyWith(
                              fontSize: 13,
                            ),
                          ),
                          if (file.created)
                            Text(l10n.codeChangesNewFile, style: meta),
                        ],
                      ),
                    ),
                    Text(
                      '+${file.added}',
                      style:
                          meta.copyWith(color: CodeStyle.addedSignOf(context)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '−${file.removed}',
                      style: meta.copyWith(
                          color: CodeStyle.removedSignOf(context)),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _open ? .5 : 0,
                      duration: reduced ? Duration.zero : CodeStyle.base,
                      curve: CodeStyle.curve,
                      child: FluxIcon(
                        icon: FluxIcons.chevronDown,
                        size: 16,
                        color: FluxColors.mutedOf(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduced ? Duration.zero : CodeStyle.base,
            curve: CodeStyle.curve,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: CodeDiffView(lines: file.lines, maxLines: 40),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

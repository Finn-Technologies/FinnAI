import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_suggestions.dart';
import 'package:finn_ai/src/shared/layout/finn_layout.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/enter_to_send.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// FinnAI Code's input: a slim field between an add button and send, with
/// `/commands` and `@file` mentions offered above it as you type, and the
/// [status] line under it.
class CodeComposer extends StatefulWidget {
  const CodeComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
    required this.onStop,
    required this.status,
    this.commands = const [],
    this.files,
    this.width,
    this.attachments = const [],
    this.onAttach,
    this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// A request is running: the send button becomes stop.
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  /// The status line drawn under the field.
  final Widget status;

  final List<CodeSlashCommand> commands;

  /// The project's files, for `@` mentions; null turns mentions off.
  final Future<List<String>> Function()? files;
  final double? width;

  /// Names of the files waiting to go with the next message.
  final List<String> attachments;

  /// Opens the file picker; null hides the add button.
  final VoidCallback? onAttach;
  final ValueChanged<int>? onRemoveAttachment;

  @override
  State<CodeComposer> createState() => _CodeComposerState();
}

class _CodeComposerState extends State<CodeComposer> {
  late bool _hasText = widget.controller.text.trim().isNotEmpty;
  CodeCompletionQuery? _query;
  List<String>? _files;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant CodeComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // The phone keyboard's return key types a newline instead of sending: on
    // a `/command` it means "run it".
    final typed = widget.controller.text;
    if (RegExp(r'^/[\w-]+\n$').hasMatch(typed)) {
      final name = typed.substring(1, typed.length - 1).toLowerCase();
      final match =
          widget.commands.where((c) => c.name.startsWith(name)).firstOrNull;
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.controller.clear();
          match.run();
        });
        return;
      }
    }
    final hasText = widget.controller.text.trim().isNotEmpty;
    var query = CodeCompletionQuery.of(widget.controller.value);
    if (query?.kind == CodeCompletionKind.file && widget.files == null) {
      query = null;
    }
    if (query?.kind == CodeCompletionKind.file && _query == null) {
      // Read once per mention: the folder does not change while typing.
      _files = null;
      unawaited(widget.files!().then((files) {
        if (mounted) setState(() => _files = files);
      }));
    }
    if (hasText != _hasText || query != _query) {
      setState(() {
        _hasText = hasText;
        _query = query;
      });
    }
  }

  List<CodeSlashCommand> get _matchingCommands {
    final query = _query?.query.toLowerCase() ?? '';
    return [
      for (final command in widget.commands)
        if (command.name.startsWith(query)) command,
    ];
  }

  List<String> get _matchingFiles {
    final query = _query?.query.toLowerCase() ?? '';
    final files = _files ?? const <String>[];
    final starts = files.where((f) => f.toLowerCase().startsWith(query));
    final contains = files.where((f) =>
        !f.toLowerCase().startsWith(query) && f.toLowerCase().contains(query));
    return [...starts, ...contains];
  }

  void _pick(int index) {
    final query = _query;
    if (query == null) return;
    HapticFeedback.selectionClick();
    if (query.kind == CodeCompletionKind.command) {
      final command = _matchingCommands[index];
      widget.controller.clear();
      command.run();
      return;
    }
    final file = _matchingFiles[index];
    final value = widget.controller.value;
    final end = value.selection.baseOffset;
    final text = value.text.replaceRange(query.start, end, '@$file ');
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: query.start + file.length + 2),
    );
  }

  void _send() {
    final query = _query;
    // Enter on a `/com` runs the first matching command.
    if (query?.kind == CodeCompletionKind.command &&
        _matchingCommands.isNotEmpty) {
      _pick(0);
      return;
    }
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final canSend = (_hasText || widget.attachments.isNotEmpty) && !widget.busy;
    final query = _query;

    Widget? suggestions;
    if (query != null) {
      suggestions = query.kind == CodeCompletionKind.command
          ? CodeSuggestionList(
              items: [
                for (final command in _matchingCommands)
                  CodeSuggestion(
                    label: '/${command.name}',
                    detail: command.description,
                    icon: command.icon,
                  ),
              ],
              onPick: _pick,
            )
          : CodeSuggestionList(
              items: [
                for (final file in _matchingFiles)
                  CodeSuggestion(label: file, icon: CodeIcons.file),
              ],
              onPick: _pick,
              empty: _files == null ? null : l10n.codeMentionNoFiles,
            );
    }

    final trailing = widget.busy
        ? _RoundButton(
            key: const ValueKey('code-stop-button'),
            label: l10n.chatStopGeneratingSemantic,
            dark: true,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onStop();
            },
            child: SizedBox.square(
              dimension: 11,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FluxColors.canvasOf(context),
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
          )
        : _RoundButton(
            key: const ValueKey('code-send-button'),
            label: l10n.chatSendMessageSemantic,
            dark: true,
            onTap: canSend ? _send : null,
            child: FluxIcon(
              icon: FluxIcons.arrowUp02,
              size: 17,
              color: FluxColors.canvasOf(context),
            ),
          );

    final field = Container(
      constraints: const BoxConstraints(
        minHeight: CodeStyle.inputHeight,
        maxHeight: 180,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: FluxSurfaces.flat(context, radius: CodeStyle.inputHeight / 2),
      child: Semantics(
        label: l10n.codeComposerHint,
        textField: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.focusNode.requestFocus,
          child: Center(
            heightFactor: 1,
            child: Padding(
              // Same optical centring as the chat field (see
              // FinnLayout.fieldTextLift), at Code's size.
              padding: EdgeInsets.only(
                top: 6,
                bottom: 6 + FinnLayout.fieldTextLift * .8,
              ),
              child: EnterToSend(
                canSend: canSend,
                onSend: _send,
                child: TextField(
                  key: const ValueKey('code-composer-field'),
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  inputFormatters: [LengthLimitingTextInputFormatter(6000)],
                  minLines: 1,
                  maxLines: 6,
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: CodeStyle.prose(context).copyWith(height: 1.3),
                  cursorColor: FluxColors.inkOf(context),
                  cursorWidth: 1.6,
                  decoration: InputDecoration.collapsed(
                    hintText: l10n.codeComposerHint,
                    hintMaxLines: 1,
                    hintStyle: CodeStyle.prose(context).copyWith(
                      height: 1.3,
                      color: FluxColors.inkOf(context).withValues(alpha: .5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: CodeStyle.motion(context, CodeStyle.fast),
            curve: CodeStyle.curve,
            alignment: Alignment.bottomCenter,
            child: suggestions == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: suggestions,
                  ),
          ),
          if (widget.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (i, name) in widget.attachments.indexed)
                    FluxChip(
                      key: ValueKey('code-attachment-$i'),
                      icon: CodeIcons.file,
                      label: name,
                      dense: true,
                      semanticLabel: l10n.codeAttachmentRemove(name),
                      trailing: FluxIcons.close,
                      onTap: () => widget.onRemoveAttachment?.call(i),
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.onAttach != null) ...[
                _RoundButton(
                  key: const ValueKey('code-attach-button'),
                  label: l10n.codeAttachFiles,
                  onTap: widget.busy ? null : widget.onAttach,
                  child: FluxIcon(
                    icon: FluxIcons.add,
                    size: 17,
                    color: FluxColors.inkOf(context),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: field),
              const SizedBox(width: 8),
              FluxSwap(swapKey: widget.busy, child: trailing),
            ],
          ),
          const SizedBox(height: 2),
          widget.status,
        ],
      ),
    );
  }
}

/// A 44dp round control beside the field: add, send, stop.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fill =
        dark ? FluxColors.actionOf(context) : FluxColors.controlOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: FluxPressScale(
        child: AnimatedOpacity(
          duration: CodeStyle.motion(context, CodeStyle.fast),
          opacity: enabled || !dark ? 1 : .35,
          child: Material(
            color: fill,
            shape: CircleBorder(
              side: dark
                  ? BorderSide.none
                  : BorderSide(color: FluxColors.lineOf(context), width: .5),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: CodeStyle.inputHeight,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

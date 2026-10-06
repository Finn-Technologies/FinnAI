import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/layout/finn_layout.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';
import 'package:finn_ai/src/shared/widgets/enter_to_send.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// The message field of FinnAI Code: the same pill and send control as the
/// chat composer, with the model and the permission mode as chips above it,
/// so what will answer and what it may do are always in view.
class CodeComposer extends StatefulWidget {
  const CodeComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
    required this.onStop,
    required this.modelLabel,
    required this.modelIsLocal,
    required this.permission,
    required this.onModel,
    required this.onPermission,
    this.width,
    this.compact = false,
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

  final String modelLabel;
  final bool modelIsLocal;
  final CodePermissionMode permission;
  final VoidCallback onModel;
  final ValueChanged<CodePermissionMode> onPermission;
  final double? width;

  /// Shrinks the whole control to 85% while the transcript is scrolled away
  /// from the newest message, as the chat composer does.
  final bool compact;

  /// Names of the files waiting to go with the next message.
  final List<String> attachments;

  /// Opens the file picker; null hides the add button (no session can take
  /// files, or the platform has no picker).
  final VoidCallback? onAttach;
  final ValueChanged<int>? onRemoveAttachment;

  @override
  State<CodeComposer> createState() => _CodeComposerState();
}

class _CodeComposerState extends State<CodeComposer> {
  late bool _hasText = widget.controller.text.trim().isNotEmpty;

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
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final canSend = (_hasText || widget.attachments.isNotEmpty) && !widget.busy;

    final trailing = widget.busy
        ? FinnCircleButton(
            key: const ValueKey('code-stop-button'),
            label: l10n.chatStopGeneratingSemantic,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onStop();
            },
            dark: true,
            glyph: SizedBox.square(
              dimension: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FluxColors.actionInkOf(context),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
          )
        : FinnCircleButton.icon(
            key: const ValueKey('code-send-button'),
            icon: FluxIcons.arrowUp02,
            label: l10n.chatSendMessageSemantic,
            onTap: canSend ? widget.onSend : null,
            dark: true,
            dimmed: !canSend,
          );

    final pill = Container(
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 220),
      padding: const EdgeInsets.fromLTRB(17, 1, 4, 1),
      // Flat, like the chat composer. This used to carry a hand-rolled shadow,
      // which in dark mode is `elevationOf` — near-white — so the pill wore a
      // pale halo instead of an edge.
      decoration: FluxSurfaces.flat(context, radius: FluxRadius.pill),
      child: Semantics(
        label: l10n.codeComposerHint,
        textField: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.focusNode.requestFocus,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            // heightFactor 1: the field sets the height. A plain Center fills
            // the pill's whole maximum height and the composer balloons.
            child: Center(
              heightFactor: 1,
              child: Padding(
// InstrumentSans carries more space above its letters than below, so the
// laid-out line box sat ~4.5px under where the letters look centred. Measured
// on the real window (pixel rows of the letters against the pill); the
// bottom padding lifts the centred field by half its value; per platform, see
// FinnLayout.fieldTextLift.
                padding: EdgeInsets.only(
                  // Room above and below so a second line does not
                  // touch the pill; one line still centres in it.
                  top: 8,
                  bottom: 8 + FinnLayout.fieldTextLift,
                ),
                child: EnterToSend(
                  canSend: canSend,
                  onSend: widget.onSend,
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
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                      color: FluxColors.inkOf(context),
                    ),
                    cursorColor: FluxColors.inkOf(context),
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.codeComposerHint,
                      hintMaxLines: 1,
                      hintStyle: TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                        color: FluxColors.inkOf(context).withValues(alpha: .55),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.compact ? 1.0 : 0.0),
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, shrink, child) => Transform.scale(
        alignment: Alignment.bottomCenter,
        scale: 1 - 0.15 * shrink,
        child: child,
      ),
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Chips(
                modelLabel: widget.modelLabel,
                modelIsLocal: widget.modelIsLocal,
                permission: widget.permission,
                onModel: widget.onModel,
                onPermission: widget.onPermission,
              ),
            ),
            if (widget.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.onAttach != null) ...[
                  FinnCircleButton.icon(
                    key: const ValueKey('code-attach-button'),
                    icon: FluxIcons.add,
                    label: l10n.codeAttachFiles,
                    onTap: widget.busy ? null : widget.onAttach,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: pill),
                const SizedBox(width: 12),
                FluxSwap(swapKey: widget.busy, child: trailing),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.modelLabel,
    required this.modelIsLocal,
    required this.permission,
    required this.onModel,
    required this.onPermission,
  });

  final String modelLabel;
  final bool modelIsLocal;
  final CodePermissionMode permission;
  final VoidCallback onModel;
  final ValueChanged<CodePermissionMode> onPermission;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final permissionLabel = CodeText.permission(l10n, permission);
    return Row(
      children: [
        Flexible(
          child: FluxChip(
            key: const ValueKey('code-model-chip'),
            icon: modelIsLocal ? FluxIcons.chip : CodeIcons.cloud,
            label: modelLabel,
            semanticLabel: l10n.codeModelChipSemantic(modelLabel),
            onTap: onModel,
            trailing: CodeIcons.chevronDown,
          ),
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (anchorContext) => FluxChip(
            key: const ValueKey('code-permission-chip'),
            icon: permission == CodePermissionMode.autoRun
                ? CodeIcons.play
                : CodeIcons.shield,
            label: permissionLabel,
            semanticLabel: l10n.codePermissionSemantic(permissionLabel),
            onTap: () => showFinnMenu(
              context,
              anchor: finnAnchorOf(anchorContext),
              items: [
                for (final mode in CodePermissionMode.values)
                  FinnMenuItem(
                    label: CodeText.permission(l10n, mode),
                    icon: switch (mode) {
                      CodePermissionMode.askEveryTime => CodeIcons.shield,
                      CodePermissionMode.acceptEdits => CodeIcons.file,
                      CodePermissionMode.autoRun => CodeIcons.play,
                    },
                    selected: mode == permission,
                    onTap: () => onPermission(mode),
                  ),
              ],
            ),
            trailing: CodeIcons.chevronDown,
          ),
        ),
      ],
    );
  }
}

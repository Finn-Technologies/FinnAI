import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/code_agent.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_action_card.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';
import 'package:finn_ai/src/shared/widgets/finn_edge_fade.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';

/// The transcript of a coding session: what was asked, what the model said,
/// each thing it did, and why it stopped when it did.
class CodeConversation extends StatelessWidget {
  const CodeConversation({
    super.key,
    required this.session,
    required this.agent,
    required this.topInset,
    required this.bottomInset,
    required this.scrollController,
  });

  final CodeSession? session;
  final CodeAgent agent;
  final double topInset;
  final double bottomInset;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final messages = session?.messages ?? const <CodeMessage>[];
    final working = agent.busy && agent.runningSessionId == session?.id;
    if (messages.isEmpty && !working) return const _EmptySlate();

    // An assistant message with nothing to show yet is the "thinking" row.
    final visible = [
      for (final message in messages)
        if (message.isUser ||
            message.text.trim().isNotEmpty ||
            message.action != null ||
            message.failed)
          message,
    ];
    final last = messages.lastOrNull;
    final lastId = last?.id;
    final thinking = working &&
        agent.phase == CodeAgentPhase.thinking &&
        last != null &&
        !last.isUser &&
        last.text.trim().isEmpty &&
        last.action == null;
    final resumable = !agent.busy && last != null && last.failed;

    return Stack(
      children: [
        ListView.builder(
          key: const ValueKey('code-scroll-view'),
          controller: scrollController,
          reverse: true,
          padding: EdgeInsets.fromLTRB(0, topInset, 0, bottomInset + 20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const FluxBouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: visible.length + 1,
          itemBuilder: (context, index) {
            // Index 0 is the bottom of the list: the live row.
            if (index == 0) {
              return thinking
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: CodeThinking(),
                    )
                  : const SizedBox.shrink();
            }
            final message = visible[visible.length - index];
            return Padding(
              key: ValueKey('code-message-${message.id}'),
              padding: const EdgeInsets.only(bottom: 14),
              child: FluxEntrance(
                alignment: message.isUser
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: message.isUser
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: _UserBubble(text: message.text),
                      )
                    : _AssistantMessage(
                        message: message,
                        awaiting: agent.pendingMessageId == message.id,
                        isLast: message.id == lastId,
                        resumable: resumable && message.id == lastId,
                        onApprove: () => agent.approve(message.id),
                        onSkip: () => agent.skip(message.id),
                        onResume: agent.resume,
                      ),
              ),
            );
          },
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: finnTopFadeHeight,
          child: IgnorePointer(
            child: FinnEdgeFade(key: ValueKey('code-fade-top'), top: true),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: bottomInset,
          child: const IgnorePointer(
            child: FinnEdgeFade(key: ValueKey('code-fade-bottom'), top: false),
          ),
        ),
      ],
    );
  }
}

class _EmptySlate extends StatelessWidget {
  const _EmptySlate();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: FinnReveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.codeGreeting,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.codeGreetingCaption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * .82, 620),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        // The same fill + hairline a chat bubble uses. Without the hairline the
        // user's own message had no edge in dark mode.
        decoration: FluxSurfaces.flat(
          context,
          radius: FluxRadius.pill,
          color: FluxColors.bubbleUserOf(context),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: 'InstrumentSans',
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w400,
            color: FluxColors.inkOf(context),
          ),
        ),
      );
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.message,
    required this.awaiting,
    required this.isLast,
    required this.resumable,
    required this.onApprove,
    required this.onSkip,
    required this.onResume,
  });

  final CodeMessage message;
  final bool awaiting;
  final bool isLast;
  final bool resumable;
  final VoidCallback onApprove;
  final VoidCallback onSkip;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final action = message.action;
    final byline = message.modelLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message.text.trim().isNotEmpty)
          SelectionArea(child: SafeMarkdownText(text: message.text)),
        if (action != null) ...[
          if (message.text.trim().isNotEmpty) const SizedBox(height: 10),
          CodeActionCard(
            action: action,
            awaitingApproval: awaiting,
            onApprove: onApprove,
            onSkip: onSkip,
          ),
        ],
        if (message.failed && (isLast || !_recovered(message))) ...[
          if (message.text.trim().isNotEmpty || action != null)
            const SizedBox(height: 10),
          _ErrorNotice(
            text: CodeText.error(l10n, message.errorCode!, message.errorDetail),
            detail: message.errorCode!.startsWith(CodeErrorCode.providerPrefix)
                ? message.errorDetail
                : '',
            actionLabel: resumable
                ? (message.errorCode == CodeErrorCode.stepLimit
                    ? l10n.commonContinue
                    : l10n.commonRetry)
                : null,
            onAction: resumable ? onResume : null,
          ),
        ],
        // Say which model wrote it when it was not the one on the phone: the
        // reply came from a provider's servers.
        if (byline != null &&
            byline != 'FinnAI' &&
            message.text.trim().isNotEmpty &&
            action == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              byline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FluxColors.mutedOf(context),
                    fontSize: 12,
                  ),
            ),
          ),
      ],
    );
  }
}

/// A reply that was cut off or unusable and then retried: once the model has
/// gone on to do something, the notice is history, not news.
bool _recovered(CodeMessage message) =>
    message.errorCode == CodeErrorCode.cutOff ||
    message.errorCode == CodeErrorCode.malformed;

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({
    required this.text,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('code-error-notice'),
      padding: const EdgeInsets.all(14),
      // Flat with a hairline, like the card above it.
      decoration: FluxSurfaces.flatCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: FluxIcon(
                  icon: FluxIcons.error,
                  size: 20,
                  color: FluxColors.destructiveOf(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: theme.bodyMedium)),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                detail,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(
                  color: FluxColors.mutedOf(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 150,
                child: FinnButton(
                  label: actionLabel!,
                  onTap: onAction,
                  compact: true,
                  secondary: true,
                  icon: CodeIcons.play,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three dots that breathe while the model writes.
class CodeThinking extends StatefulWidget {
  const CodeThinking({super.key});

  @override
  State<CodeThinking> createState() => _CodeThinkingState();
}

class _CodeThinkingState extends State<CodeThinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = FluxColors.inkOf(context);
    return Semantics(
      label: L10n.of(context).codeThinking,
      liveRegion: true,
      child: Row(
        key: const ValueKey('code-thinking'),
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Each dot peaks a third of a cycle after the last.
                  final phase = (_controller.value - i / 3) % 1.0;
                  final pulse = .5 - .5 * math.cos(phase * 2 * math.pi);
                  return Opacity(
                    opacity: .25 + .6 * pulse,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

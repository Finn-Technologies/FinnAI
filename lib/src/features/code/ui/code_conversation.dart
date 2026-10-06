import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/code_agent.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_blocks.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/features/code/ui/code_tool_row.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_edge_fade.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';

/// The transcript of a coding session, read as a log: each request, what the
/// model said, one line per thing it did, and why it stopped.
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
          padding: EdgeInsets.fromLTRB(0, topInset, 0, bottomInset + 12),
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
                      padding: EdgeInsets.only(top: 4),
                      child: CodeThinking(),
                    )
                  : const SizedBox.shrink();
            }
            final position = visible.length - index;
            final message = visible[position];
            final previous = position > 0 ? visible[position - 1] : null;
            return Padding(
              key: ValueKey('code-message-${message.id}'),
              padding: EdgeInsets.only(top: _gapBefore(message, previous)),
              child: _Appear(
                child: message.isUser
                    ? _UserPrompt(text: message.text)
                    : _AssistantMessage(
                        message: message,
                        awaiting: agent.pendingMessageId == message.id,
                        isLast: message.id == last?.id,
                        resumable: resumable && message.id == last.id,
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

  /// Tool rows of one request sit tight together, like lines of a log; a new
  /// request gets air above it.
  static double _gapBefore(CodeMessage message, CodeMessage? previous) {
    if (previous == null) return 0;
    if (message.isUser) return 18;
    if (previous.isUser) return 10;
    final toolAfterTool = message.text.trim().isEmpty &&
        message.action != null &&
        previous.action != null;
    return toolAfterTool ? 0 : 6;
  }
}

/// A short fade and lift as an item joins the log; quick enough that a fast
/// run of tool rows never queues behind its own animation.
class _Appear extends StatefulWidget {
  const _Appear({required this.child});

  final Widget child;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CodeStyle.base,
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: CodeStyle.curve);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 6 * (1 - _curve.value)),
            child: child,
          ),
          child: widget.child,
        ),
      );
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
              FluxIcon(
                icon: CodeIcons.prompt,
                size: 28,
                color: FluxColors.mutedOf(context),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.codeGreeting,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: CodeStyle.sans,
                  fontSize: 20,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.codeGreetingCaption,
                textAlign: TextAlign.center,
                style: CodeStyle.label(
                  context,
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

/// What the user asked: full width, a quiet fill, a prompt mark.
class _UserPrompt extends StatelessWidget {
  const _UserPrompt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('code-user-prompt'),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(CodeStyle.radius),
          border: Border.all(color: FluxColors.lineOf(context), width: .5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '›',
                style: CodeStyle.code(
                  context,
                  color: FluxColors.mutedOf(context),
                ).copyWith(fontSize: 14, height: 1.25),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(text, style: CodeStyle.prose(context)),
            ),
          ],
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
    final hasText = message.text.trim().isNotEmpty;
    final media = MediaQuery.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasText)
          // The chat renderer at Code's density: 14sp prose, the user's own
          // text-size setting still applied on top.
          MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                media.textScaler.scale(CodeStyle.proseSize) / 16,
              ),
            ),
            child: SelectionArea(
              child: SafeMarkdownText(
                text: message.text,
                codeFontFamily: CodeStyle.mono,
              ),
            ),
          ),
        if (action != null) ...[
          if (hasText) const SizedBox(height: 4),
          CodeToolRow(
            key: ValueKey('code-tool-${message.id}'),
            action: action,
            awaitingApproval: awaiting,
            onApprove: onApprove,
            onSkip: onSkip,
          ),
        ],
        if (message.failed && (isLast || !_recovered(message))) ...[
          if (hasText || action != null) const SizedBox(height: 4),
          _ErrorRow(
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
        // Which model wrote it, when it was not the one on the phone: the
        // reply came from a provider's servers.
        if (byline != null && byline != 'FinnAI' && hasText && action == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(byline, style: CodeStyle.meta(context)),
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

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
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
    final red = FluxColors.destructiveOf(context);
    return Row(
      key: const ValueKey('code-error-notice'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FluxIcon(icon: FluxIcons.error, size: 14, color: red),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: CodeStyle.label(context)),
              if (detail.isNotEmpty)
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CodeStyle.meta(context),
                ),
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 8),
          CodeSmallButton(
            label: actionLabel!,
            onTap: onAction,
            icon: CodeIcons.retry,
          ),
        ],
      ],
    );
  }
}

/// "● Thinking… 4s": a breathing dot and how long the model has been at it,
/// so a slow on-device step reads as work, not a hang.
class CodeThinking extends StatefulWidget {
  const CodeThinking({super.key});

  @override
  State<CodeThinking> createState() => _CodeThinkingState();
}

class _CodeThinkingState extends State<CodeThinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final seconds = _clock.elapsed.inSeconds;
    return Semantics(
      label: l10n.codeThinking,
      liveRegion: true,
      child: SizedBox(
        key: const ValueKey('code-thinking'),
        height: CodeStyle.rowHeight,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FadeTransition(
                  opacity: Tween<double>(begin: .3, end: 1).animate(_pulse),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: FluxColors.inkOf(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              l10n.codeThinking,
              style:
                  CodeStyle.label(context, color: FluxColors.mutedOf(context)),
            ),
            if (seconds > 0) ...[
              const SizedBox(width: 6),
              Text('${math.max(1, seconds)}s', style: CodeStyle.meta(context)),
            ],
          ],
        ),
      ),
    );
  }
}

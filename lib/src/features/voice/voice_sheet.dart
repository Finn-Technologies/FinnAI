import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';

bool get voiceSupportedOnPlatform {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

Future<void> openVoiceSheet({
  required BuildContext context,
  required VoiceChatController voice,
  required Future<void> Function(String transcript) onSendTranscript,
  required VoidCallback onStopGeneration,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: L10n.of(context).voiceCloseSemantic,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, __) => VoiceSheet(
      voice: voice,
      onSendTranscript: onSendTranscript,
      onStopGeneration: onStopGeneration,
    ),
  );
}

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({
    super.key,
    required this.voice,
    required this.onSendTranscript,
    required this.onStopGeneration,
  });

  final VoiceChatController voice;
  final Future<void> Function(String transcript) onSendTranscript;
  final VoidCallback onStopGeneration;

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.voice.onTranscript = _handleTranscript;
    unawaited(widget.voice.startListening());
  }

  bool _isClosing = false;

  @override
  void dispose() {
    if (widget.voice.onTranscript == _handleTranscript) {
      widget.voice.onTranscript = null;
    }
    unawaited(widget.voice.reset());
    super.dispose();
  }

  Future<void> _handleTranscript(String text) async {
    if (_sending || !mounted) return;
    _sending = true;
    try {
      await widget.onSendTranscript(text);
    } finally {
      _sending = false;
    }
  }

  Future<void> _onMicTap() async {
    final voice = widget.voice;
    switch (voice.state) {
      case VoiceChatState.listening:
        await voice.stopListening();
      case VoiceChatState.speaking:
      case VoiceChatState.thinking:
        await voice.interrupt();
        widget.onStopGeneration();
        await voice.startListening();
      case VoiceChatState.idle:
        await voice.startListening();
    }
  }

  void _onClose() {
    if (_isClosing) return;
    _isClosing = true;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        intensity: 1,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: widget.voice,
            builder: (context, _) {
              final voice = widget.voice;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxHeight < 480;
                  final orbScale = isCompact ? 0.72 : 1.0;
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.all(isCompact ? 4 : 12),
                          child: Semantics(
                            button: true,
                            label: L10n.of(context).voiceCloseSemantic,
                            child: SizedBox.square(
                              key: const ValueKey('voice-close-button'),
                              dimension: 48,
                              child: InkWell(
                                onTap: _onClose,
                                customBorder: const CircleBorder(),
                                child: Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedCancel01,
                                    size: 24,
                                    color: FluxColors.mutedOf(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // The orb and the copy scroll rather than clip: a
                      // landscape or split-screen window can be shorter than
                      // the content even in its compact size.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, inner) => SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(minHeight: inner.maxHeight),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _VoiceOrb(
                                    state: voice.state,
                                    soundLevel: voice.soundLevel,
                                    onTap: _onMicTap,
                                    scale: orbScale,
                                  ),
                                  SizedBox(height: isCompact ? 14 : 28),
                                  // The error line already says what went
                                  // wrong, so the status line stays out of the
                                  // way instead of repeating the hint below.
                                  if (voice.error == VoiceChatError.none)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                      ),
                                      child: Text(
                                        _statusText(context, voice),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: FluxColors.inkOf(context),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  if (voice.transcript.trim().isNotEmpty) ...[
                                    SizedBox(height: isCompact ? 6 : 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                      ),
                                      child: Text(
                                        '“${voice.transcript.trim()}”',
                                        textAlign: TextAlign.center,
                                        maxLines: isCompact ? 2 : 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color:
                                                  FluxColors.mutedOf(context),
                                            ),
                                      ),
                                    ),
                                  ],
                                  if (voice.error ==
                                      VoiceChatError.modelMissing) ...[
                                    SizedBox(height: isCompact ? 6 : 12),
                                    _ModelCard(voice: voice),
                                  ] else if (voice.error !=
                                      VoiceChatError.none) ...[
                                    SizedBox(height: isCompact ? 6 : 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                      ),
                                      child: Text(
                                        voice.error == VoiceChatError.micDenied
                                            ? L10n.of(context).voiceMicDenied
                                            : L10n.of(context).voiceUnavailable,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: FluxColors.destructiveOf(
                                                context,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: isCompact ? 8 : 24),
                        child: Text(
                          L10n.of(context).voiceTapToSpeak,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: FluxColors.mutedOf(context),
                                  ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _statusText(BuildContext context, VoiceChatController voice) {
    switch (voice.state) {
      case VoiceChatState.listening:
        return voice.transcript.trim().isEmpty
            ? L10n.of(context).voiceListening
            : L10n.of(context).voiceHeardYou;
      case VoiceChatState.thinking:
        return L10n.of(context).voiceThinking;
      case VoiceChatState.speaking:
        return L10n.of(context).voiceSpeaking;
      case VoiceChatState.idle:
        // The recogniser worked and heard nothing. Saying so is the
        // difference between "the mic is fine, try again" and "is this thing
        // broken?" — and it is what `voiceDidNotCatch` was translated for.
        return voice.didNotCatchAnything
            ? L10n.of(context).voiceDidNotCatch
            : L10n.of(context).voiceTapToSpeak;
    }
  }
}

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({
    required this.state,
    required this.soundLevel,
    required this.onTap,
    this.scale = 1.0,
  });

  final VoiceChatState state;
  final double soundLevel;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final baseColor = isDark ? Colors.white : Colors.black;
    final listening = state == VoiceChatState.listening;
    final thinking = state == VoiceChatState.thinking;
    final speaking = state == VoiceChatState.speaking;

    // Organic Apple-inspired fluid elasticity: responds to voice without lag
    final soundExpansion =
        listening ? (soundLevel.clamp(0.0, 1.0) * 0.38) : 0.0;
    final primarySize = 144.0 * scale * (1.0 + soundExpansion);

    return Semantics(
      button: true,
      label: L10n.of(context).voiceMicSemantic,
      child: GestureDetector(
        onTap: onTap,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: 210 * scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer organic fluid diffusion halo (monochrome, zero blur passes)
                if (listening || speaking)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    width: primarySize * (1.28 + soundExpansion * 0.5),
                    height: primarySize * (1.28 + soundExpansion * 0.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withValues(
                        alpha: isDark
                            ? (0.04 + soundExpansion * 0.08)
                            : (0.03 + soundExpansion * 0.06),
                      ),
                    ),
                  ),

                // Mid fluid breathing layer
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: primarySize * (1.12 + soundExpansion * 0.2),
                  height: primarySize * (1.12 + soundExpansion * 0.2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor.withValues(
                      alpha: listening
                          ? (isDark ? 0.12 : 0.08)
                          : (isDark ? 0.06 : 0.04),
                    ),
                  ),
                ),

                // Core fluid orb: pure Apple monochromatic depth
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: primarySize,
                  height: primarySize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: listening
                        ? baseColor.withValues(alpha: isDark ? 0.94 : 0.92)
                        : (isDark
                            ? const Color(0xFF26262B)
                            : const Color(0xFFE5E5EA)),
                    boxShadow: [
                      BoxShadow(
                        // The orb core is near-white in dark, so a black
                        // shadow both vanished and left it ungrounded.
                        color: FluxColors.elevationOf(context).withValues(
                          alpha: isDark
                              ? (listening ? 0.20 : 0.12)
                              : (listening ? 0.20 : 0.06),
                        ),
                        blurRadius: listening ? 32 * scale : 16 * scale,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: thinking
                        ? SizedBox.square(
                            dimension: 34 * scale,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          )
                        : HugeIcon(
                            icon: speaking
                                ? HugeIcons.strokeRoundedMicOff01
                                : HugeIcons.strokeRoundedMic01,
                            size: 40 * scale,
                            color: listening
                                ? (isDark ? Colors.black : Colors.white)
                                : FluxColors.inkOf(context),
                            strokeWidth: 2.2,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Offers the one-time speech-model download, and shows it happening.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.voice});

  final VoiceChatController voice;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ValueListenableBuilder<SpeechModelStatus>(
      valueListenable: voice.speechModel,
      builder: (context, status, _) {
        final downloading = status.phase == SpeechModelPhase.downloading;
        final failed = status.phase == SpeechModelPhase.failed;
        final percent = (status.progress * 100).round();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                failed
                    ? l10n.voiceModelFailed
                    : downloading
                        ? l10n.voiceModelDownloading(percent)
                        : l10n.voiceModelNeeded(sttModelSizeLabel),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: failed
                          ? FluxColors.destructiveOf(context)
                          : FluxColors.mutedOf(context),
                    ),
              ),
              const SizedBox(height: 16),
              if (downloading)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: const ValueKey('voice-model-progress'),
                    value: status.progress,
                    minHeight: 6,
                  ),
                )
              else
                FilledButton(
                  key: const ValueKey('voice-model-download'),
                  onPressed: () => unawaited(voice.downloadSpeechModel()),
                  child: Text(
                    failed ? l10n.voiceModelRetry : l10n.voiceModelDownload,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

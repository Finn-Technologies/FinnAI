import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../l10n/l10n_helper.dart';
import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import 'voice_chat_controller.dart';

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
    final isDark = FluxColors.isDark(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        intensity: 1,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: widget.voice,
            builder: (context, _) {
              final voice = widget.voice;
              return Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Semantics(
                        button: true,
                        label: L10n.of(context).voiceCloseSemantic,
                        child: InkWell(
                          onTap: _onClose,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
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
                  const Spacer(),
                  _VoiceOrb(
                    state: voice.state,
                    soundLevel: voice.soundLevel,
                    onTap: _onMicTap,
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _statusText(context, voice),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: FluxColors.inkOf(context),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  if (voice.transcript.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '“${voice.transcript.trim()}”',
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: FluxColors.mutedOf(context),
                            ),
                      ),
                    ),
                  ],
                  if (voice.error != VoiceChatError.none) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        voice.error == VoiceChatError.micDenied
                            ? L10n.of(context).voiceMicDenied
                            : L10n.of(context).voiceUnavailable,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? FluxColors.destructiveDark
                                  : FluxColors.destructive,
                            ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      L10n.of(context).voiceTapToSpeak,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FluxColors.mutedOf(context),
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _statusText(BuildContext context, VoiceChatController voice) {
    if (voice.error != VoiceChatError.none) {
      return L10n.of(context).voiceTapToSpeak;
    }
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
        return L10n.of(context).voiceTapToSpeak;
    }
  }
}

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({
    required this.state,
    required this.soundLevel,
    required this.onTap,
  });

  final VoiceChatState state;
  final double soundLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final baseColor = isDark ? Colors.white : Colors.black;
    final listening = state == VoiceChatState.listening;
    final halo = listening ? 1.0 + soundLevel * 0.35 : 1.0;
    return Semantics(
      button: true,
      label: L10n.of(context).voiceMicSemantic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 148 * halo,
          height: 148 * halo,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withValues(alpha: listening ? 0.92 : 0.12),
            border: Border.all(
              color: baseColor.withValues(alpha: listening ? 0.0 : 0.25),
              width: 1.5,
            ),
            boxShadow: listening
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.25),
                      blurRadius: 42,
                      spreadRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: state == VoiceChatState.thinking
                ? SizedBox.square(
                    dimension: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  )
                : HugeIcon(
                    icon: state == VoiceChatState.speaking
                        ? HugeIcons.strokeRoundedMicOff01
                        : HugeIcons.strokeRoundedMic01,
                    size: 44,
                    color: listening
                        ? (isDark ? Colors.black : Colors.white)
                        : FluxColors.inkOf(context),
                  ),
          ),
        ),
      ),
    );
  }
}

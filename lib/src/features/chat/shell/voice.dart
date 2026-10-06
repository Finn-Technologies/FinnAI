// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellVoice on _HomeShellState {
  Future<void> _openVoiceMode() async {
    if (!voiceSupportedOnPlatform || _busy) return;
    _voice.setSpokenResponses(VoiceSettingsStore.instance.spokenResponses);
    _voice.onTranscript = _onLiveTranscript;
    // Put the keyboard away first: the field it belongs to is about to
    // dissolve into the screen's light. A firm tick marks the moment it opens.
    _focusNode.unfocus();
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _voiceListening = true);
    // Warm the language model while the user is still talking, so the first
    // question is not also paying to load it.
    unawaited(_inference.prewarm());
    await _voice.startLive();
    if (!mounted) return;
    if (_voice.error != VoiceChatError.none) {
      _voice.onTranscript = null;
      setState(() => _voiceListening = false);
      if (_voice.error == VoiceChatError.modelMissing) {
        // Not a failure: the speech model has not been downloaded (the user
        // skipped it, or was offline when it was offered). The full voice
        // sheet is where it can be fetched.
        await openVoiceSheet(
          context: context,
          voice: _voice,
          onSendTranscript: _sendVoiceTranscript,
          onStopGeneration: _stopReply,
        );
        return;
      }
      _showVoiceFailure();
    }
  }

  /// What was said is sent as soon as the speaker stops: a live conversation
  /// has no "send" to tap.
  void _onLiveTranscript(String text) {
    if (!mounted || !_voiceListening) return;
    unawaited(_sendVoiceTranscript(text));
  }

  /// The conversation ended by itself (silence, an error): close the bar.
  void _onVoiceChanged() {
    if (!mounted || !_voiceListening || _voice.live) return;
    _voice.onTranscript = null;
    setState(() => _voiceListening = false);
  }

  Future<void> _endVoiceListening() async {
    if (!_voiceListening) return;
    setState(() => _voiceListening = false);
    _voice.onTranscript = null;
    await _voice.endLive();
  }

  /// A tap on the pill: finish what was said, or interrupt Finn and talk.
  Future<void> _tapVoice() => _voice.tapMic(onStopGeneration: _stopReply);

  void _showVoiceFailure() {
    final message = _voice.error == VoiceChatError.micDenied
        ? L10n.of(context).voiceMicDenied
        : L10n.of(context).voiceUnavailable;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendVoiceTranscript(String transcript) async {
    final text = transcript.trim();
    if (text.isEmpty || _busy || !mounted) return;
    _voice.beginThinking();
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
    _spokenTurn = true;
    try {
      await _send();
    } finally {
      _spokenTurn = false;
    }
    final job = _generation.job;
    if (job != null && job.busy) {
      _voiceReplyGenerationId = job.generationId;
      _voice.speakReplyChunk(job.responseText);
    } else {
      _voiceReplyGenerationId = null;
      _voice.finishReply('');
    }
  }

  void _pumpVoiceReply() {
    final replyId = _voiceReplyGenerationId;
    if (replyId == null) return;
    final job = _generation.job;
    if (job == null || job.generationId != replyId) {
      _voiceReplyGenerationId = null;
      return;
    }
    if (job.busy) {
      if (_voiceCappedGenerationId != replyId &&
          ReplyChunker.sentenceCount(job.responseText) >=
              ReplyChunker.spokenReplyMaxSentences) {
        // Long enough to listen to: stop writing, and speak what there is.
        _voiceCappedGenerationId = replyId;
        unawaited(_generation.stop());
      }
      _voice.speakReplyChunk(job.responseText);
    } else {
      _voiceReplyGenerationId = null;
      _voice.finishReply(job.responseText);
    }
  }
}

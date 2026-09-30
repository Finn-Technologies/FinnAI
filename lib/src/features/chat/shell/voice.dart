// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellVoice on _HomeShellState {
  Future<void> _openVoiceMode() async {
    if (!voiceSupportedOnPlatform || _busy) return;
    _voice.setSpokenResponses(VoiceSettingsStore.instance.spokenResponses);
    _voice.onTranscript = _onInlineTranscript;
    setState(() {
      _voiceListening = true;
      _voiceDraft = '';
    });
    await _voice.startListening();
    if (!mounted) return;
    if (_voice.error != VoiceChatError.none) {
      _voice.onTranscript = null;
      setState(() => _voiceListening = false);
      _showVoiceFailure();
    }
  }

  void _onInlineTranscript(String text) {
    if (!mounted || !_voiceListening) return;
    setState(() => _voiceDraft = text);
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _endVoiceListening() async {
    if (!_voiceListening) return;
    setState(() => _voiceListening = false);
    _voice.onTranscript = null;
    await _voice.stopListening();
    if (!mounted) return;
    final heard = _voiceDraft.trim();
    _voiceDraft = '';
    if (heard.isEmpty) return;
    await _sendVoiceTranscript(heard);
  }

  Future<void> _expandVoiceMode() async {
    if (!_voiceListening) return;
    setState(() => _voiceListening = false);
    _voice.onTranscript = null;
    await _voice.stopListening();
    if (!mounted) return;
    _voiceDraft = '';
    await openVoiceSheet(
      context: context,
      voice: _voice,
      onSendTranscript: _sendVoiceTranscript,
      onStopGeneration: _stopReply,
    );
  }

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
    await _send();
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
      _voice.speakReplyChunk(job.responseText);
    } else {
      _voiceReplyGenerationId = null;
      _voice.finishReply(job.responseText);
    }
  }
}

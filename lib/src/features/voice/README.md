# voice — speech in and out

**Entry points.** `voice_chat_controller.dart`, `reply_chunker.dart`, `voice_sheet.dart`, `speakable_text.dart`, `voice_settings_store.dart`, `tts_backend.dart`, and `stt/` (speech recognition; see `docs/decisions/0006-on-device-speech-recognition.md`).

**Invariants.**
- Foreground only: backgrounding stops the microphone and resets state.
- Text is sanitised by `SpeakableText` before TTS (no spoken code fences or table pipes).
- Speech recognition is on-device and never uses the platform recogniser: mic -> Silero VAD -> Whisper base, on one isolate (`stt/stt_worker.dart`). Only that file imports `sherpa_onnx`; the controller sees `SpeechBackend` only.
- The speech model (~161 MB) is downloaded with the language model (first run and the upgrade screen, via `InstallAddon`; best effort, never blocks the app) or, if that was skipped, from the voice sheet's download card; it is verified by SHA-256, freed when voice mode closes, and removed by "Delete all data". Change its files only with the size and digest from Hugging Face / the release asset.
- No partial words (Whisper is not streaming): the transcript arrives once, after the speaker stops.
- A cancelled session's in-flight result must never reach the next one (`SttResetDone`). Don't remove that handshake.
- Replies are spoken by on-device Piper voices (`tts/`, sherpa-onnx + `flutter_pcm_sound`), one per language, downloaded with the language model; `FallbackTtsBackend` uses the platform engine only when no on-device voice fits. Only voices with a redistributable licence may be added to `tts_voice_catalog.dart` (a test lists the rejected ones). A non-Latin language with no voice is not spoken, never read with the English voice.
- `VoiceChatController.startLive` is the hands-free loop: listen -> send -> think -> speak -> listen. It ends on the cross, 10 s of silence, an error, or backgrounding, and never reopens the microphone while Finn is speaking. Decisions in `docs/decisions/0007-live-voice-and-spoken-replies.md`.
- A spoken turn is short on purpose (`PromptAnalysis.spoken`, three-sentence cap, no speculative web search). Don't lengthen it without measuring `FINN_VOICE first_audio_ms`.
- Open licensing question: espeak-ng (GPL) is inside the sherpa-onnx native library. See ADR 0007.
- Android/iOS only (`voiceSupportedOnPlatform`).

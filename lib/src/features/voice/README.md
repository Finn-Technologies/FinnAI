# voice — speech in and out

**Entry points.** `voice_chat_controller.dart`, `reply_chunker.dart`, `voice_sheet.dart`, `speakable_text.dart`, `voice_settings_store.dart`, `tts_backend.dart`, and `stt/` (speech recognition; see `docs/decisions/0006-on-device-speech-recognition.md`).

**Invariants.**
- Foreground only: backgrounding stops the microphone and resets state.
- Text is sanitised by `SpeakableText` before TTS (no spoken code fences or table pipes).
- Speech recognition is on-device and never uses the platform recogniser: mic -> Silero VAD -> Whisper base, on one isolate (`stt/stt_worker.dart`). Only that file imports `sherpa_onnx`; the controller sees `SpeechBackend` only.
- The speech model (~161 MB) is downloaded with the language model (first run and the upgrade screen, via `InstallAddon`; best effort, never blocks the app) or, if that was skipped, from the voice sheet's download card; it is verified by SHA-256, freed when voice mode closes, and removed by "Delete all data". Change its files only with the size and digest from Hugging Face / the release asset.
- No partial words (Whisper is not streaming): the transcript arrives once, after the speaker stops.
- A cancelled session's in-flight result must never reach the next one (`SttResetDone`). Don't remove that handshake.
- Replies are spoken by the on-device Supertonic 3 voice (`tts/`: our C++ runner `android/app/src/main/cpp/finn_supertonic.cc` over ONNX Runtime, reached by FFI on a worker isolate, audio to `flutter_pcm_sound`). One ~398 MB model speaks every language, downloaded with the language model; `FallbackTtsBackend` uses the platform engine only when it is not installed. Only a model with a redistributable licence and **no phonemizer under a copyleft licence** may be listed in `tts_voice_catalog.dart`. Decisions: `docs/decisions/0008-licence-clean-voice.md`.
- The voice has four speaking styles (`ttsStyles` in `tts_voice_catalog.dart`). The picker lives in `settings_voice_page.dart`, the choice in `VoiceSettings.ttsStyle` (falls back to `defaultTtsStyle`), and each utterance carries it through `LocalTtsBackend` into `TtsEngine.synth`, where the worker loads that style file (unknown names fall back).
- `VoiceChatController.startLive` is the hands-free loop: listen -> send -> think -> speak -> listen. It ends on the cross, 10 s of silence, an error, or backgrounding, and never reopens the microphone while Finn is speaking. Decisions in `docs/decisions/0007-live-voice-and-spoken-replies.md`.
- A spoken turn is short on purpose (`PromptAnalysis.spoken`, three-sentence cap, no speculative web search). Don't lengthen it without measuring `FINN_VOICE first_audio_ms`.
- sherpa-onnx is built from source with TTS off (`tool/rebuild_sherpa_android.sh`) so espeak-ng (GPL) is not in the app; rerun the script's `espeak[_-]ng` check after upgrading it. `FINN_TTS_PROBE` (`--dart-define`) logs synthesis timings per language.
- Android/iOS only (`voiceSupportedOnPlatform`).

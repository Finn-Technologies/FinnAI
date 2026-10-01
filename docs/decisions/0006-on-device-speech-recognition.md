# 0006 — Speech recognition runs on the device, without the platform recogniser

**Status.** Accepted 2026-10-01. Implemented and exercised on a Xiaomi 2109119DG (Snapdragon 778G): see the PLAN.md entry for numbers.

**Context.** Voice mode used `speech_to_text`, which wraps Android's `SpeechRecognizer`. That needs a recognition service installed (the test phone has none), may send audio to the vendor's servers when no offline pack exists, and behaves differently on every OEM. FinnAI's promise is that nothing leaves the device.

**Decision.**
- Microphone audio (16 kHz mono, `record`) goes to Silero VAD, which cuts it into utterances. Each utterance is transcribed by Whisper base (multilingual, int8) through `sherpa_onnx`. Both run on one background isolate (`stt/stt_worker.dart`, the only file importing `sherpa_onnx`).
- The end-of-speech silence is 0.9 s, set by the VAD. It replaces the platform recogniser's `pauseFor`.
- The language is auto-detected (Whisper `language: ''`), because the app ships in five locales and the user base is global.
- The speech model (~161 MB: encoder, decoder, tokens, VAD) is pinned by size and SHA-256 in `stt/stt_model_store.dart`. It downloads right after the language model, in first-run setup and on the upgrade screen (existing users with the language model but no speech model go through that screen once). Onboarding does not know about voice: `app/speech_model_addon.dart` hands it an `InstallAddon`, and `onboarding/model_install.dart` runs it with one progress bar across both. It is best effort: a failed speech download never blocks the app; it is remembered (`<model dir>.failed`) so an offline launch does not wait on it again, and voice mode offers the download itself (the inline voice button opens the voice sheet's download card). It is deleted by "Delete all data". It is a second artifact, not a second language model: ADR 0005 still holds.
- It is loaded only while voice mode is open and freed when the sheet closes or the app is backgrounded, because the language model needs that memory.
- Text-to-speech was left on the platform engine here; [0007](0007-live-voice-and-spoken-replies.md) replaces it with on-device voices. LFM2.5-VL cannot produce audio.

**Alternatives rejected.**
- *LFM2.5-Audio.* A separate 1.5B model that cannot share memory with LFM2.5-VL; English only as of this decision; its runner is an unmerged llama.cpp pull request.
- *whisper.cpp over FFI.* No maintained Flutter plugin, and a second ggml build beside llama.cpp.
- *Streaming Zipformer.* Gives live partial words, but the multilingual coverage is far smaller.

**Consequences.**
- Setup downloads ~161 MB more (about 10%). The download uses the app's own HTTP client, not the language model's foreground service, so it is not guaranteed to survive backgrounding; it resumes from the `.part` file.
- No partial words: the transcript appears once, shortly after the speaker stops. The `liveTranscript` setting has nothing to show for now.
- Whisper pads every clip to 30 s, so the cost per utterance is roughly fixed. Measure `FINN_STT decode_ms` and `stop_to_text_ms` on the target phone before calling it fast enough; if not, try `tiny` or a Moonshine path for English.
- Whisper can invent text on noise. The VAD gates most of it and `transcript_filter.dart` removes bracketed non-speech tags. Watch for the rest on a device.
- Adds about 27 MB of native libraries (ONNX Runtime and sherpa) to the arm64 APK; they are 16 KB aligned.
- Log tags: `FINN_STT` (`load_ms`, `decode_ms`, `stop_to_text_ms`). Logs carry timings, never audio or text.

# voice — speech in and out

**Entry points.** `voice_chat_controller.dart`, `voice_sheet.dart`, `speakable_text.dart`, `voice_settings_store.dart`.

**Invariants.**
- Foreground only: backgrounding stops the microphone and resets state.
- Text is sanitised by `SpeakableText` before TTS (no spoken code fences or table pipes).
- Android/iOS only (`voiceSupportedOnPlatform`); the device has no recognizer or TTS by default, so verify on a phone that does.

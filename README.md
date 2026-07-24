# Finn AI

Android-first Flutter app for a private, fully local AI assistant.

## Current phase

- Figma-aligned onboarding flow
- Animated ambient canvas and page transitions
- Interactive Bonsai model selection and precautions
- Keyboard-aware chat composer
- Real, token-streaming llama.cpp inference on a worker isolate
- Resumable and SHA-256-verified model downloads
- Dedicated Models manager with storage usage, recommendations, pause/resume,
  active-model selection, and safe removal
- Device-aware threads, batch/context sizing, mmap, quantized KV cache, and
  safe compatibility fallbacks
- Sliding sidebar and creations gallery
- 390×844 visual regression baseline

The app offers official Prism ML Bonsai 1.7B, 4B, and 8B `Q1_0` GGUF models.
Weights are not bundled in the APK: the user approves the one-time download,
then chat inference remains local. The current native package targets 64-bit ARM
devices running Android 8.0 or newer and always retains a CPU execution path.

## Run

```sh
flutter pub get
flutter run
```

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```

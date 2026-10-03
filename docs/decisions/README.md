# Decisions

Short records of why the code is shaped the way it is. Read the relevant one before undoing it. To change a decision, add a new record that supersedes the old one.

| # | Decision | Status |
|---|---|---|
| [0001](0001-app-driven-search.md) | The app decides when to search; the model only answers | Accepted, implemented 2026-09-30 |
| [0002](0002-keyless-on-device-search.md) | Search stays keyless and on-device | Accepted |
| [0003](0003-template-first-creations.md) | Creations are template-first | Accepted, implemented 2026-09-30 |
| [0004](0004-lite-device-tier.md) | A Lite tier for 4 GB devices | Accepted, not yet implemented |
| [0005](0005-single-model.md) | One model, pinned | Accepted |
| [0006](0006-on-device-speech-recognition.md) | Speech recognition runs on the device (sherpa-onnx + Whisper), not the platform recogniser | Accepted, implemented 2026-10-01 |
| [0007](0007-live-voice-and-spoken-replies.md) | Live voice: a hands-free loop, short spoken answers (voice parts superseded by 0008) | Accepted, implemented 2026-10-01 |
| [0008](0008-licence-clean-voice.md) | Supertonic 3 voice, sherpa-onnx without espeak-ng | Accepted, implemented 2026-10-02 |
| [0009](0009-flows-v3.md) | Flows v3: block tree, native triggers, background runs, authoring from a sentence | Accepted, implemented 2026-10-02 |
| [0010](0010-finnai-code.md) | FinnAI Code: a second app inside the app (workspace shell, text-protocol agent, bring-your-own providers) | Accepted, implemented 2026-10-03 |

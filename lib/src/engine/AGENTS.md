# engine/ — rules for this directory

Read the root `AGENTS.md` first. This adds what is specific to the native runtime.

- **Only `engine/backends/llama_shim.dart` imports `package:llama_cpp_dart`.** `tool/verify_engine_seam.sh` enforces it.
- **engine/ must not import `features/`, `app/`, `shared/` or `platform/`.** `tool/verify_boundaries.sh` enforces it. No violation is baselined; keep it that way. Pass what the engine needs in through an interface or a type that lives in `engine/api/` (e.g. `WebSource`).
- App code imports `lib/src/inference/*`, never `engine/` paths.
- `finn_accelerator.dart` is a 4,479-line god-class being split into download / loader / session / generate / metrics. **Do not add code to it.** Put new behaviour in a new file and call it.
- Exactly one model. Never change `downloadUrl`, `expectedBytes` or `sha256Digest` without verifying against Hugging Face LFS metadata.
- Android is CPU-pinned. Do not re-enable accelerator probing (see `optimizeForDevice`).
- Any behaviour change is measured: run `tool/run_eval.sh` before and after and compare against the gates in `eval/README.md`. Speed claims need numbers from a device.
- Log tags stay `FINN_*`. Logs carry numbers, never prompt or answer text.

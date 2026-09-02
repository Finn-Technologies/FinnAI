// Shim that re-exports llama_cpp_dart inside the engine layer.
//
// Engine-seam rule: ONLY files inside `lib/src/engine/**` may reference
// `package:llama_cpp_dart` (directly or through this shim); everything else
// in the app depends on the public facade `lib/src/engine/finn_engine.dart`.
// The rule is enforced by `tool/verify_engine_seam.sh`, which scans all of
// `lib/`.
//
// Prefer engine-owned types from `finn_engine_types.dart` /
// `prompt/prompt_intent.dart` for new code; import this shim only when a
// native FFI type has no engine-owned counterpart yet.

export 'package:llama_cpp_dart/llama_cpp_dart.dart';

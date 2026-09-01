// Shim that re-exports llama_cpp_dart for transitional decoupling.
//
// ONLY files inside `lib/src/engine/backends/` may import
// `package:llama_cpp_dart`. All other engine files must import this shim
// (or better, `package:finn_ai/src/engine/api/engine_api.dart`) so that
// `grep -r "llama_cpp_dart" lib/src/engine --exclude=backends` stays clean.
// This shim is intentionally confined to Phase 1 — subsequent phases replace
// its usages with engine-owned types from `api/engine_api.dart`.
//
// Do not add new consumers of this shim; new code should depend on
// `FinnEngine` / `EngineMedia` / `PromptSpec` instead.

export 'package:llama_cpp_dart/llama_cpp_dart.dart';

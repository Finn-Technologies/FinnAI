/// Public facade of the FinnAI on-device inference engine.
///
/// The engine layer (`lib/src/engine/**`) owns every direct
/// `package:llama_cpp_dart` usage; the rest of the app — including
/// `main.dart` and the UI — depends only on this library. The rule is
/// enforced by `tool/verify_engine_seam.sh`.
///
/// Exports:
/// - [FinnAccelerator] (also aliased as `FinnEngine` and `FinnInference`):
///   the production engine facade.
/// - Engine-owned value types, configs, streams, and the prompt formatter.
library;

import 'backends/llama_shim.dart';

export 'finn_accelerator.dart';
export 'finn_engine_config.dart';
export 'finn_engine_stream.dart';
export 'finn_engine_types.dart';
export 'prompt/prompt_formatter.dart';

/// Routes the native llama.cpp runtime's log output to [path].
///
/// Used by the benchmark/eval harnesses (which live in `main.dart` and must
/// not import the FFI package directly). Non-harness builds never call this.
void setLlamaNativeLogCapturePath(String path) =>
    LlamaEngine.logCapturePath = path;

/// Overrides the directory used for repacked benchmark weights.
///
/// The benchmark model lives on `/data/local/tmp`, which SELinux keeps
/// read-only for the app, so the harness redirects the repack cache into an
/// app-writable directory. Non-harness builds never call this.
void setLlamaRepackCacheDir(String path) => LlamaEngine.repackCacheDir = path;

# FinnAI worker extension

This directory vendors `llama_cpp_dart 0.9.0-dev.9` at commit
`1a8c7563cb5382e23bcd20dc5720fc8d8099ec58`.

FinnAI adds one worker-protocol operation: prefill queued tokens without a
sampler or sampled output. State persistence remains the package's existing
codec over upstream llama.cpp `llama_state_seq_get_data` and
`llama_state_seq_set_data`; no native KV memory is serialized manually.

The engine-ready response also exposes the compiled source identity and
`llama_print_system_info()` for native runtime audits.

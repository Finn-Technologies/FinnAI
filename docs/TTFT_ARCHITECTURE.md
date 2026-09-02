# Time-to-first-visible-token architecture

TTFT is measured from the accepted Send action to the first frame containing a
non-empty, sanitized assistant token. Diagnostics never contain prompt,
history, Skills, profile, or private-context text.

## Root cause before this change

The previous path called `prewarm()` before it selected a deterministic route,
so a cold process could pay for a model load that the selected route then
could not reuse, and a cold run could produce no visible token inside 32
seconds while the model was still loading.

The first Flutter token was also held by the ordinary 50 ms repaint batch.
Only one conversation session was retained per model, so switching chats
disposed the prior KV state. Background pause could unload all engines after
35 seconds.

## Current path

1. Start a monotonic, prompt-free `TtftTrace` at Send.
2. Run deterministic intent classification and select a direct route.
3. Refresh RAM and Android thermal state.
4. Reuse an existing engine or the exact deduplicated prewarm load.
5. Reuse an isolated conversation session when its conversation, model, prompt
   configuration, private-context hash, and history count match.
6. Render only relevant Skills and useful non-empty history. An unchanged
   per-intent task policy already present in a warm conversation KV is not
   appended again.
7. Start llama.cpp generation.
8. Record the first native and first sanitized non-empty token.
9. Deliver that first token immediately; batch later repaint notifications.
10. Record the first completed Flutter frame.

`FINN_TTFT` is JSON. `FINN_TTFT_SUMMARY` is a readable one-line summary.
`FINN_PROMPT` reports estimated token contributions by base policy, router,
task instruction, private configuration, history, user prompt, and wrappers.
The gated device harness emits `FINN_BENCH` per run and
`FINN_BENCH_SUMMARY` with minimum, p50, p90, p95, and maximum.

## Phase precision

`llama_cpp_dart 0.9.0-dev.9` exposes engine/session creation and the first
native token, but its isolate facade does not emit separate tokenisation,
prefill-start, prefill-complete, or first-sample timestamps. Consequently:

- model load and session creation are measured directly;
- prompt construction is measured directly;
- tokenisation + prompt evaluation + first sampling are reported honestly as
  the combined `prompt_eval_ms`;
- `first_decode_ms` is `null`, rather than fabricated;
- prompt-token count is currently a labelled estimate.

Adding exact native prefill events requires a maintained change to the
`llama_cpp_dart` worker protocol. It is intentionally not patched in the
Pub-cache or inferred from wall-clock gaps.

## Residency and prewarming

Residency levels are unloaded, engine ready, base-prefix ready, and
conversation warm. The single production model (LFM2.5-VL 1.6B) is prewarmed
after the first frame and essential storage initialisation. One load job
exists for the model; Send joins the same future if prewarming is in progress.

On a balanced device the runtime keeps two LRU conversation sessions per
model, using distinct llama.cpp sequence IDs. Entry devices retain one and
flagships retain three. Conversation IDs never share a cache entry.

Foreground navigation, sidebar use, chat switching, generation completion, and
short idle periods do not unload engines. A delayed background release remains
available. Memory pressure releases:

1. inactive conversation sessions;
2. remaining active/recoverable sessions;
3. secondary engines;
4. the selected/default engine only when Android reports low memory.

## Prefix state

The dependency supports saving/restoring a complete session state, but its
public isolate `append` command only tokenizes and queues text; it does not
evaluate that text into KV. Generation performs prefill but always samples at
least one token, including when `maxTokens` is zero, and there is no public
sequence-clone command. Treating queued-token state as a prefix-KV hit would be
incorrect, while retaining the sampled token would alter the prompt.

FinnAI therefore implements the full compatibility key and exact
conversation-session KV reuse, but does not claim a new-chat base-prefix hit.
The compatibility key includes model SHA-256, system-prompt version,
chat-template version, private-context hash, context size, actual KV type,
tokenizer settings, and intent route. Raw private configuration is never
metadata. Safe shared-prefix reuse requires a maintained prefill-only or
sequence-clone command in the dependency worker protocol.

## Thermal policy

Android supplies current thermal status and one-shot thermal headroom with the
normal device-profile read. The measured balanced-device cool plan uses 5
decode and 8 batch threads with 512/256 batches. Severe heat suppresses
background prewarm and changes newly loaded engines to 4/4 threads with
256/128 batches. The UI truthfully warns that local generation may start more
slowly. Missing thermal APIs leave the normal policy unchanged.

## Benchmark controls

The profile harness accepts:

- `FINN_BENCHMARK=true`
- `FINN_BENCH_SCENARIO=true_cold|model_warm|prefix_warm|conversation_warm|direct_plus|ambiguous`
- `FINN_BENCH_RUNS`
- `FINN_BENCH_PREWARM=selected`
- `FINN_BENCH_THREADS`
- `FINN_BENCH_BATCH_THREADS`
- `FINN_BENCH_BATCH`
- `FINN_BENCH_UBATCH`
- `FINN_BENCH_F16_KV`
- `FINN_BENCH_FLASH_OFF`

The production model catalog (LFM2.5-VL 1.6B) is unchanged; there is a single
model and no tier selection.

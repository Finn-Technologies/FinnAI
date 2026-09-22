# Chat generation architecture

Finn AI permits one active native chat generation. Navigation is independent
of that generation: opening or creating another chat never transfers ownership
of its output.

## Ownership

`ChatGenerationController` owns the active `ChatGenerationJob`. A job captures
stable `generationId`, `conversationId`, `assistantMessageId`, original prompt,
model name, state, accumulated text, start time, cancellation state,
continuation count, finish reason, and an epoch.

Every token and persistence write is checked against both the captured
generation ID and epoch. `ConversationStore.updateMessageInConversation`
targets stable conversation and message IDs without activating the
conversation, verifies that the message is an assistant message, and can reject
a stale generation ID. The visible chat is never used as an output target.

The owning chat displays the live response and progress. Other chats display
only their stored messages plus a compact **Generating in another chat**
notice with Open and Stop actions. The native-engine busy state disables a
second send.

## State and finish reasons

```text
preparing -> generating -> complete
                      \-> token-limited -> one continuation -> complete
                      \-> error
preparing/generating -> stopping -> stopped
persisted generating + process restart -> interrupted
```

Stored assistant messages distinguish `complete`, `generating`, `stopped`,
`interrupted`, `tokenLimited`, and `failed`. Startup reconciliation changes an
abandoned `generating` record to `interrupted` without deleting its partial
text. Only token-limited messages offer the one-shot Continue action.

User-visible progress reports actual runtime state: Preparing locally,
Understanding your request, the selected Finn AI model, Generating response,
or Stopping. Hidden reasoning, prompt context, HTML, and routing markers remain
sanitized and are never used as progress text.

## Persistence

Streaming output is batched every 350 ms and written with the job's captured
conversation and assistant-message IDs. It is also flushed on conversation
switch, Stop, EOS, token limit, error, app inactive/pause, widget disposal, and
before relevant memory release. Valid partial output is preserved on Stop and
failure. An empty cancelled placeholder is removed.

The safe deletion policy is to reject deletion of a conversation while one of
its assistant messages is marked `generating`. The user can Stop first and
then delete it.

## Cancellation

Stop performs these operations in order:

1. synchronously marks the job cancellation-requested and invalidates its
   epoch;
2. immediately shows Stopping and invokes native cancellation;
3. ignores every later callback from the invalid epoch;
4. waits up to one second for native acknowledgement and partial persistence;
5. cancels the Dart subscription after native closure, avoiding a close/cancel
   stream-bridge deadlock;
6. resets the native runtime if acknowledgement or listener cleanup times out;
7. persists the partial response and returns the controller to a sendable
   terminal state.

Repeated Stop calls share the same cleanup future. Runtime logs include
`FINN_CANCEL native_ack_ms=… composer_unblocked_ms=… late_tokens=…
reset_required=…` for physical-device validation.

## Hardware guidance reliability

Hardware repair and upgrade prompts use a dedicated task contract. It requires
the exact manufacturer/model before device-specific advice, recognizes that
RAM can be soldered, socketed, or mixed, defers compatibility and disassembly
facts to manufacturer specifications/service manuals, and prohibits invented
slot labels, layouts, screws, limits, or a universal two-slot assumption.
General safety guidance includes electrostatic precautions and disconnecting
external and internal power where appropriate.

## Known gap: deterministic output for the tool-decision turn

The search-decision turn and the device-action turn are routing decisions, not
prose, and both parse JSON. The parser is deliberately forgiving (XML tool
tags, bare objects, function-call syntax) because a 1.6B model formats output
inconsistently; today the app filters and validates after the fact.

Constraining that turn with a GBNF grammar — llama.cpp supports it, and the
vendored sampler params already carry `GrammarConfig` — was attempted and
**must not be shipped until both of the following are true**:

1. **The binding must reject a failed grammar.** When `llama_sampler_init_grammar`
   cannot compile a grammar it returns NULL, and
   `third_party/llama_cpp_dart/lib/src/sampling/sampler_factory.dart`
   (`_addGrammar`) adds it to the chain unchecked. The first sample then
   dereferences NULL. Observed on device (release build, emulator
   `sdk_gphone16k_arm64`, pinned llama.cpp `d6d0ce8`) as
   `Fatal signal 11 (SIGSEGV) … SEGV_MAPERR, fault addr 0x0` with
   `#01 libllama.so (llama_sampler_sample+1136)` and nothing on the Dart side —
   no exception, no log, just a dead process mid-turn. The guard belongs in the
   vendored package, which `AGENTS.md` routes through
   `tool/llama_android_build.patch` + `tool/rebuild_llama_android_aar.sh`
   rather than hand-editing.
2. **The grammar must be provably valid before it reaches the device.** The
   first attempt used a hand-built grammar; after it crashed, the retry used
   the `str`/`ws` rules copied verbatim from the `json.gbnf` shipped with the
   pinned commit (and no unreachable rules) and **still** crashed identically.
   So the cause is not the obvious syntax differences, and there is no local
   way to validate a grammar: the only parser is the native one, and
   `flutter test` cannot load a model to run it.

Until then the working invariant is: sampling is unconstrained, and the app
handles malformed tool output by parsing, validating, and falling back.

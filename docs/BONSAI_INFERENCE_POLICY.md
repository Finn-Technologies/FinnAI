# Bonsai inference policy

FinnAI keeps model execution, device planning, and task policy separate. The
deterministic `PromptIntentClassifier` recognizes English, Italian, Spanish,
French, and German signals before model loading. Its result controls routing,
the latest-turn system instruction, output budget, and sampler profile.
Factual questions bypass the private Lite routing pass when Plus is available.
This avoids both a weak 1-bit factual endpoint and an unnecessary router
prefill. Lite remains the fallback on devices capped to Lite.

The production model catalog and default remain unchanged.

## Routing

| Intent | Preferred route when available |
|---|---|
| Greeting | Lite |
| Ordinary or ambiguous factual question | Plus (Lite fallback) |
| Recipe, structured how-to | Plus |
| Writing, comparison, coding, analysis, creative, high-stakes | Plus |
| Any genuinely advanced request | Pro |

Routes are bounded by the user's selected/automatic device tier. A route never
downloads a model above that tier. The existing UI approval remains required
before missing models in the selected adaptive set are downloaded. If only Lite
is available, every route safely falls back to Lite.

## Output budgets

Budgets are ceilings; EOS remains the normal stopping condition.

| Intent | Desired ceiling |
|---|---:|
| Greeting | 96 |
| Quick question, translation | 224 |
| Recipe, how-to | 320 |
| Writing, comparison, creative | 512 |
| Coding, analysis, high-stakes | 768 |

The final budget is the minimum of the intent ceiling, device plan, and model
tier ceiling (Lite 320, Plus 512, Pro 768). Unsupported devices retain a
160-token defensive cap.

## Sampling

| Profile | Temperature | Top K | Top P | Min P | Repeat penalty | Last N |
|---|---:|---:|---:|---:|---:|---:|
| Structured/factual | 0.20 | 20 | 0.85 | 0.02 | 1.05 | 128 |
| Normal chat | 0.50 | 20 | 0.90 | 0.02 | 1.03 | 128 |
| Creative | 0.70 | 40 | 0.95 | 0.02 | 1.05 | 128 |

These initial profiles use fields directly supported by
`llama_cpp_dart 0.9.0-dev.9`. Physical-model evaluation should decide whether
any value needs tuning.

## Completion and display

`DoneEvent.reason` is mapped to EOS, token limit, user cancellation, or error.
Only the controller's explicit stop path is displayed as user cancellation;
normal stream closure cannot produce a false **Stopped by you** label. A valid
token-limited partial response is preserved and gets a
one-shot **Continue** action. Continuation uses the original intent/language and
private configuration, requests no repetition, and cannot loop automatically.

Assistant output renders a deliberately small Markdown subset: headings,
bullets, numbered steps, bold, and inline code. Raw HTML, images, link targets,
thinking blocks, and routing markers are not rendered.

## Device evaluation harness

The compile-time `FINN_EVALUATION` harness runs a fixed multilingual suite
against any set of GGUF files already copied into app-readable storage. It
prints one `FINN_EVAL` JSON record per prompt with model label, intent, route,
budget, finish reason, latency, total time, token count, throughput, and full
response. Recipe, hardware, Bridgetown routing, and ant-necrophoresis cases
also include semantic acceptance flags.

Example profile invocation (paths must be readable by the app):

```text
flutter run --profile \
  --dart-define=FINN_EVALUATION=true \
  --dart-define='FINN_EVAL_MODELS=current=<app-files>/current.gguf;tuned=<app-files>/tuned.gguf;ternary=<app-files>/ternary.gguf;qwen08=<app-files>/qwen08.gguf'
```

Compare current Bonsai 1.7B Q1_0, the tuned build, Ternary Bonsai 1.7B, and
Qwen 3.5 0.8B Q4_K_M on the same device, thermal state, prompt order, and three
runs per prompt. Use semantic pass rate first, then truncation rate and latency.
Do not change the production default until those measurements are collected.

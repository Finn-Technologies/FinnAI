# eval/

Committed quality baselines for the on-device model, and the prompt files the
evaluation harness reads.

## Running an evaluation

```bash
./tool/run_eval.sh --prompts eval/prompts/multilingual.json   # gate against the committed baseline
./tool/run_eval.sh --write-baseline                          # measure a new baseline
BASELINE_SLUG=lite ./tool/run_eval.sh --write-baseline --lite --image eval/images/number42.png
```

`--lite` forces the Lite device policy (2048 context, text-only load, projector on first
image); `--image` adds the image case. A baseline name comes from `BASELINE_SLUG`
(default: your git user name + `-device`). The app writes the baseline into its own files
directory and the script reads it back with `run-as`, so it needs a debug build.

The phone needs the model already installed and the screen on. Read
`tool/run_eval.sh` for the full flag list.

## What a baseline is

One JSON file per device class, e.g. `baseline_<device>.json`:

- `model`, `context_tokens`, `device` — the identity of the experiment. A
  2048- and a 4096-context run are different experiments; the gates refuse to
  compare across them.
- `gates` — the thresholds this baseline is judged against.
- `summary` — the aggregate numbers.
- `observations` — one entry per generated turn.

A baseline deliberately contains **no prompt or answer text**. The suites live
in `lib/src/engine/eval/eval_prompts.dart`; the observations record only
counts, latencies, routes, and which machine checks passed. That is what makes
it safe to commit a file produced from a real phone.

## Gates

Read from the baseline, so tightening one is a reviewable diff:

| Gate | Meaning |
|---|---|
| `empty_reply_rate` | a turn that rendered nothing. The device run caught 2 of 21; the bar is 0.02. |
| `browse_precision` | share of must-not-browse turns that stayed local. Bar 1.0 — the web firing on "capital of France" five times out of five is the bug, not the norm. |
| `browse_recall` | share of must-browse turns that did reach the web. |
| `ttft_p95` | relative to the baseline, +25%. |
| `decode_speed` | relative to the baseline, −15%. |
| `check_pass_rate` | relative to the baseline, −5%. |

A gate whose denominator is zero is not emitted. A run that measures nothing
must never read as a pass.

## Prompt files

`prompts/*.json` extend the built-in catalog without touching Dart. Each entry
is a case object; `checks` may be full check objects
(`{"check": "contains_any", "needles": ["Paris"]}`).

`prompts/multilingual.json` is the deferred non-Latin half of PLAN.md §2 Suite B:
`adb shell input text` mangles non-ASCII (Devanagari arrived as literal
`\xNN`), so those prompts have to reach the device as a file.

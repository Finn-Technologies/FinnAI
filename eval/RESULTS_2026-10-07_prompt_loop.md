# Answer shaping, loop guard, prompt-read cost — 2026-10-07

Device: Android emulator (API 37, arm64, 4 cores, host GPU) on an M-series MacBook Air, the LFM2.5-VL 1.6B model,
2048 context (the emulator's policy), the built-in eval suite (34 cases, 40 turns), `./tool/run_eval.sh`. The Air
has no fan: decode speed and first-token times drift down over consecutive runs of the *same* code (75 → 64 tok/s
over three old-code runs), so speed is compared on the first run after a pause. Sampling is temperature 0.3 with a
fresh seed per turn, so pass rates move a few cases between runs; each side was run three times.

## What changed

1. **System prompt shaping rules** (`prompt_formatter.dart`): the "rich editorial article" rule used to fire on any
   entity, so "What is the largest planet?" got a headline and sections. Now: a question with one answer gets it
   first, in one sentence; an article only when a broad subject is asked about in depth; never repeat a line; stop
   when complete. Shorter than before (it is cached, so this costs nothing per turn).
2. **Task instructions**: translation replies with only the translation, once; creative writing writes the piece
   once and stops; a quick question puts the answer in the first sentence.
3. **Loop guard** (`generate/loop_guard.dart`): a reply whose tail is the same block repeated (three times for a short
   block, twice from 40 characters) ends as a finished reply and logs `FINN_LOOP`.
4. **Cancellation in the worker isolate** (`third_party/llama_cpp_dart/lib/src/isolate/worker.dart`): the generation
   loop only yielded through microtasks, so a `CancelCommand` sat in the port until the reply was fully decoded. A
   stopped reply (the Stop button, or the loop guard) kept decoding to its token budget and the next turn queued
   behind it — measured at ~8.5 s of extra first-token wait after each loop stop. The loop now gives the event loop a
   turn every 8 tokens (~0.1 s of cancel latency).

A shorter per-turn quick-question instruction was also tried (it is re-read on every chat's first turn: ~235 tokens,
~2.7 s on the Mi 11 Lite at 86 prompt tok/s). It lost the brevity (factual 25-50%, "largest planet" back to 49-91
tokens) and was reverted; the spoken instruction was shortened instead (not covered by the eval).

## Results

| Run | Code | Checks passed | First token p50 / p95 ms | Decode tok/s p50 | Output tokens (suite) |
|---|---|---|---|---|---|
| baseline | old | 71.9% | 554 / 4313 | 75.0 | 6,400 |
| old 2 | old | 68.8% | 578 / 3005 | 73.4 | 6,430 |
| old 3 | old | 56.3% | 629 / 4115 | 63.6 | 6,128 |
| new 1 | new (yield every token) | 87.5%¹ | 581 / 9105² | 74.4 | — |
| v3 a | new | 78.1% | 598 / 6299³ | 69.0 | 5,630 |
| v3 b | new | 71.9% | 709 / 4196 | 58.0 | 3,556 |
| v3 c | new | 81.3% | 951 / 4228 | 53.2 | 4,106 |
| **new baseline** | new | **81.3%** | 564 / 3144 | **74.6** | **3,544** |

¹ Prompt changes and loop guard only, before the worker fix. ² The ~9 s turns are the ones after a `FINN_LOOP` stop:
the worker-cancel bug above. ³ Set by web-search turns (network + a longer grounded prompt); local-only p95 was
0.84 s.

Mean checks passed: old **65.6%**, new (v3 + baseline) **78.1%**. Multilingual was 100% in every new run but the
baseline (75%), against 75/50/50% old; adversarial and recall up; factual moves between 50% and 100% with the seed
(old: 25-50%). Runaways: old runs hit the token cap on news, the Russian translation and nonsense input (672 tokens
each); the new runs did not loop on those.

**Not measured:** a physical phone (these are emulator numbers; the phone's baseline in
`baseline_Abhi-Flex1-device.json` is unchanged and should be re-run with `./tool/run_eval.sh` on the Mi 11 Lite);
the 3B tier; HarmonyOS.

## Final gated run (`a25df2b`, after the worker command-holding fix)

Checks passed 75.0%, first token p50 / p95 624 / 4112 ms, decode 66.0 tok/s (the Mac was warm), 4,539 output tokens.
**The gate fails** against the committed emulator baseline: check pass rate 75.0% is under its floor of 76.3%, and
p95 4112 ms is over its +25% bar of 3930 ms. Both are inside the spread measured for the new code above (71.9-87.5%;
p95 3.0-6.3 s, set by web-search turns), and the baseline is a single run that came out high. A steadier emulator
baseline would be the median of three runs; the gate's tolerances were set for a phone, where runs vary less.

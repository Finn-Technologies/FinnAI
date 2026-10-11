# FinnAI Code agent harness — redesign for a working local-model agent

**Date:** 2026-10-09
**Status:** Proposed (spec for review)
**Branch:** `finnai-code-harness`
**Supersedes:** the "text protocol" decision in `docs/decisions/0010-finnai-code.md`
(see new ADR 0014 to be written alongside implementation).

## Problem

FinnAI Code "doesn't work at all" with the on-device model. Verified cause: the
local gateway hands the model **unconstrained free text**, and reliability is
propped up by ~450 lines of regex heuristics in `agent/small_model_aids.dart`
(forced reply starts, format-slip "repair", run-command hints, forced file
headers). These are band-aids over a 1.6B model free-forming badly, and they are
insufficient: the model loops, drops its action, or answers in prose.

The engine already carries the machinery to fix this properly (GBNF grammar
constraint through `IntentSamplerProfile.grammar` → native
`llama_sampler_init_grammar`), and **Creations already proves the pattern that
works for this exact model**: a *closed output format + tuned sampler + extract
+ validate + a bounded repair round* — Creations does **not** use a grammar. The
fix is a clean, closed, OpenCode-style harness, not more heuristics.

## Goals

- The on-device model (1.6B **and** the 3B tier) reliably **performs real coding
  tasks**: creates files, reads them, edits them, runs commands, iterates on
  output, and stops when done.
- One bounded agent loop behind both the local model and cloud models, in the
  OpenCode mould: explicit tool calls in, structured observations out.
- Reliability comes from a **closed protocol + validate/repair + a tight prompt
  + per-tier tuning**, with a GBNF grammar as an on-device-tested booster — not
  from a growing pile of regex aids.
- Delete `small_model_aids.dart`.
- Nothing leaves the phone unless the user picks a cloud model (unchanged).

## Non-goals

- No cloud inference changes beyond adding tool-calling for cloud providers.
- No changes to the sandbox, command policy, runner dispatch, container/linux,
  sessions persistence format, or providers list.
- No new third tier. No engine behaviour edits (grammar flows through existing
  engine params via `inference/`).

## Architecture

```
user request
   │
   ▼
CodeAgent (bounded loop)            ← rewrite of agent/code_agent.dart
   │  system(env + tools + example) │  conversation + observations
   ▼
CodeModelGateway.complete()          ← stream of text fragments
   │  local: grammar-constrained closed format
   │  cloud: native tool-calling
   ▼
AgentProtocol.decode()               ← ONE action (validate + repair)
   ▼
AgentTool dispatch ──► CodeActionRunner / CodeWorkspace
   │  read | write | edit | list | bash | answer(terminal)
   ▼
observation appended ──► next step (until answer | step | repeat limit | stop)
```

### Tool set (kept tiny for a 1.6B; same for cloud)

One internal `AgentTool` type. Each maps to an existing primitive:

| Tool | Args | Backs onto | Approval |
|---|---|---|---|
| `read` | `path` | `workspace.readFile` (capped) | never |
| `list` | `path?` | `workspace.list` | never |
| `write` | `path`, `content` | `workspace.writeFile` | per mode (see perms) |
| `edit` | `path`, SEARCH/REPLACE | `EditBlocks` (cloud only) | per mode |
| `bash` | `command` | `runner` (linux/container/device) | per mode |
| `answer` | `summary` | terminal — ends the loop | n/a |

### The loop (bounds kept from today)

- One action per reply; stop reading the stream once one complete action is
  present (keep the current early-cancel).
- Unusable action (bad header, empty body, bad SEARCH/REPLACE) → a one-line
  **observation** naming the problem → the model retries, bounded (≤2 consecutive
  retries ends the request). This is Creations' repair round, applied per step,
  and it replaces `small_model_aids.dart`.
- Bounds: **step limit** (per tier/setting), **stop after the same action 3×**,
  the **user's stop button**, leaving the screen stops the request.
- Termination: the `answer` action; end quietly when work is clearly done.

### Permissions (unchanged semantics)

`askEveryTime` → bash waits for a tap; `acceptEdits` (default) → bash waits,
files are written as it goes; `autoRun` → nothing waits. `CodeSessionGrants`
unchanged ("Allow in this session" by kind/program; compound commands never
grantable).

## The one thing settled on the device: the local wire format (phase-1 spike)

Two decoders feed the same `AgentTool`. Cloud uses native tool-calling. For the
local model we A/B on device `ebe7291` and keep the best:

- **D1 — closed tagged block + extract/validate/repair (no grammar).**
  ` ```write path \n <raw content> \n``` `, ` ```bash \n <cmd> \n``` `,
  ` ```answer \n <summary> \n``` `. Content is raw (no escaping), like the
  current fenced format; decode is Creations-style (extract → validate → repair).
- **D2 — D1 + a GBNF grammar** forcing a valid header (tool + path) with a
  non-backtick body. Structure is machine-guaranteed; the model only supplies
  values.
- **D3 — JSON tool call + grammar.** `{"tool":"write","path":"a.sh","content":…}`
  with escaped newlines. Fully grammar-guaranteed, but escaping is hard for a
  1.6B.

**Decision rule:** pick the decoder under which the 1.6B reliably *chooses the
right tool* and *knows when it's done* across the task ladder below. If none
reach an acceptable bar, fall back to D1 and document the ceiling honestly. The
harness shape is fixed regardless; only the local wire bytes change.

## Per-tier model tuning (1.6B **and** 3B — hard requirement)

Both tiers run Code (`ADR 0013`) and **both must work well**; this pass is not
done until each tier performs the task ladder. This dev phone (`ebe7291`) runs
the **3B** tier naturally. To exercise the **1.6B** on the same phone, build with
the existing `--dart-define=FINN_FORCE_LITE=true` (the same flag `run_eval.sh
--lite` uses) so `ModelTierPolicy` selects the standard tier; the app downloads
the 1.6B artifacts once (~1.5 GB total). So one device covers both tiers:
**normal build → 3B**, **force-lite build → 1.6B**.

Knobs, all through existing engine params and measured on-device per tier:

- **Sampler** for the agentic loop: coding intent is `temp .30 / topK 30 /
  topP .90` today. Tune for tool-choosing (likely a touch cooler + higher
  repeat penalty to kill loops). Creations shows tempering matters.
- **System prompt** stays **≤1500 chars** (pinned by an existing test) and is
  identical in shape for both tiers; the worked example is shown to the small
  model, omitted for the 3B/large (they don't need it and their window is better
  spent on the project).
- **maxOutputTokens / observation & history budgets** per tier's context window
  (reuse `CodeBudget`), so a `write` isn't cut off mid-file.

Recorded as concrete constants + a short note of what each tier needed. This is
a **bounded, measured Tuning pass**, not open-ended: a defined task ladder per
tier, pass/fail recorded, settings chosen to make the ladder pass.

## Data model & persistence

`CodeMessage`/`CodeAction` remain the persisted unit (backward compatible: old
`shell`/`writeFile`/`editFile` sessions still load). Add `CodeActionKind`s
`readFile` and `listDir`; reuse the existing `path`/`output` fields for their
result. `answer` is stored as the assistant's final text (no action record).
Edit/write diffs keep using `previous`/`after` + `code_diff_view`.

## Files

**New**
- `agent/agent_tools.dart` — `AgentTool` enum, call/result types, tool specs,
  the GBNF grammar source (if D2/D3 win).
- `agent/agent_protocol.dart` — **rewrite**: system prompt builder, `decode`
  (per chosen decoder), repair notices, observation text, example turns.

**Rewrite**
- `agent/code_agent.dart` — the bounded loop over `AgentTool` dispatch.
- `providers/provider_client.dart` + `providers/code_wires.dart` — tool-calling
  for the three cloud request shapes.
- `providers/code_gateway.dart` + `providers/gateways.dart` — carry tools +
  grammar; local gateway builds the tuned agentic sampler.

**Modify**
- `sessions/code_session.dart` — new action kinds.
- `ui/code_tool_row.dart`, `ui/code_conversation.dart`, `ui/code_status_line.dart`,
  `ui/code_suggestions.dart` — a card per tool kind; read/list result view;
  `answer` as a normal final bubble.
- `test/features/code/agent_protocol_test.dart`, `code_agent_test.dart` — rewrite
  against the new protocol (fakes, no model/shell).

**Delete**
- `agent/small_model_aids.dart` (+ its tests).

**Docs**
- New ADR `0014` (supersedes the text-protocol clause of 0010, justifies
  tool-calling), update `features/code/AGENTS.md`, `README.md`, and
  `CODE_MAP.md` if file names move.

## Constraints held

- System prompt ≤1500 chars (pinned test); parser has a test in
  `agent_protocol_test.dart`.
- Engine seam intact (no `llama_cpp_dart` outside `engine/`; grammar via
  `inference/`); `tool/verify_engine_seam.sh` green.
- Boundaries green (`tool/verify_boundaries.sh`); no file >600 lines.
- `dart format` clean; `flutter analyze` clean; user-facing strings via
  `L10n.of(context)` in all 5 ARBs.
- On-device model measured with `tool/run_eval.sh` before/after only if engine
  behaviour is touched (it isn't expected to be).

## Testing strategy

1. **Hermetic (no model, no shell)** — `code_fakes.dart` scripted gateway +
   temp filesystem: decode of each tool, repair path, bounds (step/repeat/stop),
   approvals + grants, persistence round-trip, UI rendering per tool kind.
2. **On-device `ebe7291`, both tiers — hard requirement.** Two builds:
   - **3B (natural):** `flutter build apk --debug --no-pub` → install → drive Code.
   - **1.6B:** `flutter build apk --debug --no-pub --dart-define=FINN_FORCE_LITE=true`
     → install (downloads the 1.6B artifacts once) → drive Code.

   A task ladder with pass/fail recorded honestly, per tier:
   - "Create `count.sh` that prints 1..5, then run it." (create → run → report)
   - "Read `data.txt` and append a line with the sum of its numbers."
   - "Create `a.py` and `b.py` per these two specs." (multi-file, one per reply)
   - "This script errors — fix it." (read → edit/rewrite → run → iterate)
   Confirm the running tier from `FINN_ENGINE` logs for each build.

## Risks & fallbacks

- **Risk:** the 1.6B can't reliably *choose* the right tool or *stop* at
  `answer`. **Fallback:** D1 grammar-free + tighter prompt; if still unreliable,
  ship a smaller guaranteed-safe subset (e.g. write + bash + answer only) and
  document the ceiling. No silent claims.
- **Risk:** grammar hurts (locks the model into a wrong shape). Grammar is only
  kept if the device A/B shows it helps.
- **Risk:** tuning overfits one tier. Both tiers are measured independently via
  the two builds above; each tier's settings are recorded separately.

## Success criteria

- Hermetic suite green; analyze/format/boundaries/seam green.
- On-device, the create→run and read→change tasks pass on **both** tiers
  (3B natural + 1.6B force-lite), with the exact observed behaviour recorded
  (not inferred).
- `small_model_aids.dart` gone; no net growth in agent-side heuristics.
- Nothing leaves the device by default.

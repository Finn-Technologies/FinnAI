# FinnAI Code Agent Harness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make FinnAI Code actually perform coding tasks with the on-device model, via a clean bounded tool-call harness (OpenCode-style) that works on both the 1.6B and 3B tiers, replacing the fragile `small_model_aids.dart` heuristics.

**Architecture:** One bounded loop behind local + cloud. The model emits one structured action per reply; the harness decodes → validates/repairs → executes through existing primitives (`CodeWorkspace`, `CodeActionRunner`) → appends an observation → repeats until `answer`, a step/repeat limit, or stop. Reliability comes from a closed protocol + validate/repair + a tight prompt + per-tier tuning (Creations' proven pattern), with a GBNF grammar as an on-device-tested booster.

**Tech Stack:** Flutter/Dart; local model via `lib/src/inference` (engine GBNF grammar already wired); cloud via existing provider client; `package:test`/`flutter_test` for hermetic tests; on-device `adb`/`flutter build apk`.

**Spec:** `docs/superpowers/specs/2026-10-09-finnai-code-agent-harness-design.md`

## Global Constraints

- System prompt stays **≤1500 chars** (pinned by an existing test in `test/features/code/agent_protocol_test.dart`).
- Engine seam: only `engine/**` imports `package:llama_cpp_dart`; Code reaches the engine only via `inference/`. Grammar/`IntentSamplerProfile` flows through existing engine params — **no engine edits expected**.
- Boundaries green (`tool/verify_boundaries.sh`); **no Dart file >600 lines**; `dart format` clean; `flutter analyze` clean.
- User-facing strings via `L10n.of(context)` across all 5 ARBs; brand names stay untranslated; no ICU plurals.
- Backward compatibility: existing sessions (`shell`/`writeFile`/`editFile`) must still load and render.
- Both tiers (1.6B + 3B) is a **hard requirement**; each measured on-device independently (3B natural build; 1.6B via `--dart-define=FINN_FORCE_LITE=true`).
- Delete `agent/small_model_aids.dart`; no net growth in agent-side regex heuristics.

## Review Focus

Failures most likely to bite a user, and the test that pins each (added in the owning task):
1. **Plain-text reply means "done".** A prose reply with no action must end the loop and show as a normal bubble, not an error. → pinned in Task 6.
2. **No-shell environment.** Where `CommandEnvironment.none` (e.g. iOS), file tools still work and `bash` returns a clear "cannot run" observation rather than hanging. → pinned in Task 5 + Task 6.
3. **Malformed action recovery.** A bad header/empty body yields a one-line repair observation and one retry; **two consecutive** malformed replies end the request with a clear message, not an infinite loop. → pinned in Task 6.
4. **Approval + streaming.** Under `acceptEdits`, `bash` waits for a tap and streams live output; "Allow in session" widens by program and never trusts a compound command. → pinned in Task 5 + Task 6.
5. **Persistence & reopen.** Old sessions load; new `readFile`/`listDir` kinds round-trip; a reopened session never shows an action stuck "waiting for tap". → pinned in Task 4.

## File Structure

- `agent/agent_tools.dart` — **Create.** `AgentTool`, `AgentCall`, `AgentReply`, gBNF grammar source (added in Task 14 only).
- `agent/agent_protocol.dart` — **Rewrite.** system prompt, `decode`, `observationFor`, example turns, transcript/turns building. Delete the small-model lands here.
- `agent/code_tool_runner.dart` — **Create.** `ToolResult`, `CodeToolRunner` interface + `WorkspaceCodeToolRunner` (read/list via workspace; write/edit/bash via existing `CodeActionRunner`).
- `agent/code_agent.dart` — **Rewrite.** The bounded loop over `CodeToolRunner` + decoder + observations.
- `sessions/code_session.dart` — **Modify.** Add `CodeActionKind.readFile`, `listDir` (backward-compatible JSON).
- `providers/gateways.dart`, `providers/code_gateway.dart`, `providers/code_wires.dart`, `providers/provider_client.dart` — **Modify.** Carry the agentic sampler (grammar off until Task 14); local keeps agentPrompt path; cloud uses the same tagged-block format (native tool-calling deferred, see Task 14 note).
- `ui/code_tool_row.dart`, `ui/code_conversation.dart`, `ui/code_status_line.dart`, `ui/code_suggestions.dart` — **Modify.** A card per tool kind.
- `agent/small_model_aids.dart` — **Delete** (Task 9).
- Tests rewrite: `test/features/code/agent_protocol_test.dart`, `code_agent_test.dart`, extend `stores_test.dart` (persistence), extend `code_ui_test.dart`.
- Docs: `docs/decisions/0014-*.md`, update `features/code/AGENTS.md`, `README.md`, `docs/architecture/CODE_MAP.md`.

---

### Task 1: Tool/call types + the decoder (`decode`)

**Files:**
- Create: `lib/src/features/code/agent/agent_tools.dart`
- Modify: `lib/src/features/code/agent/agent_protocol.dart` (add `decode`; leave the rest for later tasks)
- Test: `test/features/code/agent_protocol_test.dart`

**Interfaces:**
- Produces:
  - `enum AgentTool { read, list, write, edit, bash, answer }`
  - `class AgentCall { AgentTool get tool; String get path; String get content; String get command; bool get isShell; bool get isEdit; const AgentCall.read(path); const AgentCall.list([path]); const AgentCall.write(path, content); const AgentCall.edit(path, blocks); const AgentCall.bash(command); const AgentCall.answer(summary); }`
  - `class AgentReply { AgentCall? get call; bool get malformed; bool get answer; String get prose; String get notice; bool get hasCall; }`
  - `AgentProtocol.decode(String raw, {required bool allowShell, required bool allowEdit}) -> AgentReply`

- [ ] **Step 1: Write the failing tests.** Cover: `read`/`write`/`edit`/`bash`/`answer` decode from tagged blocks (```` ```write a.txt\nhi\n``` ````→`AgentCall.write('a.txt','hi\n'/'hi')`; ```` ```bash\nls -la\n``` ````→`AgentCall.bash('ls -la')`; ```` ```list\n``` ````→`AgentCall.list('')`; ```` ```answer\nDone.\n``` ````→`reply.answer==true, reply.prose=='Done'`). A **plain prose** reply (no fence) → `answer==true`, `prose==that text`. A cut-off block (no closing fence) → **not** emitted as a call (`hasCall==false`). An `edit` block while `allowEdit:false` → `malformed==true` with a `notice` that says to use `` ```write ``. A `write` with no path (```` ```write\nbody\n``` ````) → `malformed==true`. Content with a single line of backticks uses a 4-backtick fence rule (model told to outer-fence with 4); assert a body containing ``` inside a 4-fence parses. Shell tag set `{sh,bash,shell,console}`; file tag set `{file,write,create,save}`; edit tag set `{edit,patch}`.
- [ ] **Step 2: Run and confirm FAIL** (`flutter test --no-pub test/features/code/agent_protocol_test.dart`) — undefined symbols.
- [ ] **Step 3: Implement** `AgentTool`, `AgentCall`, `AgentReply`, and `AgentProtocol.decode` reusing the existing fence-scanning approach in the current `agent_protocol.dart` (`_openingFence`/`_closes`/`_actionFor`) generalized to `AgentCall`. `answer` decodes from an `answer` tag OR from a reply with no recognized action fence.
- [ ] **Step 4: Run and confirm PASS.**
- [ ] **Step 5: Commit** `feat(code): agent tool/call types + decoder`.

---

### Task 2: System prompt + example turns

**Files:**
- Modify: `lib/src/features/code/agent/agent_protocol.dart`
- Test: `test/features/code/agent_protocol_test.dart`

**Interfaces:**
- Produces:
  - `AgentProtocol.systemPrompt({required bool allowShell, required bool allowEdit, required CommandEnvironment env}) -> String` (≤1500 chars; assert length).
  - `AgentProtocol.exampleTurns({required bool allowShell}) -> List<CodeTurn>` (ask → act → observe → act → answer).

- [ ] **Step 1: Write the failing tests.** Assert `systemPrompt(...).length <= 1500`. Assert it names the exact action tags the small model may use (`read`, `write`, `list`, and `bash` iff `allowShell`, `edit` iff `allowEdit`), the rule "one action per reply then stop", the rule "paths relative, never `/` or `..`", the command environment line (device vs Alpine-linux vs busybox-container vs none). Assert `exampleTurns` opens with a `write`/`bash` action and closes with a plain-text `answer`.
- [ ] **Step 2: Run → FAIL.
- [ ] **Step 3: Implement** the prompt builder (count characters; trim to fit). Reuse `CommandEnvironment` (already imported by the code feature).
- [ ] **Step 4: Run → PASS.
- [ ] **Step 5: Commit** `feat(code): agent system prompt + example`.

---

### Task 3: Observations (tool result → next user message)

**Files:**
- Create: `lib/src/features/code/agent/code_tool_runner.dart` (only the `ToolResult` type now)
- Modify: `lib/src/features/code/agent/agent_protocol.dart`
- Test: `test/features/code/agent_protocol_test.dart`

**Interfaces:**
- Produces:
  - `class ToolResult { final bool ok; final String text; final int? exitCode; final bool truncated; final bool timedOut; final PolicyReason? denied; final String? previous; final String? after; }`
  - `AgentProtocol.observationFor(ToolResult r, {required AgentTool tool, {String path = ''}}) -> String`? — Use signature: `observationFor(ToolResult result, {required AgentTool tool})`. It returns the message fed back: a `write` → "Wrote path (N chars)…"; a `read`/`list` → the content (clipped to a budget); a `bash` → "Result (exit code N):\n<output>" or "The command timed out…"/denied reason; a denied action → the policy sentence.

- [ ] **Step 1: Write the failing tests.** One per outcome: write-ok (mentions path + byte count), read-ok (returns clipped content), bash-ok ("Result (exit code 0):"), bash-failed (non-zero exit), bash-timeout, denied (`outsideWorkspace`, `blockedProgram`, `network`), write-failed (file error text), and a `read`/list that stays within `clip` budget for a long result (head + "…N omitted…" + tail).
- [ ] **Step 2: Run → FAIL.
- [ ] **Step 3: Implement** `ToolResult` + `observationFor` (reuse the current `clip` helper).
- [ ] **Step 4: Run → PASS.
- [ ] **Step 5: Commit** `feat(code): tool observations`.

---

### Task 4: Data model — `readFile` / `listDir` action kinds

**Files:**
- Modify: `lib/src/features/code/sessions/code_session.dart`
- Test: `test/features/code/stores_test.dart` (extend)

**Interfaces:**
- Produces (additions to existing `CodeActionKind`): `readFile`, `listDir`.

- [ ] **Step 1: Write the failing tests.** A `CodeAction(kind: CodeActionKind.readFile, path:'a.txt', output:'file text')` round-trips through `toJson`/`fromJson`. A `listDir` action persists its listing in `output`. **Backward compat:** a fixture JSON with `kind:"shell"`/`"writeFile"` still loads. A persisted action left `proposed`/`running` loads as `skipped` (existing behaviour, still true for new kinds).
- [ ] **Step 2: Run → FAIL.
- [ ] **Step 3: Implement** the two enum cases (no new fields; reuse `path`, `output`).
- [ ] **Step 4: Run → PASS.
- [ ] **Step 5: Commit** `feat(code): read/list action kinds`.

---

### Task 5: `CodeToolRunner` (read/list via workspace; write/edit/bash via existing runner)

**Files:**
- Modify: `lib/src/features/code/agent/code_tool_runner.dart`
- Test: `test/features/code/code_agent_test.dart` (add helper) and a new focused `test/features/code/tool_runner_test.dart`

**Interfaces:**
- Consumes: `CodeSessionStore` (`workspaceOf(id)`), `CodeActionRunner` (existing `run(sessionId, CodeAction, onOutput:)`), `CodeSettingsStore`, `CommandEnvironment`.
- Produces:
  - `abstract class CodeToolRunner { CommandEnvironment get environment; bool get allowShell; bool get allowEdit; Future<ToolResult> run(String sessionId, AgentCall call, {void Function(String chunk)? onOutput}); }`
  - `class WorkspaceCodeToolRunner implements CodeToolRunner` — maps `read`→`workspace.readFile`, `list`→`workspace.list` (formatted), `write`/`edit`→`CodeAction.write`/`.edit`, `bash`→`CodeAction.shell`, converting the returned `CodeAction` (status/output/exit/denied/previous/after/truncated/timedOut) into a `ToolResult`. `allowShell = environment != none`, `allowEdit` from settings/budget (default false for local — pass in a flag).

- [ ] **Step 1: Write the failing tests** (hermetic; temp dirs, no network/shell): `read` of an existing file returns its text; `read` of a missing file → `ok:false` with "No such file"; `list` returns entries; `write` creates the file (assert contents on disk); `bash` routed to a **fake** `CodeActionRunner` returns its output; `escape` path (`../x`) → `denied(outsideWorkspace)`; in `CommandEnvironment.none`, `bash` → `ok:false` "Commands cannot run".
- [ ] **Step 2: Run → FAIL.
- [ ] **Step 3: Implement** the interface + `WorkspaceCodeToolRunner`.
- [ ] **Step 4: Run → PASS.
- [ ] **Step 5: Commit** `feat(code): tool runner`.

---

### Task 6: Rewrite the agent loop

**Files:**
- Rewrite: `lib/src/features/code/agent/code_agent.dart`
- Test: rewrite `test/features/code/code_agent_test.dart`

**Interfaces:**
- Consumes: `AgentProtocol.decode/systemPrompt/observationFor/exampleTurns`; `CodeToolRunner`; `CodeModelGateway`; `CodeSessionGrants`; `CodeSettingsStore`; existing `codeNeedsApproval`.
- Produces: `class CodeAgent extends ChangeNotifier` with `phase`, `busy`, `send(text,{attachments})`, `resume()`, `approve(id)`, `approveForSession(id)`, `skip(id)`, `stop()`. Keep `CodeAgentPhase { idle, thinking, awaitingApproval, running }`.
- The constructor takes `CodeToolRunner runner` instead of `CodeActionRunner`.

- [ ] **Step 1: Write the failing tests** (scripted gateway `code_fakes` + fake `CodeToolRunner`; no model, no real shell). Scenarios:
  1. **Happy path:** gateway yields `` ```write a.txt\nhi\n``` ``, runner writes, yields `` ```answer\nDone.\n``` `` → session has a `writeFile` action (status done), an assistant text "Done.", loop idle.
  2. **Read then change:** script a `read` → observation (file text) → `write` → `answer`; assert the observation text was fed to the gateway on the second step (spy on request turns).
  3. **Prose means done:** gateway yields plain "All set." → loop ends, no action card, message shown.
  4. **Malformed recovery:** gateway first yields a nameless `` ```write\nx\n``` `` (malformed) → an appended observation notice → gateway then yields a valid `write` → completes. Assert the notice reached the model.
  5. **Two consecutive malformed ends the request** with `errorCode == 'malformed_action'`.
  6. **Repeat limit:** same `bash` three times → ends with `errorCode == 'repeating'`.
  7. **Step limit:** `maxSteps` reached → `errorCode == 'step_limit'`.
  8. **Approval (acceptEdits):** a `bash` action parks in `awaitingApproval`; `approve(id)` runs it; `skip(id)` records `skipped`.
  9. **Allow in session:** `approveForSession` on `sh ls` then a later `sh ls`/`ls` runs without a second approval; a compound `a && b` is never auto-granted.
  10. **Stop:** `stop()` mid-stream ends with no further gateway call.
- [ ] **Step 2: Run → FAIL.
- [ ] **Step 3: Implement** the loop: build system prompt + example turns (compact model only) + turns; `decode`; on `answer` finish with prose; on malformed append the `notice` observation and retry (count consecutive); on `hasCall` → approval gate (`codeNeedsApproval` via synthesized `CodeAction.shell` for scope) → `runner.run` → `observationFor` appended → continue; keep early stream-cancel once one complete action is present; enforce step/repeat/stop/epoch exactly as the current loop does. Preserve idempotent `historyChars`/append-only behaviour the prefix cache relies on.
- [ ] **Step 4: Run → PASS.
- [ ] **Step 5: Commit** `refactor(code): bounded tool-call agent loop`.

---

### Task 7: Wire the gateways (local agentic sampler; cloud same tagged-block)

**Files:**
- Modify: `lib/src/features/code/providers/gateways.dart`, `providers/code_gateway.dart`, `providers/code_wires.dart`, `providers/provider_client.dart`
- Test: `test/features/code/providers_test.dart` (extend)

**Interfaces:**
- Produces: `LocalCodeGateway.complete` builds the completion with `agentPrompt: true`, `agentStart: ''` (no forced start — removed with small_model_aids), a **tuned** `IntentSamplerProfile` (`PromptIntent.coding` params; grammar field left `null` until Task 14), `maxOutputTokens` per budget; `conversationId` stable per session. Remote gateway unchanged wire (tagged-block), same `system`/`turns`.

- [ ] **Step 1: Write the failing tests.** A `CodeCompletion` from `LocalCodeGateway` sets `agentPrompt` (via the inference entry it would call — assert through a stub `FinnInference`), uses the coding sampler, and carries the `CodeCompletion.system` verbatim. Remote gateway streams through the client as today (recorded-shape test unchanged). Assert `CodeCompletion` gains no `start` usage (forced start gone) or that `start` defaults empty.
- [ ] **Step 2: Run → FAIL.
- [ ] **Step 3: Implement** the gateway changes (thin).
- [ ] **Step 4: Run → PASS.
- [ ] **Step 5: Commit** `feat(code): agentic gateway wiring`.

---

### Task 8: UI — a card per tool kind

**Files:**
- Modify: `lib/src/features/code/ui/code_tool_row.dart`, `ui/code_conversation.dart`, `ui/code_status_line.dart`, `ui/code_suggestions.dart`
- Modify: `lib/l10n/app_en.arb` + the 4 other locales (new strings; run `flutter pub get` after)
- Test: extend `test/features/code/code_ui_test.dart`

**Interfaces:**
- Consumes: `CodeAction` with kinds `shell | writeFile | editFile | readFile | listDir`; assistant text = `answer`.

- [ ] **Step 1: Write the failing widget tests.** Each kind renders its header (icon + label + path/command), shows its result (`readFile`/`listDir` show `output` clipped with an expander; `bash` exit status; `writeFile`/`editFile` diff via existing `code_diff_view`); `answer` is a plain assistant bubble; a new string key `codeRead`/`codeList` exists in all 5 locales (parity test stays green).
- [ ] **Step 2: Run → FAIL.
- [ ] **Step 3: Implement** branching in `code_tool_row`/`code_conversation` by `kind`; add `codeRead`/`codeList` (and any status strings) to all 5 ARBs; run `flutter pub get`.
- [ ] **Step 4: Run → PASS (incl. locale parity).
- [ ] **Step 5: Commit** `feat(code): tool-call transcript UI`.

---

### Task 9: Delete `small_model_aids.dart`; green the suite

**Files:**
- Delete: `lib/src/features/code/agent/small_model_aids.dart`
- Modify: any remaining references (should be none after Task 6 rewrite); delete its tests.

- [ ] **Step 1: Confirm no references** (`grep -rn SmallModelAids lib test` → none).
- [ ] **Step 2: Delete the file and its tests.**
- [ ] **Step 3: Run the full focused suite** `flutter test --no-pub test/features/code/` → all pass; `dart analyze lib/src/features/code test/features/code` clean; `dart format` the changed files.
- [ ] **Step 4: Commit** `refactor(code): remove small-model aids`.

> **Milestone:** FinnAI Code now runs the new harness hermetically with a scripted model. Phases B/C validate and tune it on the real device.

---

### Task 10: On-device baseline — 3B tier

**Files:** none (experiment) — record results in `docs/superpowers/plans/DEVICE_3B.md`.

- [ ] **Step 1: Build + install** `flutter build apk --debug --no-pub` then `adb install -r -t …`; `adb shell am start -n com.abhiflex.finnai/.MainActivity`.
- [ ] **Step 2: Confirm tier** via `adb logcat -s flutter | grep FINN_ENGINE` (expect 3B) and `adb shell run-as com.abhiflex.finnai ls -la files/models/`.
- [ ] **Step 3: Drive the task ladder** in FinnAI Code (create→run, read→change, multi-file, fix-a-bug) via `adb shell input`/`screencap`; capture logs + screenshots.
- [ ] **Step 4: Record** each step: what the model emitted, whether it acted correctly, where it looped/failed. Commit the notes.

---

### Task 11: On-device A/B — pick the local wire format (D1 tagged-block vs D2 +GBNF vs D3 JSON)

**Files:** implement the winner in Task 14.

- [ ] **Step 1: Instrument a minimal probe** (a debug path that sends fixed asks + prints the raw model reply for each decoder variant). Keep it dev-only/removable.
- [ ] **Step 2: Run the same asks on the 3B** for D1, D2 (grammar-constrained: header-forcing GBNF over a non-backtick body), D3 (JSON GBNF). Record: valid-parse rate, correct-tool rate, time-to-first-action, any grammar stalling (`FINN_GRAMMAR_REJECTED`).
- [ ] **Step 3: Choose** the decoder that acts most reliably; record the decision + fallback (spec §"wire format").
- [ ] **Step 4: Commit** the decision note.

---

### Task 12: 1.6B tier — verify + tune

**Files:** constants land in Task 7; tuning recorded here.

- [ ] **Step 1: Build + install** `flutter build apk --debug --no-pub --dart-define=FINN_FORCE_LITE=true`; let the app download the 1.6B artifacts once.
- [ ] **Step 2: Confirm tier** from `FINN_ENGINE` (expect 1.6B).
- [ ] **Step 3: Run the ladder**; tune sampler (temp/repeat-penalty), the prompt example on/off, and per-tier budgets (`CodeBudget`) so the ladder passes. Record final constants.
- [ ] **Step 4: Commit** tuned constants + notes.

---

### Task 13: 3B tier — verify + tune; both tiers pass

- [ ] **Step 1: Rebuild the natural 3B build**, re-run the ladder with the final constants.
- [ ] **Step 2: Confirm both tiers pass create→run and read→change** with observed evidence (logs/screenshots), not inference.
- [ ] **Step 3: Commit** the final tuning + a short `DEVICE_RESULTS.md` with the honest pass/fail per tier per task.

---

### Task 14: Apply the A/B outcome (conditional; only if D2/D3 win)

**Files:** modify `agent/agent_tools.dart` (grammar source), `agent/agent_protocol.dart` (`decode` variant), `providers/gateways.dart` (attach grammar to the sampler).

- [ ] **Step 1: If D2 (grammar) wins:** add the GBNF source constant, attach via `IntentSamplerProfile(grammar: …)` in `LocalCodeGateway`; add hermetic tests that `decode` still reads the constrained output and that a `FINN_GRAMMAR_REJECTED`-style failure degrades to a normal reply. Re-verify on device (both tiers).
- [ ] **Step 2: If D3 (JSON) wins:** swap `decode` to the JSON variant + JSON grammar; same tests + device re-verify.
- [ ] **Step 3: If D1 wins:** no code change; record why.
- [ ] **Step 4: Commit.

---

### Task 15: ADR + docs + full gates

**Files:** `docs/decisions/0014-finnai-code-tool-call-agent.md`; update `features/code/AGENTS.md`, `README.md`, `docs/architecture/CODE_MAP.md`.

- [ ] **Step 1: Write ADR 0014** superseding the text-protocol clause of ADR 0010: decision, rationale (why tool-calls + closed format + repair beat regex aids; grammar usage + tiers), consequences.
- [ ] **Step 2: Update** the code `AGENTS.md` invariants ("agent protocol is plain text on purpose" → the new rule) and `README.md`; update `CODE_MAP.md` for created/deleted/renamed files.
- [ ] **Step 3: Run the full CI gates:** `dart format --output=none --set-exit-if-changed .`; `bash tool/verify_engine_seam.sh`; `bash tool/verify_boundaries.sh`; `flutter analyze`; `flutter test` (full, `--no-pub`).
- [ ] **Step 4: Commit** `docs(code): ADR 0014 + code-map/AGENTS updates`.

---

## Self-Review

- **Spec coverage:** harness+tools+UI (§) → Tasks 1,4–8. Delete aids → 9. Closed protocol + validate/repair + tight prompt + tuning → 1–3,7,12–13. Grammar as tested booster → 11,14. Both tiers → 10–13. Cloud tool-calling → deliberately unified on tagged-block now; native tool-calling noted as an optional follow-on in the spec, deferred to keep one shippable path (recorded in ADR). Backward compat → 4. Docs/gates → 15. No gaps.
- **Step scan:** each step names signatures + the exact assertions; the only bodies left open are collection plumbing the tests pin.
- **Type consistency:** `AgentCall`/`AgentReply`/`ToolResult`/`CodeToolRunner`/`observationFor` names/types are fixed in Tasks 1,3,5 and reused verbatim in 6–8.
- **Review Focus:** items 1–5 map to Tasks 6,5+6,6,5+6,4 respectively (assertions listed in those tasks).
- **Proportion:** code appears as signatures + assertions; device tasks record evidence rather than transcribing output.

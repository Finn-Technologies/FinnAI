# FinnAI Full Rewrite — PLAN.md

> **Status 2026-09-30 (night): the v2 rewrite is under way; the three eval gates now pass.**
> Empty replies 8.6% → **0%**, browse precision **100%**, recall **100%** (Xiaomi, standard
> and forced-Lite policies; [`eval/RESULTS_2026-09-30_v2.md`](eval/RESULTS_2026-09-30_v2.md)).
> The reported "looping on tool calls" and the blank replies had one cause: the base prompt
> advertised browser tools on every turn. Search is now decided by the app (ADR 0001).
> `finn_accelerator.dart` (4,479 → 574 lines) and `home_shell.dart` (5,073 → 578) are split
> into part files; a boundary/size gate runs in CI. **Flows scheduling, the Creations remake,
> the motion system and a real `FinnEngine` interface are not done.** See the v2 entry in
> [§10](#10-progress-log) and `docs/decisions/`.
>
> **Earlier status (superseded).** Owner approved execution of
> Phases 0-2 ("Phase 0 to 2 with subagents and all") and answered §9: release-mode
> perf aggregates approved (no prompt text); Q4_K_M A/B deferred (Q4_0 stays pinned);
> macOS-first order and foreground-only voice confirmed; one polished release after
> full QA; device verification via build + install + screenshot.
>
> **Execution progress is tracked in [§10 Progress log](#10-progress-log) at the
> bottom of this file.** Sections 0-9 below are the approved plan, unchanged except
> where the progress log explicitly supersedes a line. PLAN.md remains the
> cross-session contract (§5): update it per milestone.
> Owner decisions 2026-09-29 (no code changed): (1) Desktop: mobile + macOS first (macOS first for easy testing on this machine; Linux/Windows later). (2) Flows: KEEP visible as Flows; target = MacroDroid-like on-device automations FinnAI can write + user-editable clean flowchart UI. (3) Voice: foreground-only + lifecycle stop, optimize for best experience. (4) Assistant: full Android digital assistant, acts on device. (5) Release: test everything first, ship one polished version (no rushed staged partial). (6) Users: global (Russia, India, any country/action) — multilingual + any-domain eval. (7) Model: stay pinned to lowest-resource / highest speed (Q4_0 class); no up-quant that costs RAM/heat without proof.
> Device check 2026-09-29: Xiaomi `ebe7291` (Android 16, API 36) connected via `flutter devices`; `adb devices` shows `ebe7291 device`. macOS host present. Full device verification in VERIFICATION.md §§1-7.
> Deferred to later per owner: image/multimodal eval prompts (needs sample photo), TalkBack pass, voice-engine install + voice retest (phone has no recognizer/TTS).
> Source: 9 parallel read-only audits (UI, animation, perf/memory, response quality, web search, Flows, voice, architecture/portability, a11y/onboarding/bugs). This file merges and dedups them.

## 0. Verdict: rewrite justified, but keep the good cores

Do not throw everything away. Keep: `lib/src/engine/catalog`, `prompt/*`, `metrics/*`, `policy/*`, `profiler/*`, `chat_generation_controller.dart` (ChatInferenceRuntime interface), `conversation_store.dart` (AES-GCM + refuse-to-overwrite rule), search parser/executor split, `SafeExpression`/creation spec-limits. Rebuild/split: `finn_accelerator.dart` (~4300 lines god-class), `home_shell.dart` (~3300-5000 lines god-widget + owns FinnPageRoute), `inference/` re-export seam (porous — FFI types leak via `finn_engine_types.dart:3`, `finn_accelerator.dart:9`), `main.dart` benchmark/eval harness embedded in prod entry, Flows (mislabeled prompt-snippet manager, not automations), voice orchestration, search dual-stack (`WebSearchService` + `TinyBrowser` with separate clients/caches), onboarding copy + empty states.

Hard constraints carried forward (from AGENTS.md): only `lib/src/engine/**` imports `package:llama_cpp_dart` (`tool/verify_engine_seam.sh`); exactly one shipped mobile model until desktop phase adds picker; never change `downloadUrl`/`expectedBytes`/`sha256Digest` without HF LFS verify (`lfs.oid` == sha256); `lib/l10n/*_generated` edited only via ARB + `flutter pub get`; `dart format` clean; user strings via `L10n`.

## 1. Merged audit issue list (deduplicated, prioritized)

### Critical (fix first or block release) — re-verified by code re-read + device verification on Xiaomi 2026-09-29 (VERIFICATION.md §§6-7). Per-item verdicts below.
1. [CONFIRMED ON DEVICE 2026-09-29, worse than described] Chat bubbles: user bubble white; assistant replies render as bare text with NO bubble at all (`dbg_p2_answer.png`, `dbg_chunk2.png`). Distinction fails. Repro: send any message in light mode.
2. [DOWNGRADED Critical→High; PARTIAL device evidence] Onboarding short-viewport squeeze — `onboarding_flow.dart:411-426` (`bodyMax=max(0, h-(...))` can clamp body toward 0 while card + Next remain). Emulator landscape welcome shows absolute-position fragility (glow card crowds "Swipe to start", `emu_welcome_land.png`). Consent/download-p2 body-clamp still needs a small-phone/landscape shot of a _StepPage (not covered: download auto-starts on emulator, would pull 1.5GB).
3. [CONFIRMED ON DEVICE 2026-09-29] Empty reply: prompt "Reply with only the word blue…" logged `tokens=5 emitted=5` but rendered NOTHING (two screenshots incl. scrolled-up, `dbg_p1_answer.png`/`dbg_p1_top.png`). Batch empty-visible rate 2/21. NEW companion bug: reply "blue" (2 tok) appeared only AFTER the next user message — message-ordering race. Think-guard + ordering fix both required.
4. [CONFIRMED ON DEVICE end-to-end] Consent skip opts IN: tapped Next with neither Yes/No selected → advanced to Finish; no `context_consent.json` written; Settings → On-device context toggle ON (`dbg_settings4.png`). Privacy bug reproduced exactly as audited.
5. [CONFIRMED ON DEVICE visually; TalkBack DEFERRED] Welcome swipe-only, zero button (`dbg_onboard_welcome.png`; drag-only `_SwipeAdvance`, `NeverScrollableScrollPhysics`). Owner runs the TalkBack pass later.
6. [CONFIRMED ON DEVICE] Serial upfront search + spurious browsing: `route≈3070ms` hits on capital-of-France (reps 1-2), math, planet, bike-tire, web-current; "What did you reply above? Say it again." searched the web + Wikipedia +2 + photo (`dbg_p2_answer.png`); static facts carry "Searched the web" disclosures every time. TTFT 5-9.6s for 2-token answers.
7. [CONFIRMED ON DEVICE] Decision-prefill TTFT tax: 21-prompt batch TTFT 1.0-9.8s, `prompt_eval` 1-7s dominates; decode steady 15-17.6 tok/s; `session_hit=false` on early turns incl. 2nd turn of conv1 and Paris reps 1-2 (session reuse inconsistent). Baseline table in VERIFICATION.md §6.
8. [CONFIRMED ON DEVICE effects] Contradictory format rules bite: "Júpiter" (language leak from prior Spanish prompt), 5-word summary echoed input in 8 words, train answer correct (180 km) but verbose vs "only number and unit". Multilingual non-Latin evaluation DEFERRED (ADB cannot send non-ASCII; needs hand-typed prompts or harness).
9. [Unchanged, code-level; session_hit pattern observed] Per-intent task instruction not in session identity (`finn_accelerator.dart:3485-3491` vs `:1569-1570`); device batch showed `session_hit=false→true` flapping across identical repeats. Covered by Phase 1 history/session fix.
10. [Unchanged, code-level; behavior consistent with it] Decision prompt drops history (`renderDecisionPromptText` never renders `history`, `prompt_formatter.dart:141-170`); follow-up "And what did I ask first?" browsed instead of using history. Covered by Phase 1 history-aware decision.

### High
- Response quality systematic drivers:
  - Giant stacked system prompt (~450-word safety + 5-7 blocks/turn, contradictory concise-vs-magazine instructions) `prompt_formatter.dart:16-59,218-327`. 1.6B cannot arbitrate; expect terse-vs-overformatted variance.
  - Per-intent task instruction not in session hash; intent switch appends conflicting instruction over resident KV (`prompt_intent.dart:619-665`, `finn_accelerator.dart:3482-3495,1569-1570`).
  - Decision prompt drops history (dead `history` param) `prompt_formatter.dart:130-172` → follow-ups misroute ANSWER vs browse.
  - Sampler `temp 0.30/topK30/topP0.90/minP0.05` + fresh random seed every turn (`prompt_intent.dart:584-617`, `finn_accelerator.dart:26-35,1245-1249,1823-1826`) = non-deterministic factual answers. No deterministic factual profile. Dead `FinnEngineConfig` sampling fields (`finn_engine_config.dart:48-52`) mislead tuners.
  - Grammar-off decision + over-accepting parser (`SEARCH:`, bare JSON, `browser_search()`) → spurious browsing (`prompt_intent.dart:530-556`, `finn_accelerator.dart:1257-1259`, `search_agent.dart:90-232`).
  - Token accounting `len/3` heuristic, drops date/tool/doc/image tokens; 65% cap starves history on 2048 ctx (`prompt_formatter.dart:368-400`). Front-truncation can drop question keep answer.
  - Post-tool continuation omits question/history, depends on KV; no-tool path `session.clear()` + re-render — same turn two shapes (`finn_accelerator.dart:1700-1756`).
  - Continue/regen/edit drop image bytes (`home_shell.dart:812-833` vs `:923-927,978-982,1018-1022`); continuation capped at 1 (`:905-908`); regen re-searches inconsistently.
  - Template: no `<|startoftext|>` in Dart (BOS via `addSpecial`, untested vs GGUF tokenizer); custom `<tool_call>`/`<tool_response>` alien to LFM2.5 native tools; `<__media__>` vs `<image>` correct only if vendored mapping holds — no pinning test.
  - Q4_0 coarsest 4-bit on 1.6B + 854MB F16 projector larger than 696MB LLM (`model_catalog.dart:56-82`); 2048 vs 4096 ctx by device class = same prompt different quality.
  - Truncation silent: history front-drop, doc 4000ch, snippet 350x3/page 600/open 2200, output bound `ctx-96` (1952/4000 = 7-13min runaway at 5-10 tok/s), tool-block `flush()==''` vanishes.
  - Dual grounding paths (freshness→upfront 3s single-shot; >900ch/advanced-keyword→agentic loop) + double-wrapped instructions + thin lossy excerpts + no-JS + unbounded `TinyBrowser` cache.
  - VL: only newest image sent (cap-4 dead), mmproj size-only load gate vs SHA install gate + re-hash 854MB with no memo every startup path, HEIC skipped, doc-by-extension garbles PDFs, media disables context-shift → overflow wipes sessions.
- Perf/memory:
  - `_token()` O(n²): `responseText.toString()` per token + full-string compare + markdown re-parse (`chat_generation_controller.dart:602-633`).
  - `FINN_PERF/TTFT/PREFIX` gated `!kReleaseMode` — prod blind (`finn_accelerator.dart:1836-1842`, `ttft_metrics.dart:137-151`).
  - 2.2GB min-RAM tight for 1.55GB artifacts + 4096 f16 KV (`device_profile.dart:24,42-46`).
  - Background generation 10s retry loop burns CPU screen-off (`home_shell.dart:389-428`); no metered-network guard for 1.5GB download; controller `dispose()` never stops native generation; legacy HttpClient not in cancel set (desktop).
  - Bootstrap blocks first frame on `DeviceProfiler.read()` sysfs loop + file IO (`bootstrap.dart:28-41`, `device_profile.dart:131-179`).
  - Streaming markdown re-parse full text ≤20Hz/60Hz (`chat_generation_controller.dart:901`, `safe_markdown_text.dart:44,109`); overlapping 320ms `animateTo` while tokens stream; `FluxDisclosure` per-frame setState+jumpTo; sidebar full-layer clip+shadow+blur per frame; voice orb `AnimatedContainer` restarted at audio-callback rate via full-page `ListenableBuilder`; animated fullscreen blur 18-28px.
- Web search stage detail: hedged fallbacks sequential (DDG API deprecated empty → Wiki full-text → DDG-lite → thumbnail RTT 1500ms off-critical-path work on-path); `browser.open` downloads full MBs HTML then DOM-parses on main isolate then truncates 2200→fed to context bloat; per-turn `http.Client` churn + TLS, never closed; caches non-cooperating (LRU 30/15m vs unbounded no-TTL, different keys); query stripper duplicated/lossy; continuation 8s budget.
- Flows: not automations — `{name,desc,instructions≤500ch,category,enabled}` + keyword-substring gate (`.take(4)`) injected as system text. No triggers/steps/tools-per-flow/scheduling/background/run-button/logs/observability (`flows_store.dart:25-81,280-337`, `flows_page.dart`, `home_shell.dart:743-746`). Device actions (15 fixed intents via `FinnDeviceActionsBridge.kt`) disconnected from Flows; engine tool loop browser-only; no `workmanager/alarm/notifications` deps; background policy actively unloads model. Rename residue Skills↔Flows in CODE_MAP/I18N, no FLOWS.md.
- Voice: no explicit mic permission request (relies on plugin side-effect); BT disabled silently; default `listenFor/pauseFor/locale` (OEM variance); sentence-chunk TTS `rate 0.45` speaks code/markdown literally, silent until first `.?!`; tap-only interrupt (no barge-in/VAD); background leaves STT/TTS running + stale state (no reset in `didChangeAppLifecycleState`/`dispose`); OHOS no `MICROPHONE` perm + `voiceSupportedOnPlatform=Android||iOS` only; `voiceDidNotCatch` translated but dead; errors binary micDenied/unavailable, no Retry/Settings link.
- A11y/onboarding/bugs: 50%-alpha 20px body ~2.3-3.2:1 fails AA (needs 4.5:1); link `#5D75FF` 3.9:1; reply actions 40px <48, chips ~32px; no textScaler/highContrast handling; download trap (no skip/pause/cancel, back disabled, `pauseDownload()` unwired); ETA `m:ss + "minutes remaining."` (“0:05 minutes”); empty chat dead-end (10 suggestion strings dead, no chips); upgrade auto-dismiss 450ms; single corrupt message wipes visible history (`ConversationMessage.fromJson byName/parse` throw → latch empty); storage-error latch permanent + ENOSPC misclassified as model failure; non-Android no pre-flight storage check; backgrounded inference leaves stale generating bubble; archived activation orphans on fault-back fail; Settings spinner forever on `inspectModels` throw; startup-resume vs onboarding-start race → spurious “Another download”; send-path 12s store timeout proceeds broken.
- Architecture: seam porous (FFI types leak, no `FinnEngine` abstract, no `llama_backend.dart`, ROADMAP Q1 unexecuted); single-tier catalog + 2048/4096 ctx + CPU pin + `sessionCacheEntries:1` block larger desktop models; singletons everywhere (`FinnAccelerator/AppState/Conversation/Creation/ChatController`) — multi-window unsafe; `secure_storage/STT/TTS/pickers` Android/iOS-only; OHOS `GeneratedPluginRegistrant.ets registerWith()` empty → MissingPluginException except hand-rolled path_provider; iOS template-only; no `macos/windows/linux/`; `analysis_options` excludes native; `main.dart` prod+harness coupling + `/sdcard` hard paths; test gaps: accelerator core, residency/TTFT/eval assessors, onboarding flow, home_shell send/stop/attach/browse, creations controller/store/export, actions executor, voice sheet/settings, OHOS degradation, desktop matrix.
- Visual/UI (mom-test): dead privacy link (no-op when `hasPrivacyPolicyUrl==false`, `onboarding_flow.dart:733-739`); consent unanswerable (“get context on your device?” no examples); “Downloading the core, please standby.” typo/jargon; privacy lead grammar+duplication + “every request locally” contradicts search; 4 precaution strings dead/orphaned; `onboardingProgressEtaTail`; internal `LFM2.5-VL 1.6B`/`mmproj` exposed; Ready repeats 3x; download dialog fragment; brand `Finn AI` vs `FinnAI`; title==body 20px only-alpha hierarchy; report 11px/hint 10px; section 11px uppercase `toUpperCase()` (tr/i18n break); artwork 24px white over 35% wash; markdown serif H1 alien; 10px labels; hardcoded `Color(0xFF…)` ×52 bypass theme; `AmbientBackground` dead vs chat green wash; amber pill 2.15:1; goldens only 390x844 light onboarding skeleton (no dark/small/tablet/chat); sidebar stagger overlap; composer 220px + listening 40px gap; creations 40px gap/badge off-screen; deck dots overflow + notes maxLines 3; header 0.96-alpha ghost; gutter jump at 380px + FAB overlap.
- Animation inconsistency: 3 page motions (FinnPageRoute slide-x vs _blurRoute slide-y vs _enterHome fade, same durations different curves) + MaterialPageRoute zoom on wipe + 3 modal motions; per-message controllers burst on history open; entrance translates full CustomScrollView; infinite tickers while off-stage.

### Medium/Low (condensed)
Jargon ARB (`llama.cpp·GGUF`, `LFM2.5-VL 1.6B`, `multimodal component`, `artifact`, `Purge/RAM`, `FINN_PRIVACY_POLICY_URL` leak); split sentences/ETA-tail/`{received} of {total}` break DE/JA order; `hintMaxLines:1` clips; FigmaSvg vs FluxIcons mix; dark pastel harsh; offline/history notices no retry + jargon “cited sources”; verification errors undifferentiated; report disabled when unconfigured; switch/FAB platform inconsistency; image fallback cryptic; web image `errorBuilder shrink` silent drop; `FilePicker` full-res bytes 2x RAM + doc `readAsString` full-then-truncate 4000; history copied 2x/turn; prefix-state dir list+delete per miss; download progress 2-7Hz broad notify; sidebar `_conversationChanged setState{}` on any store notify; encryption `compute` main-fallback; SHA-after-download re-streams 700MB+; heavy plugin set cost; `MainActivity.onTrimMemory` level ignored; `handleMemoryPressure` serial no-timeout; prewarm 450ms always on balanced+; `needsBenchmark` file+profile per start; unload-after-spawn waste; `_outputBudget` unbounded runaway; `promptTokenCount /3.2` estimate; `prewarmTier` double-gate; `prompt_eval_ms` conflates + multi-round under-reports; `FinnAccelerator` singleton never disposed + single-slot `onToolActivity`; `_unload` serial chain; `_verifiedModels` memo but no mmproj memo; pressure-during-generation ignored except imageCache clear.

## 2. Model evaluation plan (broad, not task-specific)

Do not scope to recipes. Phases: (a) record baseline on Xiaomi SD778G with pinned `LFM2.5-VL-1.6B-Q4_0 + mmproj-F16` before any change; (b) every change measured before/after; (c) honest weak-spot report drives product limits.

- Suite A — Public on-device-runnable benches (subset, offline where possible): MMLU-style factual, GSM8K-style math (vs `LocalArithmetic` oracle), instruction-following (IFEval-style shape/language checks), long-context recall (multi-turn retention at 2048 vs 4096), OCR/doc-QA (chart/screenshot/photo/handwriting).
- Suite B — Custom prompt set: multilingual (≥12 langs incl. Hindi, Arabic, Chinese, Tamil/Malayalam, Turkish, German, French, Spanish, Swahili + non-Latin scripts; morphology + code-switch) — NON-LATIN DEVICE RUNS DEFERRED (ADB cannot send non-ASCII; needs hand-typed prompts or harness); multimodal (OCR, charts, screenshots, real-object photos, doc-after-photo, HEIC rejection path, multi-image single-image-limit doc) — DEVICE RUNS DEFERRED (needs sample photo); reasoning/math/format/long-recall; tool/function-call validity (schema-valid first-try %, bare-JSON %, repeat-call %, truncated %); safety/refusal precision (allow cooking/hardware/household vs refuse disallowed; over-refusal metric — phishing refusal + bike-tire answer already baselined on device 2026-09-29) + hallucination factual set; everyday non-technical (recipes, writing, translation, health/finance with safe-completion + disclaimer, homework, planning); adversarial-unusual (nonsense, jailbreak, empty, huge paste, mixed-language, emoji-only).
- Suite C — Determinism/self-consistency: same factual prompt ×5 at shipped sampler vs greedy temp-0; exact/semantic/numeric match rates. Gates sampler fix.
- Suite D — Browse precision/recall (needs-web vs must-not: greeting/recipe/translation/creative/coding) incl. follow-up turns; grounded faithfulness + citation P/R + bare-[1]/dump/verbatim rates; latency-quality tradeoff (TTFT, tok/s, browse time vs quality by 2048/4096 class).
- Suite E — Template conformance goldens vs HF `chat_template.jinja` for pinned GGUF (BOS, role order, tool role, `<image>`/`<__media__>`, empty-think prime, `nKeep:321` drift); sampler sweep grid (temp/topP/topK/minP) factual vs creative; truncation accounting (tokenLimit %, continuation success after cap removal, empty-reply %).
- Harness: extract from `main.dart:293-301` into `tool/` + `lib/src/engine/eval/harness.dart`; seeded eval mode; store baselines in repo (`eval/baseline_*.json`); fail CI on quality regression. Extend existing `evaluation.dart:52-164` seeds (ricotta cake, laptop RAM) beyond 2 cases.
- Model/runtime/quant assessment (explicit, pinned low-resource per owner): Q4_0 stays default; any Q4_K_M/Q5_K_M or projector change needs measured proof it keeps SD778G speed/RAM/heat; survey current LiquidAI LFM2.5 family + alternatives for this device class (e.g. small VL vs text-only + separate OCR) and runtimes (llama.cpp pin vs update; GPU/Vulkan on desktop only — keep CPU-pinned Android per `finn_accelerator.dart optimizeForDevice` comment). Decision only after measured baseline; report where 1.6B weak (factual consistency, long-context, multi-step orchestration, non-English morphology, tables/PDF/JS pages) and design product around limits (shorter answers, cite-or-say-unknown, no multi-image promises, no background agents on 3GB devices).

## 3. Product vision (recommendation + reason each)

1. UI cleanup + coherent design system, still mom-simple. Reason: current theme exists (`FluxTheme/Colors/Radius/Controls`) but bypassed by 52 hardcodes, identical bubbles, 10px text, dead empty states. System: semantic tokens (light+dark variants for link/amber/blue/bubble), 12px min, 48px targets, one page motion + one modal motion, empty-state CTAs (suggestion chips from dead ARB `suggestion*`), plain-language ARB rewrite (hide `LFM2.5-VL/multimodal/artifact/GGUF`), goldens for dark/small/tablet/chat/settings. Keep single primary action per screen.
2. Flows as real on-device automations (KEEP visible). Reason: owner wants MacroDroid-class value, not hidden. Design: `FinnFlow{trigger:{manual|time|cron|event}, steps:[{prompt|deviceAction|browser|notify}], inputs, maxRounds, requiresConfirmation}` + `FlowRunner` outside `engine/` via `inference/` facade + `workmanager/alarm/notifications` + run history + chat badge `via Flow X` + clean flowchart editor (nodes/edges, FinnAI-generates-flow + user edits). Manual Run first, scheduled second. Safety: per-flow standing grant, confirmation tiers reuse (`open` vs `execute`), no silent execute. Global triggers (timezones/locales) per owner.
3. Voice end-to-end (foreground-only per owner, best experience). Reason: STT/TTS present but mutually exclusive tap-only, speaks code, no lifecycle handling. Design: speakable-text sanitizer, `pauseFor/listenFor` tuning + first-audio metric, lifecycle `reset()` on pause (no background mic service), permission rationale + Settings deep-link + offline-pack hint, rate/voice picker, wire dead `voiceDidNotCatch` + Retry. No barge-in VAD in v1; tap-to-interrupt polished. OHOS: document unsupported or add perm later.
4. System assistant (Android, full digital-assistant per owner). Reason: act on device from outside app. Mechanisms: Assist role (`VoiceInteractionService`/`AssistContent`) vs AccessibilityService vs share/process-text (already have `process_text` channel) vs App Shortcuts/intents. Recommend: phase 1 share/process-text + widget (already partly there) and explicit in-app confirm cards; phase 2 Assist role for voice invocation with foreground confirmation for sensitive actions (dial/SMS/email/alarm/torch/media/volume/open_app only from `action_catalog.dart` allowlist; never wireless-settings/system writes silently). Permissions: RECORD_AUDIO + foreground-mic if background; safety: allowlist + per-action grant + audit log + “confirm before sensitive” cards. AccessibilityService only if tap-automation explicitly approved (abuse/malware optics + Play policy).
5. Desktop (mobile + macOS first per owner; Linux/Windows later) without another rewrite. Reason: macOS testable on this machine; headroom for larger models later but mobile stays lowest-resource pinned. Architecture: `FinnEngine` abstract in `engine/api/` + `backends/llama_backend.dart` (execute ROADMAP Q1), constructor-injected (kill singletons for multi-window), per-model `{nCtx, KV type, GPU layers, threads/batch}` config, `libraryPath` per-OS (Metal/CUDA/Vulkan), Keychain/Credential/libsecret shim for `secure_storage`, desktop pickers/TTS/STT gating, `getApplicationSupportDirectory`-relative bench paths, scaffold `linux/` first (closest to current Linux-only `optimizeForDevice` + `/proc`), then macOS Metal, then Windows. Catalog evolves `single→registry` with mobile pinned to one entry.
6. Desktop Cowork agent (local Liquid models). Reason: fits private-local story, desktop RAM/GPU allow 7B+ + 16-32K ctx. Design: same tool/agent layer as Flows/assistant (unified registry: `browser.*`, `device.*`→`desktop.*` (file read/write/apply-patch, shell allowlist, app open)), grammar-constrained decoding (re-enable once llama pin supports), step budget + patch-preview + undo, file-scoped permissions. Powered by larger LiquidAI text model on desktop; mobile stays 1.6B.
7. Other mom-fit features: offline-first “Try asking” chips; download with skip/pause + storage pre-check all platforms + metered guard; “Free up memory” rename; image part auto-install note fix; low-storage/ENOSPC plain errors; large-font/high-contrast pass; share-to-Finn + home-screen widget (already scaffolded) over new gimmicks. Non-goals: NPU probing on Android, analytics/crashlytics (keep absent for battery/privacy).

## 4. Rewrite plan — phases, keep-vs-rebuild, deps, risks, effort

Effort scale: S ≤1wk, M 2-4wk, L 1-3mo (single senior Flutter + device time; parallel tracks need +1 eng each).

- Phase 0 — Baselines + harness extraction (M; partly DONE 2026-09-29: 21-prompt TTFT/tok/s table, cold load ~5s / warm restore 45-90ms, RAM empty 2.54GB → 3.73GB after 20 turns, 1.55GB download ~3.5min — see VERIFICATION.md §6). Remaining: extract bench/eval from `main.dart` → `tool/`; commit numbers to `eval/baseline_*.json`; add release-mode `FINN_PERF` sampling; investigate RAM growth (leak vs caches). HarmonyOS: paused (no device, no work; only note gaps). Definition of done: reproducible `tool/eval --baseline` runs on Xiaomi + numbers committed + harness out of `main.dart`. Cut line if short on time: drop release-mode logging, keep baselines. Risk: bench flakiness → pin governor, airplane-aware runs.
- Phase 1 — Core app + response quality (L). Split accelerator (download/loader/session/tool-loop/metrics) behind `FinnEngine` abstract; deterministic factual sampler + seeded eval; history-aware decision; single grounding format + stop browsing static facts/follow-ups (device-proven waste); temp-0 grammar-on decision; think-guard + message-ordering race fix (both device-confirmed); attachment-preserving continue/regen + cap removal with `prompt+max≤nCtx-margin`; delete orphaned `.finn_repack` in `remove*` paths (device+code confirmed ~693MB orphan); Q4_K_M measure-only A/B (stays Q4_0 pinned unless proof, per owner); fix O(n²) token path + markdown throttle; release TTFT logging. Keep catalog/prompt/metrics/profiler/policy. HarmonyOS: degraded — keep CPU-path compiling, no ETS/feature work; document STT/TTS/picker gaps. Definition of done: self-consistency + grounded faithfulness + empty-reply % improve vs baseline with TTFT/tok/s not regressed; seam script passes; eval deltas in PR. Cut line: defer grammar-on decision and Q4_K_M A/B; keep sampler + think-guard + history-aware decision + O(n²) fix.
- Phase 2 — Design system + onboarding/a11y (M). Tokens, bubble distinction (assistant has no bubble at all on device), 12px/48px, one motion language, plain ARB, consent explicit (device-proven opt-in bug), skip/pause download, empty-state chips, dark/small/tablet goldens INCLUDING dark sidebar white-tile + glowing voice FAB + dark user-bubble contrast (all device-confirmed §7), Semantics/liveRegions, contrast, ETA fix. TalkBack full pass DEFERRED (owner does it later); code-level Semantics fixes still in scope. HarmonyOS: supported for UI-only (goldens + ARB + layout pass apply cross-platform; no native work). Definition of done: golden suite (light+dark × phone/small/tablet/landscape) green + TalkBack onboarding→chat pass on Xiaomi + consent skip blocked + mom-test checklist (§8) recorded. Cut line: defer tablet goldens and motion-language unification; keep bubbles, consent, download skip/pause, contrast, phone goldens.
- Phase 3 — Search speed (M, after Phase 1 engine split). Single facade + shared keep-alive client + shared LRU; overlap net ∥ model load; hedge Wiki∥DDG-lite, drop Instant-Answer primary, thumbnail off-path; byte-capped streaming parse off-main; 1 decision round default, budget 12s→6s, no `clear()` on unprimed ANSWER; unified turn budget. HarmonyOS: degraded — pure-Dart path only, no foreground-service parity. Definition of done: grounded p50/p95 faster than baseline V6/V7 stage breakdown with quality held; empty-result fast-fail ~2s. Cut line: defer parse-off-main and hedging; keep single facade + shared cache + overlap + budget cut.
- Phase 4 — Flows runner + unified tool registry (L, after Phase 1+3). KEEP visible per owner; model/trigger/steps (flowchart editor, FinnAI-generates + user edits)/scheduler/notifications/run-log; generalize directive+parser+grammar+filters; Manual Run → scheduled. HarmonyOS: paused — no scheduler/service port; data model + manual-run UI must not break OHOS build. Definition of done: create→Run→history+badge on Xiaomi; one scheduled alarm-driven run; no silent execute without grant. Cut line: defer scheduled triggers and flowchart editor polish; keep data model v2 + Manual Run + run history + registry.
- Phase 5 — Voice complete, foreground-only (M, after Phase 1). Sanitizer, timings, lifecycle `reset()` on pause (no background mic service per owner), permission UX, customization, tap-interrupt polish (no VAD barge-in v1). Code work proceeds; DEVICE RETEST DEFERRED until owner installs a recognition service + TTS engine (phone has neither — VERIFICATION.md §6). HarmonyOS: paused — voice stays Android-gated (`voiceSupportedOnPlatform`), documented unsupported. Definition of done: STT/TTS/latency/interrupt/foreground-background matrix green on Xiaomi (§6 checklist) + dead `voiceDidNotCatch` wired + first-audio metric. Cut line: defer voice/rate picker and offline-pack hint; keep sanitizer + lifecycle reset + permission UX + metrics.
- Phase 6 — System assistant (L, after Phase 4+5). Share/process-text + widget hardening → Assist role; allowlist + confirm cards + audit log. HarmonyOS: paused (Android-only). Definition of done: invoke outside app → allowlisted action with confirmation on Xiaomi; Play-policy review recorded. Cut line: defer Assist role; keep share/process-text + widget + confirm cards (nice-to-have: full voice invocation).
- Phase 7 — Desktop macOS + Cowork (XL, after Phase 1 seam; Linux/Windows later per owner). `FinnEngine` backends, per-model config, native builds, secure-storage shims, scaffold macOS first (testable on this machine), larger-model picker, desktop agent tools. HarmonyOS: unaffected/paused. Definition of done: same Dart features run on macOS + one larger local model with 16K ctx; no mobile regression. Cut line: defer Cowork agent tools and larger-model picker; keep macOS build + engine backend + storage shim (nice-to-have: Cowork file/shell tools).
- Keep vs rebuild recap: keep listed cores; rebuild home_shell split (shell/sidebar/composer/bubbles/attachments/voice/device/report), inference seam (abstract not re-export), main harness, Flows, voice controller/sheet, search stacks, onboarding copy/states.
- Risks: 1.6B ceiling (mitigate: design around limits, deterministic factual path, cite-or-unknown); llama pin upgrade breaks `<__media__>`/grammar (pin + conformance goldens); OHOS plugin gap (ETS + HUKS); Play policy for assistant/accessibility/background; 1.5GB→multi-GB downloads (resume/chunk tuning); heat/battery on SD778G (budgets + prewarm gating).

### Phase ranking by user impact per effort (highest first)
1. Phase 1 (core quality) — fixes inconsistent answers + empty replies + TTFT tax. Impact highest, effort L. Not skippable.
2. Phase 2 (design/onboarding/a11y) — fixes bubbles, consent privacy bug, swipe trap, download trap. Impact very high, effort M.
3. Phase 3 (search speed) — fixes slowest everyday path. Impact high, effort M.
4. Phase 0 (baselines) — unlocks measurement; no user-visible change alone. Effort M, prerequisite.
5. Phase 5 (voice foreground) — completes half-built feature. Impact medium-high, effort M.
6. Phase 4 (Flows runner) — turns misleading section into real value. Impact medium-high, effort L.
7. Phase 6 (assistant) — nice-to-have until 1-5 solid. Impact medium, effort L, policy risk.
8. Phase 7 (macOS + Cowork) — nice-to-have for mobile users; strategic for desktop. Impact low (mobile) / high (desktop), effort XL.

### What could make this plan wrong (assumptions + how Phase 0 tests each)
1. "1.6B Q4_0 is good enough with better prompting/sampling." VALIDATED directionally 2026-09-29: static facts answer correctly (Paris 5/5, primes, translation) but need determinism + no-browse fixes; open QA stays cite-or-unknown.
2. "TTFT/tok/s are dominated by decision-prefill + double-search, not weights." CONFIRMED 2026-09-29: prompt_eval 1-7s + route ~3s dominate; decode steady 15-17.6 tok/s. Search/routing fixes will move TTFT.
3. "Empty replies come from think-swallowing." CONFIRMED on device (5 tokens emitted, nothing rendered) + ordering race found. Both get fixes in Phase 1.
4. "Q4_0 pinned is the right ceiling for SD778G." Unchanged: Q4_K_M measure-only A/B stays in Phase 1; non-Latin device runs deferred.
5. "Single shared search facade + overlap fixes perceived speed." Test: upfront-vs-engine overlap timing + cache-hit rate; if network variance dominates (DDG/Wiki on mobile radio), need timeout/budget cuts, not architecture.
6. "Rewrite beats patching home_shell/accelerator in place." Test: Phase 0 split-spike time-box; if seam split explodes callers (FFI leak wider than mapped), fall back to staged extraction behind facade.
7. "macOS-first desktop shares the engine seam." Test: Phase 0 loader audit (`libraryPath`, Metal backend, secure-storage shim gaps); if native port dominates, macOS slips behind mobile phases.

## 5. Workstreams, parallelism, merge/verify (no shared files)

- Parallel-safe (separate branches/worktrees, disjoint file sets): (a) eval/harness + baselines (`tool/`, `eval/`, `lib/src/engine/eval/`); (b) design-system tokens/goldens/ARB (`lib/src/shared/`, `lib/l10n/*.arb`, `test/goldens/`, `test/*golden*`); (c) search facade internals (`lib/src/features/search/`, engine `tool_loop` only via reviewed interface); (d) voice (`lib/src/features/voice/`, manifest mic parts); (e) Flows runner new files (`lib/src/features/flows/runner/*`, `tool_registry/*`) without touching chat UI until integration milestone.
- Sequential (shared files, one owner at a time): engine seam split (`finn_accelerator.dart`, `finn_engine*.dart`, `inference/*`) → chat controller/shell split (`chat_generation_controller.dart`, `home_shell.dart`) → onboarding/a11y → integration (badges, confirm cards, run history UI). Never two agents in `finn_accelerator.dart` or `home_shell.dart` concurrently; split first, then parallelize per-file.
- Merge/verify per milestone: feature branch → `dart format` + `verify_engine_seam.sh` + `flutter analyze --no-pub` (OHOS fork note) + `flutter test --no-pub` + focused goldens → Xiaomi install (`flutter build apk --debug`, `adb install -r -t`, `am start`, `adb logcat -s flutter | grep FINN_`) + screenshots/numbers attached. No “works” without tests + screenshots + bench numbers. `PLAN.md` is the cross-session contract; update it per milestone.

## 6. Testing & QA strategy

- Unit: sampler/intent/formatter/filters/arithmetic/device-profile/adaptive/KV-memo/download-recovery/parser/matcher + new runner/registry/sanitizer/trigger matching.
- Widget: composer/sheet/error/consent/download/empty/run-history/confirm-card (explicit consent, skip/pause, retry, liveRegion).
- Golden: light+dark × 390x844, 360x740 small, 768x1024 tablet, landscape onboarding, chat/composer/sidebar/settings/creations/flows/voice error; keep `test/flutter_test_config.dart` at root, 2.5% drift review.
- Integration: send→grounded→cite, interrupt/regen/continue w/ image, corrupt-history quarantine, disk-full ENOSPC copy, background mid-stream mark-interrupted, upgrade migrate, scheduled flow fire, assistant outside-app confirm.
- Perf suite (SD778G targets — confirm in Phase 0 baseline, do not invent pass): cold start to interactive, model load, TTFT (short factual / grounded / VL), tok/s sustained, RAM peak (2048 vs 4096 class), download+verify throughput, search stage breakdown (decision-prefill vs net vs open vs parse), voice first-audio latency, heat (skin-temp proxy + throttle events). Targets set from measured baseline ±10-20% regression gates; publish numbers per milestone. Missing tooling (thermal API, GPU counters) → say so, use logcat + `dumpsys meminfo/battery` + manual feel log.
- Model eval: §2 suites with before/after deltas in PR description.
- Manual QA checklist: fresh install (grant/deny perm), consent skip blocked, download fail/resume/pause/skip, airplane grounded + ungrounded, corrupt history file, 1GB-free device, background/kill mid-generation, 200% font, TalkBack full onboarding→chat→voice, landscape/foldable/small, OHOS smoke (degraded plugins), Play upgrade over prod data.

## 7. Release safety (live on Play)

Same `applicationId` + signing key; versionCode bump; `versionCode` gate 16KB alignment via `tool/verify_release.sh`. Owner wants one polished release after full QA (no rushed partial): still use internal → closed → small staged halt-check before full push so rollback stays possible. Migration: `flows.json v1→v2`, conversations enc + KeyStore key reuse (never delete on key-missing — keep `_storageError` refuse-to-overwrite rule), settings/stores, models: keep `fileName` identity; add old names to `_retiredModelFiles` only after verify; interrupted-download resume. Staged rollout (internal → closed → 10% → 50% → 100% with TTFT/crash/empty-reply/ANR gates), server-side kill/hold (staged halt, no client flag needed), rollback: halt rollout + hotfix or prior AAB republish (same key, higher versionCode); data forward-compatible (no destructive migration). Pre-release: `release_hardening_test.dart` (URL/digest), `test/shell/test_cleanup.sh`, signed AAB + alignment gate green.

## 8. Real-user testing (non-technical, e.g. first-run with local-AI novice)

Observe, don’t coach: can they start (no swipe trap), explain consent in own words, predict download size/time, recover from fail (retry/skip), ask first question unaided (chips help?), distinguish Finn vs user bubbles, interrupt voice, understand offline notice + citations, complete “find recipe / translate / photo question” without jargon, report confusion verbatim. Record: task success, time-to-first-success, taps-to-send, mis-tap rate, comprehension quotes, trust moments (ETA, errors, citations). Include ≥1 low-vision/large-font + ≥1 TalkBack session. No PII retained; on-device logs only with consent.

## 9. Remaining decisions (short questions + recommended answer)

1. May Phase 0 add privacy-safe release-mode perf aggregates (no prompt text)? Recommended: yes — else prod stays blind.
2. May Q4_K_M run as measure-only A/B on Xiaomi (default stays Q4_0)? Recommended: yes, measure only.
3. Confirm macOS-first desktop order (Linux/Windows later)? Recommended: yes per your call.
4. Confirm foreground-only voice, no background mic service (device retest after you install recognizer+TTS)? Recommended: yes per your call.
5. Confirm one polished release after full QA (with small halt-check before full push)? Recommended: yes.
6. Real-user sessions: how many + which locales (e.g. Hindi/Russian) for first mom-test round? Recommended: 3-5 sessions, ≥1 non-English.
7. Eval quality bar to ship (e.g. empty-reply % < X, grounded faithfulness delta)? Recommended: set numeric bar from Phase 0 baseline.
8. Image eval: attach 2 photos yourself or say "push a chart" for me to drive the picker? Recommended: your 2 photos (real + text) when ready — deferred, non-blocking.

---

## 10. Progress log

Append-only. Newest milestone first. Every entry states what is **verified** (tests
run, with counts) versus **unverified** (built, on a device, awaiting a run). A
milestone is only "done" when it has been merged into `main` with a green gate
(`dart format` + `verify_engine_seam.sh` + `flutter analyze --no-pub` +
`flutter test --no-pub`) and, where it claims a behaviour change, device evidence.

### 2026-10-02 — Reply-prompt A/B: shorter-by-default reverted

Six interleaved full-suite eval runs on the Xiaomi (NEW x3: 0.594/0.781/0.563;
OLD x3: 0.656/0.750/0.719; 34 cases each, every run gated against the committed
baseline). NEW average 0.646 < OLD average 0.708 − 0.03, and NEW replies were
slightly longer (median 49 vs 45 toks), so per the agreed rule the OLD length
instruction is back; only the NEW word "preambles" was kept (tree differs from
HEAD by that word). Per-run spread (±0.1) dwarfs the gap, so sampling noise
cannot be excluded. Full table: `eval/RESULTS_2026-10-02.md`. Incidental fix:
every earlier gate run had `"baseline":null` (the script pushed to
`/sdcard/…`, unreadable to the app — only the 3 absolute gates ran); baseline
and `--prompts` files are now staged through `run-as`, and the harness logs
`FINN_EVAL_ERROR` when the baseline is missing. Verified: all 6 A/B runs show
a loaded baseline; `test/engine` 237 pass.

### 2026-10-01 — Chat <-> voice transition, version 9

The message field becomes the voice pill as one motion (details and the gradient/alpha
bug in ADR 0007). Verified on the Xiaomi by screen recording cut into frames, in both
directions, after the first version was found to be nearly invisible on the phone (the
gradient/alpha bug) and too front-loaded (the curve). New: 20 morph tests (frame-by-frame
width never stutters back, the field is usable again after leaving, a long message still
grows the field, a ticker is not left running while idle, narrow 320 dp, reduced motion).
The two controls-sheet goldens were stale because of this work's shorter "Spoken
responses" copy and were regenerated and looked at (clean HEAD passes them). Version
2.0.0-beta+9. GPL: owner chose to ship as is; see ADR 0007.

### 2026-10-02 — Beta feedback round: widgets, flows v3, mini-apps, chat creation, voice licence, transitions

Interactive home-screen widgets (counter, checklist, tracker; taps work with the app closed),
full-screen persistent mini-apps, a rebuilt Flows system (block tree with branches, triggers for
time and device events, conditions, a standing grant, background runs, a flowchart editor, authoring
from a sentence), apps/widgets/flows made from chat (a card in the thread), a shorter-by-default
reply prompt, and one page transition that no longer passes through the home screen.
Voice: Piper and espeak-ng removed; Supertonic 3 via our own ONNX Runtime shim and a source-built
sherpa-onnx without TTS (ADR 0008). Measured on the Xiaomi: load 1.3 s, RTF 0.42-0.48.

### 2026-10-01 — Live voice: spoken replies, hands-free loop, faster turns

Spoken replies (on-device Piper voices), a hands-free listen -> send -> think -> speak ->
listen loop, a pill that moves with what it hears, and a shorter, faster spoken turn.
Decisions and rejected options: `docs/decisions/0007-live-voice-and-spoken-replies.md`.

**Device run (same Xiaomi), debug build.** Voices downloaded on the upgrade screen
(~21 MB, unpack 5.9 s). Spoken turn, same kind of question, before -> after:
prompt eval 2655 -> 1141 ms (task instruction ~232 -> ~50 tokens), time to first text
3.0 -> 1.5 s, first audio 3.7 -> 2.1-4.1 s (depends on the first sentence). Speech
synthesis 0.30-0.65x real time (keeps up). The loop ran two questions in a row with no
taps: the microphone reopened by itself after the spoken answer. Three-sentence cap
verified (a five-sentence answer was cut at three). The "what is the capital of Italy"
question no longer web-searched (it had cost 9.5 s). The pill measurably changes width
with speech (frames: ~99 -> ~110 dp) and the caption changes with state. TTS at three
threads slowed the model from ~16 to ~10 tokens/s; at two it is ~11-13.

**Found, not fixed.** (1) espeak-ng (GPL-3.0) is statically inside
`libsherpa-onnx-c-api.so`; owner chose to ship v9 as is, risk accepted, notices added
(ADR 0007, THIRD_PARTY_NOTICES, in-app licences). (2) No
redistributable Hindi voice (fixed 2026-10-02 by Supertonic).
(3) Whisper base misheard "octopuses" and "capital" from a computer voice; the model then
answered the wrong question. (4) The model ignores "two short sentences" when asked to
"explain"; the cap is what bounds it. (5) First audio is still dominated by the first
sentence's length and by decode speed (~11-13 tokens/s with the voice running).

**Not verified.** Any voice but English (only English was heard through a real
speaker pipeline; the others are covered by unit tests and the catalog's pinned
digests, not run on the phone). Audio quality was not listened to by me: only logs and
timings. Real people speaking, noise, battery, long sessions, and the first-run
onboarding path.

### 2026-10-01 — Voice: on-device speech recognition (sherpa-onnx + Whisper)

Replaced `speech_to_text` (Android's `SpeechRecognizer`) with mic -> Silero VAD ->
Whisper base on a background isolate. Why and what was rejected:
`docs/decisions/0006-on-device-speech-recognition.md`.

**Verified.** `dart format` clean; `verify_engine_seam.sh` and `verify_boundaries.sh`
OK (the voice controller dropped from 611 to 433 lines, so its baseline line is gone);
`dart analyze .` clean; the voice, model-store, backend and shell tests pass
(new: 23 backend-state-machine tests with a fake mic and worker, 10 model-store
tests against a local HTTP server incl. resume and bad-digest, 12 audio-math and
transcript-filter tests, 3 sheet tests for the download card); `flutter build apk --debug` links
(arm64 `libsherpa-onnx-c-api.so` + `libonnxruntime.so`, both 16 KB aligned).
Full suite: 2 golden tests of the shared controls sheet fail (`widgets_controls_*`,
image size mismatch) in code this change does not touch; not run on a clean HEAD.

**Device run (Xiaomi 2109119DG "lisa", Snapdragon 778G, Android 16, debug build
installed over the existing app with the language model and onboarding already done).**
- *Upgrade path:* launching the new build showed the upgrade screen on its own, the
  four speech files downloaded (exact pinned sizes, ~7 MB/s on Wi-Fi), and the app went
  to chat. Relaunch did not show the screen again. About 25 s of that screen is the
  existing language-model re-check at 0%, before the speech download starts.
- *Offline upgrade:* with the speech files deleted and Wi-Fi/data off, the screen
  tried, logged `addon failed (continuing)`, went to chat, wrote the `.failed` marker,
  and the next launch skipped the screen (no install attempt).
- *Voice, real microphone, TTS from a Mac speaker:* English "What is the capital of
  France?" transcribed exactly and answered "Paris" through the model. Russian "Какая
  столица Франции?" came out as "Какая столица франции?" (language auto-detected).
  `FINN_STT`: model load 1.1-1.2 s, decode 0.57-0.70 s per ~2 s utterance, i.e. about
  1.6 s from the end of speech to text including the 0.9 s end-of-speech silence.
- *Hindi: FAILED.* "फ्रांस की राजधानी क्या है?" came out as "Ranski Rajbhani" (romanised
  gibberish). Whisper base is weak on Hindi and auto-detect did not help. Try forcing
  `language: 'hi'` from a setting, or Whisper small (~375 MB), before promising Indic.
- *Silence:* gives up after 10 s, sends nothing. The inline voice bar does not react to
  that (it stays until tapped); pre-existing behaviour of the bar.
- *Memory (PSS):* 2563 MB fresh -> 2749 MB with voice listening (+186 MB) -> 2545 MB
  after backgrounding (recogniser released).
- *Missing-model path:* tapping the inline voice button used to show "Speech recognition
  isn't available" with no way forward for a user who skipped the download; it now opens
  the voice sheet's download card. Verified offline (Download -> "didn't finish" ->
  Try again), then online: progress bar, then it started listening by itself.

**Not exercised on the phone.** The first-run onboarding path (it shares
`ModelInstall` with the upgrade path, which was run, and is covered by 11 unit tests,
but I did not wipe the phone's data to run it); the cellular-data cost of a 161 MB
download; accuracy beyond short TTS-voice utterances (no real speakers, no noise, no
accents); whisper hallucination on real noise.

**Pre-existing, seen while testing.** The phone has no text-to-speech engine, so after an
answer the voice controller stays in "speaking" and the composer shows Stop; tapping it
twice is needed to get back to the voice button.

**Left as it was.** Text-to-speech is still `flutter_tts` (the platform engine);
LFM2.5-VL cannot produce audio. The `liveTranscript` setting has nothing to show until
a streaming model is used. Backgrounding frees the recogniser (foreground-only holds).

**Setup/upgrade integration (same day).** The speech model now downloads right after the
language model in first-run setup and on the upgrade screen, best effort (a failure
never blocks the app). See ADR 0006 and `onboarding/model_install.dart`.

### 2026-09-30 (night) — v2 rewrite, stage 1: guardrails, search, engine/shell split, Lite

Plan: `/Users/abhi/.claude/plans/` (owner-approved): staged rewrite, quality first, Android Play
release only, app-driven search, template-first Creations, Flows v1 = scheduled + manual +
templates, minimum device 4 GB. Commits `69b5c31`…`4864cde` on `main`.

| Stage | State | Evidence |
|---|---|---|
| Audit log committed (Phase 0) | **done** | 5 tests; was missing an import, now purged by "Delete all data" |
| Guardrails | **done** | `tool/verify_boundaries.sh` (layering, feature edges, 600-line cap, shrink-only baseline), nested AGENTS.md, feature READMEs, ADRs 0001-0005, CODE_MAP test |
| Search rewrite (D1) | **done, device-verified** | `SearchPlanner` + `SearchTurn`; eval gates all pass; `WebSource` moved to `engine/api/` so `engine/` imports nothing from `features/` |
| Engine split | **done** (mechanical) | `finn_accelerator.dart` 4,479 → 574 lines + 17 part files; bodies moved verbatim |
| Shell split | **done** (mechanical) | `home_shell.dart` 5,073 → 578 + `shell/` and `widgets/`; `composer.dart` (648) is the one baselined file |
| Lite tier (D3) | **partly done, device-verified on the Lite *policy*** | text-only load, projector on first image; image case passes; not measured on a real 4 GB phone |
| Empty-reply retry (D2) | **done, host-tested only** | retry decision is a tested pure function; the native hiccup it guards cannot be forced |
| Flows v1 (D4) | **done for the notify-and-tap path; device-verified except the alarm firing** | templates (morning brief / web check / reminder), real steps, schedule editor, AlarmManager + notification, result saved as a chat; ran on the Xiaomi: Google News RSS (5 sources) + Open-Meteo + model, 14 s; alarm seen armed in `dumpsys alarm`. **Not verified:** the alarm actually firing and the notification tap. **Not built:** background run on capable devices (owner chose "both"); this is notify-and-tap on every device for now |
| Creations remake (D5) | **done**, host-tested; not device-run | 4 app templates, 2 widget templates, deck themes/layouts, slot editor; every template fuzz-tested; `append` with `{field}` + `clear` |
| Motion system (D6) | **not started** | |
| Real `FinnEngine` interface (D2) | **not started** | the parts still share private state |

Verified: `dart format` clean, engine seam OK, boundaries OK, `flutter analyze --no-pub` clean,
**942 tests**. Device: three eval runs on the Xiaomi (see RESULTS v2).

**Correction to the earlier "Phase 4 done" claim.** Flows were not usable: the page built its runner with no model, `browse` steps failed as "unsupported", `notify` did nothing, nothing created steps or a schedule, and `runDueScheduledFlows` had no caller. The 23 tests passed because they injected every dependency. That is now fixed and exercised on the phone. Also found on the phone: general keyless search cannot answer news or weather questions (a Wikipedia search returns articles *about* news), so two keyless providers were added (ADR 0002 amendment), and a brief with no sources made the model invent them, so such a run now fails instead.

Known gaps to carry forward: searching turns cost 8-12 s TTFT; an empty reply after the retry
now shows an error bubble with Retry (host-tested; not seen on a device); check pass rate is
65-75% (verbosity); the voice and Flows device runs are still unverified.

### 2026-09-30 — Milestones 4-8: Phases 1, 2, 3, 4, 5 merged; Phase 6 started

| Phase | State | Evidence |
|---|---|---|
| 0 — baselines + harness | **done** | 29-case suite run twice on the Xiaomi; [`eval/RESULTS_2026-09-30.md`](eval/RESULTS_2026-09-30.md) |
| 1 — core + response quality | **done** (client + engine) | 847 tests; TTFT p95 −51% |
| 2 — design + onboarding/a11y | **done** | consent fix; 38 goldens |
| 3 — search speed | **done** | search policy + one client + bounded caches |
| 4 — Flows runner | **done**, device-**unverified** | 23 tests; no device run |
| 5 — voice | **done**, device-**unverified** | 29 tests; phone has no TTS/STT engine |
| 6 — system assistant | **started** | audit log written, uncommitted |
| 7 — desktop macOS | not started | — |

Commits `c701614`…`0493be0` on `main`, plus two merges (`64357a6`, `890ff3b`).
Gate at the last commit: `dart format` clean · seam OK · `flutter analyze
--no-pub` no issues · **`flutter test --no-pub` 847 passed, 0 failed**
(was 670 at the start of this session).

#### Phases 1 + 2 — merged (`64357a6`, `890ff3b`)

**Phase 1 client.** The two markdown-throttle tests that §10 previously
recorded as blocking are green, and the blocker was a real bug rather than a
bad test: the throttle decided to defer by comparing `DateTime.now()`
against the age of the last parse, which the widget clock does not advance.
The trailing parse also re-entered `build` and re-evaluated the same
conditions, so it could re-defer indefinitely. The window is now closed by a
flag `_canReuseRender` treats as an unconditional refusal, so the trail is
bounded by the window plus a frame rather than by a timing guess. One of the
two failing tests asserted an exact render *mid-burst* — which is precisely
what the throttle defers — so it was corrected, and a new test asserts the
real invariant: stale inside the window, exact outside it.

Also merged: the O(n²) token path (951,995 chars copied → 3,896 for the same
500-token burst), the terminal-commit ordering race that made a two-token
reply appear only after the *next* user turn, and a `dispose()` that left
llama.cpp decoding in the background.

**Phase 2.** The consent step **could be skipped, and skipping opted you in**
(Critical #4, device-confirmed). Next is now disabled until Yes or No is
chosen, with a line saying why, and the question defines what "context" means
in all five locales. Fixing the copy exposed a layout fault the audit had
only ranked High: `_StepPage` sizes the artwork card from the height it
reserves for the body, so the added sentence pushed the only two tappable
things below the fold (y=877 on a 390×844 phone). The answers are now pinned
and the explanation scrolls. Semantic colour tokens with measured WCAG
contrast, a visible dark user bubble, one motion language, 48dp targets, and
**38 goldens** (from 4).

#### Phase 3 — search speed (`b055ac7`, `ed97cda`)

Suppressed browsing for closed-domain facts and for follow-ups, made the
decision prompt history-aware (its `history` parameter had been threaded
through three layers and never written into the prompt — which is *why*
follow-ups went to the web), put the per-intent task instruction into the
session cache key, halved the tool budget to 6s, and stopped an unterminated
`<tool_call>` parsing as a finished one.

The output budget was **inverted**: `max(intentBudget, ctx - 96)` meant the
context bound always won, so every turn was allowed 4000 output tokens on a
4096 context. The eval caught a real runaway on exactly that — 4000 tokens,
230 seconds, for a question whose whole answer was one word.

Then one shared keep-alive HTTP client instead of three pools, and the
browser's two unbounded caches bounded (24 entries, 15 min TTL).

#### Phase 4 — Flows as real automations (`88de43c`, `f5a4270`)

Flows were a prompt-snippet manager with a keyword gate. A flow is now a list
of steps, and **a flow cannot act on the device without permission** — the
rule is enforced in three independent places (shape check, manual run,
scheduled run) and each has a test. `flows.json` had a version that was
written but never read; a v1 file now migrates. Runs are recorded in a
bounded log that **holds no model text**. 23 new tests.

#### Phase 5 — voice, foreground-only (`0493be0`)

`SpeakableText` turns Markdown into speakable segments: code blocks become a
short marker instead of "backtick d-a-r-t backtick", tables one marker rather
than a run of "pipe Name pipe", links speak their label. 23 tests.

Voice is now **genuinely foreground-only** — backgrounding the app left the
microphone hot and the orb frozen. `voiceDidNotCatch` had been translated
into five languages and never displayed; it is now a real state. Two smaller
bugs with real symptoms: a failed `speak()` could leave the controller stuck
in `speaking` forever, and the orb was rebuilt at audio-callback rate (each
rebuild restarted three `AnimatedContainer` tweens before they could finish).

#### Phase 0 — the baseline is finally measured

This is the §4 Phase 0 "definition of done" line, and it is now closed. Two
runs of the same 29-case suite on the Xiaomi, before and after Phases 1-3.
Full write-up in [`eval/RESULTS_2026-09-30.md`](eval/RESULTS_2026-09-30.md).

| | before | after |
|---|---|---|
| Empty replies | 17.1% | **8.6%** |
| TTFT p50 | 2704 ms | **2115 ms** |
| TTFT p95 | 9250 ms | **4489 ms** |
| 4000-token runaway | 1 (230 s) | **0** |
| Browse suite | 0.75 | **1.00** |
| Everyday suite | 0.00 | **0.33** |
| Factual suite | 0.67 | **0.33** |
| Check pass rate | 71.4% | 69.0% |

**Two of three gates still fail** and the run reports `"passed": false`.
Empty replies are 4× the 2% bar and browse recall is 0. The factual drop is
the honest price of suppressing searches for closed-domain facts: those cases
now answer from the model's own knowledge, which is right for "what is the
capital of France" and wrong for anything the model has stale.

**The baseline *files* were not recovered.** The app is replaced by the next
build and the file each run wrote to external storage went with it. The
numbers above are the `FINN_EVAL_SUMMARY` lines, which are what the files
hold. `tool/run_eval.sh` now survives a dropped USB link, which is what lost
the first of the two runs.

#### Phase 6 — started, not finished

`ActionAuditStore` is written (an append-only, bounded log of which action ran,
whether it was approved or refused, and from where — with **no prompt text
and no action arguments**, because a `dial` number is the user's data and the
encrypted conversation store is the right place for it). It is wired into the
chat approval and refusal paths. **Uncommitted and not gated.**

**Not started:** share-to-Finn (`ACTION_SEND` is not accepted at all today —
only `PROCESS_TEXT` is), the dead `finn_creation_id` shortcut deep link, and
the Assist role, which PLAN.md's own cut line says to defer.

#### Explicitly still open

| Item | State |
|---|---|
| Empty replies 8.6% vs 2% bar | **unfixed** — the ordering race is gone; something else causes the rest |
| Browse recall 0.0 | **unfixed** — the trigger lists are keyword-based and match nothing in the suite |
| RAM growth 2.54 → 3.73 GB | partially addressed (bounded browser caches); not measured |
| Non-Latin eval | still deferred — needs a hand-typed prompt or a harness |
| TalkBack pass | still deferred to the owner |
| Voice on a real device | **unverified** — the phone has no recognizer or TTS engine |
| Flows on a real device | **unverified** — 23 host tests, no device run |
| Phases 6 (rest) and 7 | not started |

#### Two things worth knowing about this environment

`flutter emulators` **crashes** on this OHOS Flutter fork (`--launch-ohos-emulator`
is passed to a command that does not accept it). The `Medium_Phone` AVD
exists and can be started directly with `emulator -avd Medium_Phone`.

`flutter test` appears to hang rather than fail when a **previous run's
`flutter_tester` process is still alive**. `pkill -f flutter_tester` first.
This cost roughly 40 minutes and is worth remembering.

---

### 2026-09-30 — Milestone 1: Phase 0 (baselines + harness) merged to `main`

Commits `e347192` (pre-existing onboarding/Flows work checkpointed), `af513d9`,
`134df4f`.

**Owner decisions now settled (§9).**

| # | Decision | Answer |
|---|---|---|
| 1 | Release-mode perf aggregates | **Yes**, no prompt text — every 8th turn |
| 2 | Q4_K_M measure-only A/B | **Deferred.** Q4_0 stays pinned |
| 3 | macOS-first desktop | Confirmed (Phase 7, not started) |
| 4 | Foreground-only voice | Confirmed (Phase 5, not started) |
| 5 | One polished release after full QA | Confirmed |
| 6 | Real-user sessions | Not started (§8) |
| 7 | Eval quality bar | **Set** — see gates below |
| 8 | Image eval | Deferred, non-blocking |

**Done and verified.**

- **Harness out of `main.dart`.** The production entry point is now 116 lines of
  bootstrap and nothing else; the benchmark moved to
  `lib/src/engine/eval/benchmark.dart` and the quality runs to
  `lib/src/engine/eval/{harness,eval_prompts,eval_baseline}.dart`.
  `main.dart` went from 410 to 116 lines, all of it wiring.
- **The catalog is data with machine-checkable expectations**, not a prose rubric:
  `eval_prompts.dart` carries 31 cases across the suites of §2 (factual, math,
  instruction, recall, multilingual, browse, everyday, adversarial, determinism).
  A check is a predicate over the answer (`containsAny`, `forbids`, `wordCount`,
  `hasLines`, `matches`, `satisfies`), so a wrong answer fails a check for a reason
  the report can name.
- **Summary + gates are pure Dart**, so CI can fail on a regression with no phone
  attached. `compareToBaseline` emits a gate only when its denominator is non-zero —
  a run that measures nothing must not read as a pass. This caught a real bug in my
  own first cut (browse precision reporting 0.0 for a suite with no must-not-browse
  turn); it is fixed and covered.
- **Baselines carry no prompt or answer text.** Observations record counts,
  latencies, routes and check verdicts only. A test asserts the encoded file
  contains neither, because a baseline is generated on a real phone and committed.
- **`tool/run_eval.sh --write-baseline`** is the `tool/eval --baseline` entry point
  from §4 Phase 0: build, install, run on device, pull the baseline into `eval/`.
  `--prompts eval/prompts/multilingual.json` covers the deferred non-Latin half of
  Suite B — `adb shell input text` mangles non-ASCII (Devanagari arrived as literal
  `\xNN`), so those 20 prompts travel as a file instead.
- **Release builds are no longer blind (§9.1).** `PerfLogSampler` samples
  `FINN_PERF`/`FINN_TTFT`/`FINN_PREFIX` once every 8 turns in release instead of
  never. These lines carry only numbers, which is what makes the gate safe; the
  full prompt breakdown (`FINN_PROMPT`) stays debug-only, and the
  unverified-weights warning stays a debug decision rather than a measurement. The
  rule takes the build mode as a parameter so it is testable — a test runs in debug,
  where `kReleaseMode` is false and every turn would be kept.
- **`.finn_repack` is deleted with the model.** It is ~693MB on the 1.6B and nothing
  removed it, so "Delete All Local Data" left a third of a gigabyte on the device —
  the exact state VERIFICATION.md §6 recorded. `removeModelArtifactFiles` is now the
  one cleanup path for the model, its `.part`, its range side-files and the repack
  cache, as a testable top-level function.
- **Eval quality bar (§9.7), numeric and sourced** — `eval/README.md` documents each
  gate and where its number comes from: empty-reply ≤ 2% (the device rate was 2/21),
  browse precision = 1.0, TTFT +25%, decode −15%, check pass rate −5%, with every
  relative gate skipped when the baseline has no comparable number.

**Gate state at this commit:** `dart format` clean (211 files) · seam OK ·
`flutter analyze --no-pub` no issues · `flutter test --no-pub` **670 passed, 0 failed**.

**Not verified — do not treat as done.**

- **The baseline has not been measured.** The eval APK builds and installs, but no
  `eval/baseline_*.json` has been produced from a real run, so the gates are
  unexercised against hardware. This is the §4 Phase 0 "definition of done" line
  still open: **run `tool/run_eval.sh --write-baseline` on the Xiaomi** (model
  already installed; ~25 prompts, several minutes, screen on).
- **RAM growth (2.54GB → 3.73GB PSS over 20 turns) is unexplained.** No
  investigation started. §4 Phase 0 lists it; it is open.

### 2026-09-30 — Milestones 2 & 3: Phase 1 (chat streaming) + Phase 2 (design system) IN FLIGHT, not merged

Both are being built on separate worktrees off `main` with disjoint file sets, per
§5. Neither is merged; neither is verified end to end. Treat every line here as
*work in progress*, not as a claim.

**Phase 1 — `phase1-chat` worktree (uncommitted).** Targets the client side of the
two device-confirmed Criticals:

- O(n²) token path — `buffer.toString()` per token replaced by a single
  materialisation per paint batch, with the count and bytes exposed for tests.
- Message-ordering race (Critical #3, the "blue" reply appearing only after the next
  user message). Root cause: `_finishPersisted` published the terminal job *after*
  awaiting the encrypted flush, so anything running in that window (`flushActive`,
  `stop`, the 1.5s persistence timer) re-read a stale live job and overwrote the
  finished answer — downgrading status back to `generating`, and truncating text
  whenever the last paint lagged the buffer. Fix: commit to the store and publish
  the terminal job in one synchronous step before the first await.
- `dispose()` now stops the native generation, not just the Dart subscription —
  previously llama.cpp decoded to completion in the background holding the KV
  session. The epoch is bumped before detaching, so late tokens are counted, never
  applied.
- 13 tests written, **11 pass / 2 fail.** Both failures are in the new
  `safe_markdown_text` throttle tests ("final render equals final streamed text",
  "a burst inside one paint gap costs one parse"), not in the controller fixes.
  **Blocked on that.** The throttle design defers a re-parse inside a paint gap and
  schedules a trailing one; it needs review before it ships, because stale rendered
  text during a stream is a worse bug than the parse cost it saves.

**Phase 2 — `phase2-design` worktree (uncommitted).** Targets the measured contrast
failures and the missing dark-mode coverage:

- Semantic colour tokens with light+dark variants (`linkOf`, `infoOf`, `warningOf`,
  `successOf`, `bubbleUserOf`, `bubbleAssistantOf`, `secondaryInkOf`) plus a 48dp
  `minTapTarget`. The values replaced were measured on the device: link 3.9:1, amber
  pill 2.15:1, 50%-alpha body text ~2.3-3.2:1.
- `test/shared/` — **32 tests passing**, including WCAG ratio maths asserted in the
  test against both brightnesses, and the 48dp / semantic-label checks.
- Goldens expanded from 4 light-phone onboarding shots to **35**: light+dark ×
  phone/small/tablet/landscape, plus the shared widgets.
- Locale-safe section labels (the `toUpperCase()` that breaks tr/i18n), one named
  page+motion pair, and an ARB copy pass removing `llama.cpp`/`GGUF`/`artifact`/`Purge`
  jargon from user-facing strings.
- **Goldens not yet inspected.** A golden that captures a layout error is worse than
  no golden; the produced PNGs must be read before this merges.

**Explicitly not started.** Phases 3-7 (search speed, Flows runner, voice, system
assistant, desktop). The Phase 1 *engine-side* items are also still open and are not
in the `phase1-chat` worktree: deterministic factual sampler, history-aware decision
prompt, single grounding format / stop browsing static facts, per-intent instruction
in the session identity hash, attachment-preserving continue/regen.

**Next, in order:** (1) resolve the two failing throttle tests or drop the throttle;
(2) inspect the Phase 2 goldens, then merge both with a full gate run; (3) run
`tool/run_eval.sh --write-baseline` on the Xiaomi to produce the first real baseline;
(4) begin the Phase 1 engine-side response-quality work.

**FinnAI Code — 2026-10-03.** A second app inside the app (`lib/src/features/code/`, ADR 0010): a coding agent with its own sessions, settings and providers, reached from the brand row of either sidebar. Runs on the on-device model, or on the user's own OpenRouter / Command Code (GOAT+) / OpenCode Zen / OpenCode Go / OpenAI-compatible key, with live model lists and OpenRouter allowance. Commands run in a workspace shell (private folder, policy, timeout), not a VM. Verified on an Android 37 emulator with the real 1.6B model (file write, approved command, real output) and against a local OpenAI-compatible server (live model fetch, disclosure, streaming). **Not verified:** any paid provider account, iOS, OpenHarmony, a low-RAM device, or on-device model quality beyond simple tasks. Open: encryption at rest for Code sessions; a real Linux environment (ADR 0010 lists what it needs); function-calling for cloud models was left out on purpose.

**Branch consolidation — 2026-10-03.** Everything on separate worktrees is now on `main`: `phase1-chat` and `phase2-design` were already ancestors of `main` (nothing to merge, so "merge both" above is done); `harmonyos-full` (OpenHarmony plugin layer, key-storage seam, rebuilt llama.cpp) and the FinnAI Code branch were merged; the onboarding layout fix (system-bar insets, welcome bloom anchored to the bottom edge, larger body budgets) landed with regenerated goldens. Gate on the merged tree: format, seam, boundaries, `flutter analyze`, 1528 tests and the shell tests pass, and a debug APK builds. **Not run:** the app on a device or emulator (none was attached), the OpenHarmony build (no Hmos SDK on this Mac), and iOS.

**Code/FinnAI UI parity — 2026-10-03.** FinnAI Code had drifted from the shared design language, and the drift was worst in dark mode. Two of the app-wide's permanent raised surfaces still carried hand-rolled `BoxShadow`s — the Code composer pill and the action card — after the rest of the app had moved to fill + a 1px hairline; over the near-black canvas a shadow is `elevationOf` (`#F5F5F7`), so in dark the pill wore a pale halo and the card's 6% lift was invisible, leaving it an edgeless slab. The user bubble and error notice had lost the hairline their chat counterparts keep, and Code's send glyph was `actionInkOf` (`#414141`) where the shared button uses `canvasOf` (`#101014`). Separately `FinnCaption` documented "secondary ink" but read through `actionOf`, so in dark a caption came out brighter than the title above it.

Both apps also carried private copies of the same controls: `_SidebarConversationTile` and `_SessionTile` were the same card, `_Chip` duplicated `FluxChip`, the composer's `circle()` duplicated `FinnCircleButton`, and three private pill text fields (API key, model search, terminal prompt) each had their own hint alpha. Six components are now shared — `FluxSurfaces.flat`/`flatCard`, `FluxPillField`, `FinnSidebarHistoryTile`, `FluxChip` gaining `icon`/`trailing`, and `FinnCircleButton` gaining `dimmed` — living in the new `lib/src/shared/widgets/flux_surfaces.dart`, which took 90 lines out of the baselined `flux_controls.dart` (baseline tightened 1020 → 930). Net **−120 lines** across 26 files. Six new tests pin the behaviour (`test/shared/flux_dark_mode_test.dart`, `test/features/code/code_ui_test.dart`); the composer-pill test was verified to fail when the shadow is reintroduced. Gate: format, seam, boundaries, `flutter analyze` clean, **1534 tests** pass. **Not verified:** the app on a device or emulator, so the dark-mode change is argued from tokens and asserted in tests, not seen on glass — the Code screens still have no goldens.

**Brand row reveal — 2026-10-03.** The brand row opened a popup: both app names inside a filled card, each with an icon, the current one carrying a check. It is now an inline reveal — press "FinnAI ⌄" and "FinnAI Code" appears directly beneath it as plain text, no container, no glyph, on a backdrop that blurs what scrolls underneath and carries no colour of its own. Only the app you are *not* in is listed, since the row's own title already says which one you are. The chevron rotates to mark the expanded state, and the reveal is exempt from the brand row's scroll fade so it cannot fade out from under a reader.

Three things had to be worked out rather than assumed. (1) Flutter **cannot** mask a backdrop blur: `ShaderMask` pushes a shader-mask layer and a `BackdropFilter` inside it filters that layer's empty contents, so the obvious pairing renders nothing at all. The ramp is clipped bands instead — band *k* covers everything below its own top edge, painted top to bottom, so each re-blurs the ones above and strength accumulates with depth. Every band carries the *same* sigma; a per-band sigma that grew with depth compounds and turned the history to a grey smear (caught by eye in a golden). (2) A transparent blur only does anything when there is something to blur, which is the history *mid-scroll* — at rest the reveal pushes the panel down and there is flat fill behind it. A first golden showed this wrong, mid-scroll with no backing, and the option's text vanished into a light chat card. Fixed by keeping the panel's pinned cover extended past the reveal, so the option always has the panel behind it. (3) The sidebar and the switcher originally each held their own "is it open" flag; the panel's height snapped closed on the same frame the reveal began collapsing, and 42dp of content overflowed a 50dp band for the length of the animation. Both now read one shared `BrandExpansion`, which is also why the state is `TickerProviderStateMixin` — one controller per tap would trip the single-ticker assertion.

Also: `FluxPressScale` gained an `alignment` so the wordmark (much wider than it is tall) shrinks toward its left edge rather than drifting sideways on press. `FluxGlass` moved to `flux_surfaces.dart` alongside the other surfaces. Two goldens (`widgets_brand_reveal_{dark,light}`) capture the resting state in both themes, and 6 new tests cover the reveal, the shared expansion, the band ramp, and the mid-scroll legibility case that the first golden exposed. Gate: format, seam, boundaries, `flutter analyze` clean, **1541 tests** pass. **Not verified:** on a device or emulator, so the blur's real appearance over live scrolling content — the most likely thing to want tuning — is argued from goldens rather than seen.

**Linux container + polish pass — 2026-10-05.** FinnAI Code's commands now run in an emulated Linux container (ADR 0011): v86 (bundled, BSD) boots a pinned, SHA-256-checked kernel + busybox image (9.8 MB, downloaded from Code settings) in a hidden WebView; the project is copied in and back as ustar per command, exec bits kept. The composer gained file attachments (copied into the project folder, named in the request). Fixed on the way, all found on an Android emulator with the real model: onboarding ETA counted one file of the install, its byte read-out and percentage counted different things, the notification prompt repeated per artifact; the chat and Code fields sat ~4dp high on Android (the lift was calibrated for Linux's FreeType) and did not grow for a second line; a run of blank lines in a reply stacked spacers; Code's keyboard stayed up over the agent's first action; terminal output wrapped `ls -l` columns and did not follow new output; a terminal with no session was a dead page; Creations' filter row cut a label at the margin. Verified on the Android emulator (phone, tablet portrait/landscape, light and dark): container download, boot, commands, file round trip, attachments. Then on HarmonyOS (API 24 emulator): the container runs there too (ArkWeb via `webview_flutter_ohos`), and fixed: the app chose German on any language it does not ship (Flutter falls back to the alphabetically first locale), status-bar icons were dark on the black welcome screen, the system back gesture never reached Flutter, chat and Code titles touched the new-session button, `tool/ohos_dev.sh text` dropped multi-word input. UI pass across both apps: large collapsing page titles on every secondary page, depth in page transitions, press feedback on tiles, a stretching switch with a disabled state that no longer reads as "on", message entrances that grow from their side, animated action-card state and height, the terminal input matching the other composers. **Not verified:** iOS (no simulator runtime installed), Linux desktop (no Linux host), the OHOS back gesture by hand (injected keys bypass it), a physical phone's container speed.

**FinnAI Code, Linux sandbox, app-wide UI — 2026-10-06.** Verified on a Xiaomi Mi 11 Lite 5G NE (Android 16, 90 Hz) and the HarmonyOS 6.1 emulator.

- *On-device agent harness.* Code's prompt no longer rides inside the chat persona: an `agentPrompt` engine mode renders only Code's system prompt (the 1.6B model had been echoing the injected date as its summary) and keeps a stopped agent session primed, so each step appends instead of re-reading the conversation — first token per step 5.3 s → 0.6 s on the Mi 11 Lite. Small-model aids (`small_model_aids.dart`) — guided reply starts (file to create, language line, run, install, rewrite), format repair, failure hints, "done" detection — took 'create X … run it' and 'change X … run it' from never finishing to finishing (Python, shell, Node with its own `apk add`).
- *Cloud harness.* Search/replace edit action with before/after on every write, retries on 429/5xx/network before the first token, Anthropic system-prompt caching. Exercised on the phone against a scripted OpenAI-compatible server (no paid key used).
- *Code UI.* Compact log: 30dp tool rows, inline diffs, inline approvals, 14sp prose / JetBrains Mono 12sp, slim input with `/` commands and `@file` mentions (contents sent with the request), status line, terminal as a slide-up panel sharing scrollback with the full page, live command output.
- *Linux sandbox (ADR 0012).* proot + Alpine 3.24 aarch64 on Android: network, apk/apt/pip/npm/git/cc, project mounted at /workspace, packages persist; setup <9 s, first command ~0.2 s. **HarmonyOS cannot run it**: the app cannot start any process there (also why the device-shell fallback never worked; now reported as "files only"); HarmonyOS keeps the v86 container, without network.
- *App UI.* Filled icons app-wide (Phosphor; bold for bare strokes), the design's "+" sheet, one bottom-centre create button (Creations, Flows, You), motion on shared tokens, skeleton loading, audit fixes (sidebar floor, mislabelled icons, reply-menu anchor). Frame timing on the Mi 11 Lite (SurfaceFlinger): chat scroll, sidebar, page push, Code scroll 0 frames over 1.5 vsync at 90 Hz; the "+" sheet's first open drops 3 frames, later opens none.
- **Not verified:** a paid cloud provider, iOS, Linux desktop, a networked sandbox on HarmonyOS, Google Play policy for the downloaded-binary sandbox (see ADR 0012).

**UI and motion pass — 2026-10-06.** Verified on the Android emulator (API 37, 1080x2400, profile build), dark and light.

- *Type and icons.* Geist (OFL) replaces Instrument Sans app-wide, with tighter tracking on the larger roles; Lucide at its 300 stroke weight (1.55 on a 24 grid, rounded) replaces Phosphor's fill set in `FluxIcons`, `CodeIcons` and `FlowIcons`. References: libraries.dev (Inter, 1.5px stroke icons), Hark (GT Standard, not free; Geist is the closest OFL grotesk).
- *Morphing sheets.* `finn_morph_sheet.dart`: a sheet grows out of the control that opened it (rect, radius and fill lerp from the button; content fades in once there is room, leaves first on close) and floats 10dp off the side and bottom edges as frosted glass. Used by the chat "+" sheet, every `showFinnSheet` (Flows' and Creations' "+" and Flows' empty-state button pass their rect), and `showFinnMenu` (grows from a small anchor, rises for a long-pressed card).
- *Composer fuse.* With the keyboard up on a phone, "+", field and send merge into one panel (text on top, "+" bottom-left, mic and send bottom-right) and sit 6dp above the keyboard (was 37dp); chat and Code share `KeyboardFuse`, which reads the keyboard from the physical view because a resizing Scaffold hides it from its body's MediaQuery. The same bug meant Code's "keyboard is up" terminal layout never ran; fixed. The chat composer no longer animates its bottom edge, which had made it trail the keyboard.
- *Onboarding.* The welcome screen's pink card becomes the privacy step's artwork card: the swipe drives it directly (commit past ~15% or on a flick), the sky lifts away, the canvas and copy rise in, Back plays it in reverse. Steps fade through in place instead of sliding whole screens; a skip (consent "No") never flashes the step between; the progress bar grows on from the previous step.
- *Details.* Thinking orb + shimmering "Finn is generating"; voice mode's colour glow rising from the bottom edge with the voice level (libraries.dev voice); greeting revealed by a soft wipe out of a blur; floating, theme-aware snackbars (were a white Material slab in dark mode).
- Gate: format, seam, boundaries, `flutter analyze`, 1673 tests pass; 40 goldens regenerated and inspected. **Not verified:** a physical phone, HarmonyOS, Linux desktop; voice glow with a live microphone (the emulator's mic permission was declined, so only its idle/listening rest state was seen); frame timing (the emulator's recorder captures too few frames to judge).

**Voice, Flows, history, Code list — 2026-10-06 (second pass).** Verified on the Android emulator (API 37) with the host GPU (`-gpu host`), dark and light.

- *Voice mode, Siri-style.* The colour pill is gone: the field dissolves and the state line ("Listening…") sits between the buttons. The light is `shaders/voice_glow.frag`, one full-screen pass: a rim of colour round the screen's rounded edge that draws itself in from the bottom, and heavily blurred orbs rising from the bottom edge, both following the voice level. No blur is computed — the softness is the Gaussian evaluated per pixel; no layers, no filter passes. Measured on the emulator over the same voice-mode screen (raster ms, p50/p90/p99): no light 15.6/17.8/22.6, shader 15.5/18.4/21.7, gradient fallback 15.5/23.0/63.9 (the ~15.5 floor is the emulator's pacing). The gradient painter remains as the fallback where runtime effects cannot load. The transcript steps back (scale + dim) while voice is open; a haptic marks the opening. `FrameLog` (`--dart-define=FINN_FRAME_LOG=true`) prints `FINN_FRAMES` lines for repeating this on a phone.
- *Flows (Shortcuts × Tasker).* A search field, filters, and a two-column grid of tiles coloured by what starts the flow, each with a run button and an on/off switch; the step picker is a search field, family chips and coloured step rows; the editor's steps carry the same colours.
- *History (Siri app).* The sidebar's chats are a masonry of cards: when, a bold title, a preview of the answer (model markup stripped), a photo card for a chat that started from one.
- *FinnAI Code (Cursor mobile).* Sessions are rows: a state dot (working, needs you, done, failed), title, and "status · files · +added −removed", under Pinned / Today / Earlier.
- *Also.* The sidebar sheet steps back as it slides; streaming text fades in at the line being written, and "generating" crossfades into the first words; dark-mode dialogs' primary button was white text on white (fixed).
- Gate: format, seam, boundaries, analyze, 1681 tests, goldens regenerated (plus six voice-light goldens). **Not verified:** a physical phone (frame times above are an emulator's), HarmonyOS (runtime-effect support there unknown; the fallback covers it), a live microphone (permission declined on the emulator).

**UI and motion pass, part 3: one component set, accessibility, blur — 2026-10-07.** Verified on the Android emulator (API 37, 1080x2400, `-gpu host`, profile), dark and light, English and German; reference board and screenshots in `docs/design/ui-pass-2026-10.md`.

- *FinnAI Code looks like FinnAI.* The chat's parts moved to `shared/widgets/` and Code uses them at the chat's sizes: the composer row (`FinnComposerFrame`: 50dp circles 20dp apart, the hairline pill, the keyboard fuse), the header (`FinnShellHeader`, same line in both shells, scaled from the keyboard-free height so it no longer jumps when the keyboard rises), the greeting (`FinnGreeting`), the user pill and error card (`FinnBubbleBox`, `FinnRetryButton`), the thinking orb, the confirm pills (`FluxPillButton.secondary`), 16sp replies, `FinnPageHeader` on the terminal page. Removed: `_RoundButton`, `CodeSmallButton`, chat's private circle and `_ControlSwap`.
- *Chat keyboard bug (pre-existing).* Tapping the chat field opened the keyboard and closed it ~140ms later: as the keyboard rose the composer swapped from the voice bar's tree to the fused panel's and remounted the TextField. Fixed with a GlobalKey; reproduced on a build of `219a0ae`; regression test simulates the keyboard as a phone.
- *Accessibility.* 26 controls hid their tap target from TalkBack (`Semantics(excludeSemantics)` without `onTap`; `clickable=false` in uiautomator): the "+" buttons, dialog buttons, menus, Code's status chips, Flows' editor and tiles. Fixed, with a source test. Touch targets raised to 48dp: reply actions (40), Code status line, terminal bar and prompt, approvals (32), Flows tile run/switch (38), flow editor add chips (44).
- *Contrast.* Flows tile text was 2.3-4.1:1 (2.2:1 paused in light); every trigger colour is now at least 4.5:1, checked by a test.
- *Blur and tickers.* Morph sheets no longer run a 28-sigma BackdropFilter per frame (opaque fill of the same resting colour); the brand reveal's eight stacked backdrop blurs became a gradient; a closed sidebar disables its tickers; the onboarding arrow honours reduced motion. Idle-redraw tests added for the greeting, composer frame, Code's thinking row and the closed sidebar.
- *Frame timing* (emulator; before = build of `219a0ae`, after = `1286334`; raster p50/p90/worst p99 ms, frames over budget): "+" sheet ×8 3.0/5.8/23.4, 13 over → 1.8/3.1/9.4, 0; sidebar ×6 2.6/3.8/8.1 → 2.8/4.4/15.9, 0 both; Flows push/pop ×4 (warm) 1.6/2.6/6.4 → 1.8/3.1/11.3, 0 both (first run after install had one 214.6ms frame, not recurring, not explained); keyboard fuse ×5 after: 1.7/3.8/8.1, 0 (not measurable before: the keyboard closed).
- Gate: format, seam, boundaries (`flux_controls.dart` 721 → 679, stale `home_shell.dart` entry removed), analyze, 1693 tests; goldens regenerated and inspected (two brand-reveal goldens, unchanged at rest). Also fixed a flows test that failed intermittently under a full run.
- **Not verified:** a physical phone, HarmonyOS, Linux desktop, iOS; voice mode with a live microphone; onboarding (re-running it needs a reinstall, which deletes the model); French; screens with lots of data (one chat, two Code sessions, two flows); the Linux sandbox and real terminal output on the emulator ("the container view did not load"); a multi-line diff (only a one-line write); a streaming chat reply; tablet in light mode; notification permission (not granted). The chat's empty screen exposes a full-screen text-field node that merges the greeting into the field's hint for TalkBack; seen, not fixed.

---

*Plan approved 2026-09-30. Phases 0-2 in progress; §10 records what is verified.*

# 0009 — Flows v3: a local automation system

**Status.** Accepted 2026-10-02. Implemented; background triggers verified on a Xiaomi 2109119DG.

**Context.** Beta testers found Flows "implemented very badly": a flat list of steps run once a day, no way to react to the phone, an editor that was a form. The ask was a local MacroDroid / Tasker / Shortcuts: a flowchart, triggers, conditions, AI as one block among others.

**Decision.**
- **Model.** A flow is a *tree* of blocks (`flow_blocks.dart`): ask, web, notify, speak, action, wait, branch (yes / otherwise lanes), save-to-chat, stop. It has triggers (`flow_triggers.dart`: manual, time of day (daily or chosen weekdays), every N minutes, charger connected/disconnected, battery low, headset, Wi-Fi, airplane mode, boot, screen unlocked) and "only if" conditions (`flow_conditions.dart`: battery above/below, charging, time window, weekdays, Wi-Fi, headset, airplane mode, and whether the last answer contains some text). `flows_codec.dart` reads every older shape. Limits are fixed (block count, depth).
- **Triggers are native.** Time triggers use inexact `AlarmManager` alarms (no exact-alarm permission). Device events use a foreground `specialUse` service that registers receivers dynamically, only while at least one event flow is enabled. Both hand the flow id to `FlowDispatcher`, which queues it (simultaneous triggers are never dropped) and either tells the running UI or starts a headless Flutter engine (`flowBackgroundMain`) that runs it with the app closed.
- **Safety is unchanged and now covers events.** Nothing runs unless the user enabled the flow. Device actions need a grant. A user-started run asks; an automatic run uses only the stored standing grant; a background run stops at an action that needs the screen. The run log holds no model text. Flows reach the engine, search and conversations only through `flow_ports.dart`.
- **Authoring in three tiers, cheapest first.** `FlowPhrases` (rules over a sentence), `FlowScript` (a line-based script the model writes), then `FlowAuthor` (the model proposes a script, which is validated like any other). The small model never designs a graph directly. Chat can create a flow ("every weekday at 7 give me the news"), shown as a card in the thread.
- **Editor.** A vertical flowchart (`flow_chart.dart`) with connectors and lanes; tapping a node opens a sheet for that block. Add, move, delete, test-run.

**Rejected.** Exact alarms (permission and Play review cost). A visual-programming canvas with free placement (a 1.6B model and a phone screen both do badly with it). Letting the model emit tool calls inside flows (ADR 0001).

**Consequences.**
- A flow can outlive the app being open; the user can see that (foreground notification while event flows are armed).
- Inexact alarms can be late by minutes.
- Battery-saver and manufacturer task killers can still stop the event service; there is no workaround we ship.
- Triggers are Android only (the native side is Kotlin); on other platforms flows can only be started by hand.

# 0014 — The model authors creations

**Status.** Accepted and implemented 2026-10-09. Supersedes [0003](0003-template-first-creations.md).

**Context.** 0003 made every app and widget a curated template that the model only filled with slots.
It was reliable, but it made different briefs produce the same creation: a "meal planner" and a
"scoreboard" could both come out as the same counter with different words. The template's layout was
the creation, and the model's contribution was a handful of strings. Two settings made it worse: the
sampler ran at `temperature ≈ 0.15`, so the model always chose its most likely content, and the
keyword picker routed many briefs to the same archetype.

**Decision.** Remove templates and slots. The model authors the whole artifact in the closed
vocabulary the validator already understands: the mini-app node tree and its actions, the widget rows
and kind, or the deck slides, theme and layouts. `creation_prompts.dart` states the shape and the
limits; `SpecValidator` decides whether the result can run; one repair round quotes the problems
back; a second failure throws `CreationUnusable` and the user is asked to try again rather than being
shown a generic stand-in. The sampler moves to `temperature ≈ 0.7` so two briefs do not collapse to
the same output.

**Consequences.**

- Creations are as different as their briefs, and the model can express things no template covered.
- The safety story is unchanged: generated text is still never executed, there is still no JS engine
  and no WebView, and `SafeExpression` is still the only thing that computes a value.
- Reliability now leans on the validator and the repair round rather than on construction. A weak
  model reply costs one retry before it can fail, so the failure path is a real user-visible state,
  not a hidden substitution.
- Editing is no longer a no-model slot form: "Edit with Finn" reopens the builder with the original
  brief and the model designs it again.
- Existing saved creations keep working. Their artifacts are already complete; the old `template`
  key in a stored record is ignored.

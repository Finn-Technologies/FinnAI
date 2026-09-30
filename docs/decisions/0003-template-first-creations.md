# 0003 — Creations are template-first

**Status.** Accepted and implemented 2026-09-30 (apps, widgets; decks gain themes and layouts but stay free-form).

**Context.** The model writes a whole JSON spec. A 1.6B Q4 model does this inconsistently, and the fallback is a generic counter.

**Decision.** Curated templates own layout and style: deck themes and layouts, mini-app archetypes, widget layouts. The model picks a template and fills typed slots. Generated text is still never executed and there is still no JS or WebView.

**Consequences.** Output looks good and validates reliably; less freedom. New archetypes are code, not prompts.

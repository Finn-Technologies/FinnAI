# 0002 — Search stays keyless and on-device

**Status.** Accepted 2026-09-30.

**Context.** Free hosted search APIs were reviewed. Brave removed its free tier in Feb 2026 (metered credit plus a card). Tavily, Firecrawl, LangSearch and Serper need keys with small quotas. A key shipped in the APK is extractable and its quota is shared by every user, and every query would go to a third party. FinnAI's promise is no server and no account.

**Decision.** Keep Wikipedia's API and DuckDuckGo HTML behind a `SearchProvider` interface. A power user may paste their own key (off by default, disclosed in the privacy policy). Never embed a key.

**Consequences.** Result quality is bounded by the keyless sources; the eval tracks it. The privacy policy must mention the optional key.

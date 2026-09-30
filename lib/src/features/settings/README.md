# settings — settings screen

**Entry point.** `settings_page.dart` (oversized; add new sections as separate files).

**Invariant.** Destructive actions go through `AppStateStore.deleteAllData`; add a store there when you add persisted data, and a test.

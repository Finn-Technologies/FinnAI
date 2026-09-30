# reporting — in-app problem reports

**Entry points.** `report_dialog.dart`, `report_service.dart`. See `docs/operations/REPORTING_BACKEND.md`.

**Invariant.** Intended: send only what the user can see in the dialog. Verify in `report_service.dart` before changing the payload.

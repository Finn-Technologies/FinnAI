# features/chat — rules for this directory

- `chat` is the composition root: the only feature allowed to import other features. Other features must not import `chat`; two baselined edges (`creations`, `onboarding`) exist and should be removed.
- `home_shell.dart` is 5,000+ lines and may only shrink (`tool/verify_boundaries.sh`). Add new widgets in new files here. When you touch a region of it, prefer moving that region out.
- Turn state changes are committed to the store and published synchronously before the first `await`. See `chat_generation_controller.dart` and `test/features/chat_generation_controller_test.dart`.
- An assistant message is never rendered empty. If generation produced nothing, show the retry state.
- User strings go through `L10n.of(context)` and the five `.arb` files.
- Focused tests: `flutter test --no-pub test/features/chat_generation_controller_test.dart test/features/chat_shell_ux_test.dart`.

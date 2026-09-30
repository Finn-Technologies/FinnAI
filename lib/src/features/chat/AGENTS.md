# features/chat — rules for this directory

- `chat` is the composition root: the only feature allowed to import other features. Other features must not import `chat`; two baselined edges (`creations`, `onboarding`) exist and should be removed.
- `home_shell.dart` holds `_HomeShellState` (fields, lifecycle overrides, `build`). Behaviour is in `shell/*.dart` (private extensions on the state) and widgets in `widgets/*.dart`; all are `part` files of one library, so private names are shared. Put new code in the part it belongs to, or a new part. Part files that use `setState` carry `ignore_for_file: invalid_use_of_protected_member`.
- Turn state changes are committed to the store and published synchronously before the first `await`. See `chat_generation_controller.dart` and `test/features/chat_generation_controller_test.dart`.
- A reply that finishes with no text is an error turn (`ChatGenerationController.emptyReplyError`) shown with a Retry button, never a silently removed bubble.
- User strings go through `L10n.of(context)` and the five `.arb` files.
- Focused tests: `flutter test --no-pub test/features/chat_generation_controller_test.dart test/features/chat_shell_ux_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/conversations/conversation_timestamp.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app({required Locale locale, required Widget home}) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: FluxTheme.light,
        home: home,
      );

  Widget timestampHost(Locale locale, DateTime updatedAt, DateTime now) => app(
        locale: locale,
        home: Scaffold(
          body: Center(
            child: ConversationTimestamp(updatedAt: updatedAt, now: now),
          ),
        ),
      );

  group('ConversationTimestamp', () {
    // Frozen reference clock so all three branches are pinned.
    final now = DateTime(2026, 5, 20, 15, 30);

    testWidgets('renders a 24-hour time for a conversation updated today', (
      tester,
    ) async {
      await tester.pumpWidget(
        timestampHost(const Locale('en'), DateTime(2026, 5, 20, 9, 5), now),
      );

      expect(find.text('09:05'), findsOneWidget);
    });

    testWidgets('renders month and day for an earlier day in the same year', (
      tester,
    ) async {
      final updatedAt = DateTime(2026, 3, 4, 18, 42);
      await tester.pumpWidget(
        timestampHost(const Locale('en'), updatedAt, now),
      );

      expect(
        find.text(DateFormat.MMMd('en').format(updatedAt)),
        findsOneWidget,
      );
    });

    testWidgets('renders the full date for an earlier year', (tester) async {
      final updatedAt = DateTime(2024, 11, 2, 8, 0);
      await tester.pumpWidget(
        timestampHost(const Locale('en'), updatedAt, now),
      );

      expect(
        find.text(DateFormat.yMMMd('en').format(updatedAt)),
        findsOneWidget,
      );
    });

    testWidgets('loads localized date symbols for a non-English locale', (
      tester,
    ) async {
      final updatedAt = DateTime(2026, 3, 4, 18, 42);
      await tester.pumpWidget(
        timestampHost(const Locale('de'), updatedAt, now),
      );

      // DateFormat would throw if the German date symbols were not loaded, so
      // this also proves the app's localization delegates initialize intl.
      final german = DateFormat.MMMd('de').format(updatedAt);
      expect(find.text(german), findsOneWidget);
      expect(german, isNot(DateFormat.MMMd('en').format(updatedAt)));
    });
  });

  group('conversation history list', () {
    testWidgets('shows the updated timestamp next to each conversation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = ConversationStore();
      addTearDown(store.dispose);
      final conversation = store.startNew();

      await tester.pumpWidget(
        app(
          locale: const Locale('en'),
          home: HomeShell(conversationStore: store, initializeServices: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Open menu'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final expected = DateFormat.Hm(
        'en',
      ).format(conversation.updatedAt.toLocal());
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

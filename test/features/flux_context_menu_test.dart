import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/shared/widgets/flux_context_menu.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

void main() {
  testWidgets('FluxSpringPressable responds to tap and long-press',
      (tester) async {
    bool tapped = false;
    bool longPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FluxSpringPressable(
            onTap: () => tapped = true,
            onLongPress: () => longPressed = true,
            child: const Text('Test Pressable'),
          ),
        ),
      ),
    );

    expect(find.text('Test Pressable'), findsOneWidget);

    // Tap test
    await tester.tap(find.text('Test Pressable'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    // Long press test
    await tester.longPress(find.text('Test Pressable'));
    await tester.pumpAndSettle();
    expect(longPressed, isTrue);
  });

  testWidgets('showFluxContextMenu opens with actions and dismisses',
      (tester) async {
    final GlobalKey targetKey = GlobalKey();
    bool actionTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                key: targetKey,
                onPressed: () {
                  showFluxContextMenu<void>(
                    context: context,
                    targetKey: targetKey,
                    previewWidget: const Text('Target Preview'),
                    items: [
                      FluxContextMenuItem(
                        icon: FluxIcons.edit,
                        label: 'Edit Item',
                        onTap: () => actionTapped = true,
                      ),
                      FluxContextMenuItem(
                        icon: FluxIcons.close,
                        label: 'Delete Item',
                        isDestructive: true,
                        onTap: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open context menu
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Target Preview'), findsOneWidget);
    expect(find.text('Edit Item'), findsOneWidget);
    expect(find.text('Delete Item'), findsOneWidget);

    // Tap the edit action
    await tester.tap(find.text('Edit Item'));
    await tester.pumpAndSettle();

    expect(actionTapped, isTrue);
    // Menu is closed
    expect(find.text('Edit Item'), findsNothing);
  });
}

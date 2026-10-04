import 'dart:io';
import 'dart:ui' as ui;

import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font() async {
  final bytes =
      File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync();
  final l = FontLoader('InstrumentSans')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await l.load();
}

/// The text inside the composer pill must sit on the pill's middle. InstrumentSans
/// has more space above its letters than below, which once left it 2px low.
void main() {
  setUpAll(_font);
  for (final text in ['']) {
    testWidgets('the placeholder is centred vertically in the message pill',
        (tester) async {
      tester.view.physicalSize = const Size(800, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = TextEditingController(text: text);
      final f = FocusNode();
      await tester.pumpWidget(MaterialApp(
        theme: FluxTheme.light,
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('rb'),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ChatComposer(
                controller: c,
                focusNode: f,
                blocked: false,
                onSend: () {},
                onStop: () {},
                width: 600,
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      final pill =
          tester.getRect(find.byKey(const ValueKey('chat-composer-motion')));
      late ui.Image image;
      late ByteData data;
      await tester.runAsync(() async {
        final rb = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('rb')));
        image = await rb.toImage();
        data = (await image.toByteData())!;
      });
      // dark ink inside the pill, away from the round buttons
      var minY = 9999, maxY = -1;
      for (var y = pill.top.toInt() + 2; y < pill.bottom.toInt() - 2; y++) {
        for (var x = pill.left.toInt() + 90; x < pill.left.toInt() + 330; x++) {
          final i = (y * image.width + x) * 4;
          final lum =
              (data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2)) /
                  3;
          final dark = text.isEmpty ? lum < 200 : lum < 110;
          if (dark) {
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      final inkCenter = (minY + maxY + 1) / 2;
      expect(minY, lessThan(maxY), reason: 'the hint was not painted');
      expect((inkCenter - pill.center.dy).abs(), lessThanOrEqualTo(1));
    });
  }
}

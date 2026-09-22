import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `RemoteViews` inflates only an allow-listed set of classes, and the check
/// happens in the launcher process. A layout that uses anything else fails at
/// *runtime* with
///
///   Class not allowed to be inflated android.view.View
///
/// which the launcher reports as "Can't load widget" — no crash, no Dart
/// failure, and nothing in the app's own logs. A plain `<View>` in the accent
/// bar is exactly how the home-screen widget shipped broken, so the layout is
/// checked here instead.
void main() {
  /// Layout/widget classes `RemoteViews` permits, without the package prefix.
  const allowed = <String>{
    'FrameLayout',
    'LinearLayout',
    'RelativeLayout',
    'GridLayout',
    'TextView',
    'Button',
    'ImageView',
    'ImageButton',
    'ProgressBar',
    'ViewFlipper',
    'ListView',
    'GridView',
    'StackView',
    'AdapterViewFlipper',
    'AnalogClock',
    'TextClock',
    'Chronometer',
    'CheckedTextView',
    'RadioButton',
    'RadioGroup',
    'ViewStub',
  };

  /// Strips the `android.widget.` / `android.view.` prefix, if present.
  String simpleName(String tag) {
    final parts = tag.split('.');
    return parts.last;
  }

  test('the home-screen widget layout only uses inflatable classes', () {
    final file = File('android/app/src/main/res/layout/finn_home_widget.xml');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'widget layout moved; update this guard with it',
    );

    // Comments are stripped first: they may legitimately mention a tag that
    // must not be used, including the one this guard exists to keep out.
    final markup = file
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final tags = RegExp(r'<([A-Za-z][\w.]*)')
        .allMatches(markup)
        .map((match) => simpleName(match.group(1)!))
        .toSet();

    expect(tags, isNotEmpty);
    for (final tag in tags) {
      expect(
        allowed,
        contains(tag),
        reason: 'RemoteViews cannot inflate $tag — the launcher would show '
            '"Can\'t load widget" instead of the creation',
      );
    }
  });
}

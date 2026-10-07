import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `Semantics(button: true, excludeSemantics: true, …)` hides the InkWell
/// underneath it from accessibility services, and with it the tap action:
/// TalkBack announced the "+" buttons, dialog buttons, menu items and Code's
/// status chips but could not press them (`clickable=false` in a
/// uiautomator dump). Every such node must carry its own `onTap`.
void main() {
  test('every excluded button node carries its own tap action', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('l10n/app_localizations')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(r'Semantics\(').allMatches(source)) {
        final args = _argumentsBeforeChild(source, match.end);
        if ((args.contains('button: true') || args.contains('toggled:')) &&
            args.contains('excludeSemantics: true') &&
            !args.contains('onTap')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          offenders.add('${entity.path}:${line + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}

/// The text of a `Semantics(` call's arguments up to its `child:`.
String _argumentsBeforeChild(String source, int start) {
  var depth = 1;
  var i = start;
  while (i < source.length && depth > 0) {
    final c = source[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (depth == 1 && source.startsWith('child:', i)) break;
    i++;
  }
  return source.substring(start, i);
}

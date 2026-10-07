import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/code/agent/session_grants.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';
import 'package:finn_ai/src/features/code/ui/code_changes.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

final _t = DateTime(2026, 10, 7);

CodeMessage _done(String id, CodeAction action) => CodeMessage(
      id: id,
      role: CodeRole.assistant,
      createdAt: _t,
      action: action.copyWith(status: CodeActionStatus.done),
    );

CodeSession _session(List<CodeMessage> messages) => CodeSession(
      id: 's1',
      title: 'Test',
      createdAt: _t,
      updatedAt: _t.add(Duration(seconds: messages.length)),
      messages: messages,
    );

void main() {
  group('CodeChanges', () {
    test('one entry per file, from the first before to the last after', () {
      final changes = CodeChanges.of(_session([
        _done('1', const CodeAction.write('a.txt', 'one\n')),
        _done(
          '2',
          const CodeAction.write('a.txt', 'one\ntwo\n')
              .copyWith(previous: 'one\n'),
        ),
        _done('3', const CodeAction.write('b.txt', 'x\n')),
        _done('4', const CodeAction.shell('ls')),
      ]));
      expect(changes.files.map((f) => f.path), ['a.txt', 'b.txt']);
      final a = changes.files.first;
      // Net from nothing to two lines: a new file with both lines.
      expect(a.created, isTrue);
      expect(a.added, 2);
      expect(a.removed, 0);
      expect(changes.added, 3);
    });

    test('a file put back as it was is not a change', () {
      final changes = CodeChanges.of(_session([
        _done(
          '1',
          const CodeAction.write('a.txt', 'new\n').copyWith(previous: 'old\n'),
        ),
        _done(
          '2',
          const CodeAction.write('a.txt', 'old\n').copyWith(previous: 'new\n'),
        ),
      ]));
      expect(changes.isEmpty, isTrue);
    });
  });

  testWidgets('the chip opens the review with each file and its diff',
      (tester) async {
    final changes = CodeChanges.of(_session([
      _done('1', const CodeAction.write('notes.txt', 'hi\n')),
    ]));
    await tester.pumpWidget(MaterialApp(
      theme: FluxTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: CodeChangesChip(changes: changes))),
    ));
    final chip = find.byKey(const ValueKey('code-changes-chip'));
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Changes'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('New file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('CodeSessionGrants', () {
    test('files are granted as a kind, commands by program', () {
      final grants = CodeSessionGrants();
      grants.grant('s1', const CodeAction.write('a.txt', ''));
      expect(grants.covers('s1', const CodeAction.edit('b.txt', '')), isTrue);
      expect(grants.covers('s2', const CodeAction.write('a.txt', '')), isFalse);

      grants.grant('s1', const CodeAction.shell('npm test'));
      expect(
          grants.covers('s1', const CodeAction.shell('npm run build')), isTrue);
      expect(grants.covers('s1', const CodeAction.shell('rm -rf x')), isFalse);
    });

    test('a chained or multi-line command is never granted or covered', () {
      final grants = CodeSessionGrants();
      grants.grant('s1', const CodeAction.shell('npm test'));
      for (final cmd in [
        'npm test && rm -rf x',
        'npm test; rm x',
        'npm test | sh',
        'npm test\nrm x',
        r'npm $(rm x)',
        'npm `rm x`',
        'echo hi > a.txt',
      ]) {
        expect(grants.covers('s1', CodeAction.shell(cmd)), isFalse,
            reason: cmd);
        expect(CodeSessionGrants.canGrant(CodeAction.shell(cmd)), isFalse,
            reason: cmd);
      }
      grants.grant('s2', const CodeAction.shell('mkdir a\necho b > c'));
      expect(grants.covers('s2', const CodeAction.shell('mkdir d')), isFalse);
    });

    test('the permission mode decides first', () {
      const write = CodeAction.write('a.txt', '');
      const shell = CodeAction.shell('ls');
      expect(codeNeedsApproval(CodePermissionMode.askEveryTime, write), isTrue);
      expect(codeNeedsApproval(CodePermissionMode.acceptEdits, write), isFalse);
      expect(codeNeedsApproval(CodePermissionMode.acceptEdits, shell), isTrue);
      expect(codeNeedsApproval(CodePermissionMode.autoRun, shell), isFalse);
    });
  });
}

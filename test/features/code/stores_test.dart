import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_client.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/providers/provider_store.dart';
import 'package:finn_ai/src/features/code/providers/secret_store.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('finn_code_store_');
  });

  tearDown(() async {
    // A store may still be finishing a save it did not wait for
    // (`rememberWire`); give it a moment and retry instead of racing it.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }
  });

  group('CodeSessionStore', () {
    var counter = 0;
    CodeSessionStore store() => CodeSessionStore(
          directoryProvider: () async => temp,
          idGenerator: () => 's${counter++}',
          saveDelay: const Duration(milliseconds: 1),
        );

    CodeMessage message(String id, String text, {bool user = true}) =>
        CodeMessage(
          id: id,
          role: user ? CodeRole.user : CodeRole.assistant,
          createdAt: DateTime(2026),
          text: text,
        );

    test('the first user message names the session', () {
      final s = store();
      final session = s.create();
      s.appendMessage(session.id, message('1', 'Add a README to the project'));
      expect(s.byId(session.id)!.title, 'Add a README to the project');

      s.appendMessage(session.id, message('2', 'something else'));
      expect(s.byId(session.id)!.title, 'Add a README to the project');
    });

    test('long titles are cut at a word', () {
      final title = CodeSessionStore.titleFrom(
        'Refactor the parser so that it handles nested brackets correctly',
      );
      expect(title.length, lessThanOrEqualTo(41));
      expect(title, endsWith('…'));
      expect(title, isNot(contains('correctl')));
      expect(CodeSessionStore.titleFrom('short\nsecond line'), 'short');
    });

    test('sessions persist, including actions, across a restart', () async {
      final first = store();
      final session = first.create();
      first.appendMessage(session.id, message('1', 'hi'));
      first.appendMessage(
        session.id,
        CodeMessage(
          id: '2',
          role: CodeRole.assistant,
          createdAt: DateTime(2026),
          text: 'Listing.',
          action: const CodeAction(
            kind: CodeActionKind.shell,
            command: 'ls',
            status: CodeActionStatus.done,
            output: 'a.txt',
            exitCode: 0,
          ),
          modelLabel: 'FinnAI',
        ),
      );
      first.rename(session.id, 'My project');
      first.setPinned(session.id, true);
      await first.flush();

      final second = store();
      await second.initialize();
      final loaded = second.byId(session.id)!;

      expect(loaded.title, 'My project');
      expect(loaded.pinned, isTrue);
      expect(loaded.messages.length, 2);
      final action = loaded.messages.last.action!;
      expect(action.command, 'ls');
      expect(action.output, 'a.txt');
      expect(action.status, CodeActionStatus.done);
      expect(loaded.messages.last.modelLabel, 'FinnAI');
      // Nothing is active until the user opens one.
      expect(second.active, isNull);
    });

    test('an action that was waiting when the app closed is not resumed',
        () async {
      final first = store();
      final session = first.create();
      first.appendMessage(
        session.id,
        CodeMessage(
          id: '1',
          role: CodeRole.assistant,
          createdAt: DateTime(2026),
          action: const CodeAction.shell('rm -rf x'),
        ),
      );
      await first.flush();

      final second = store();
      await second.initialize();
      expect(
        second.byId(session.id)!.messages.single.action!.status,
        CodeActionStatus.skipped,
      );
    });

    test('long output is cut on disk but kept in memory', () async {
      final s = store();
      final session = s.create();
      s.appendMessage(
        session.id,
        CodeMessage(
          id: '1',
          role: CodeRole.assistant,
          createdAt: DateTime(2026),
          action: CodeAction(
            kind: CodeActionKind.shell,
            command: 'cat big',
            status: CodeActionStatus.done,
            output: 'z' * 20000,
            exitCode: 0,
          ),
        ),
      );
      await s.flush();

      final raw = jsonDecode(
        await File('${temp.path}/code/sessions.json').readAsString(),
      ) as Map;
      final stored =
          (((raw['sessions'] as List).first as Map)['messages'] as List)
              .first['action']['output'] as String;
      expect(stored.length, CodeAction.storedOutputChars + 1);
      expect(
        (s.byId(session.id)!.messages.single.action!.output).length,
        20000,
      );
    });

    test('pinned sessions sort first, then newest', () {
      var now = DateTime(2026, 1, 1);
      final s = CodeSessionStore(
        directoryProvider: () async => temp,
        idGenerator: () => 's${counter++}',
        clock: () => now = now.add(const Duration(minutes: 1)),
      );
      final a = s.create(title: 'a');
      final b = s.create(title: 'b');
      final c = s.create(title: 'c');
      s.setPinned(a.id, true);
      expect(s.sessions.map((e) => e.title), ['a', 'c', 'b']);
      s.appendMessage(b.id, message('1', 'x'));
      expect(s.sessions.map((e) => e.title), ['a', 'b', 'c']);
      expect(c.title, 'c');
    });

    test('removing a session removes its project folder', () async {
      final s = store();
      final session = s.create();
      final workspace = await s.workspaceOf(session.id);
      await workspace.writeFile('a.txt', 'x');
      expect(workspace.root.existsSync(), isTrue);

      await s.delete(session.id);

      expect(s.byId(session.id), isNull);
      expect(s.activeId, isNull);
      expect(workspace.root.existsSync(), isFalse);
    });

    test('the oldest unpinned session is dropped past the limit', () async {
      var now = DateTime(2026, 1, 1);
      final s = CodeSessionStore(
        directoryProvider: () async => temp,
        idGenerator: () => 's${counter++}',
        clock: () => now = now.add(const Duration(minutes: 1)),
      );
      final first = s.create(title: 'oldest');
      s.setPinned(first.id, true);
      for (var i = 0; i < CodeSessionStore.maxSessions; i++) {
        s.create(title: 'n$i');
      }
      expect(s.sessions.length, CodeSessionStore.maxSessions);
      expect(s.byId(first.id), isNotNull, reason: 'pinned survives');
      expect(s.sessions.any((e) => e.title == 'n0'), isFalse);
      await s.flush();
    });

    test('with none open, the most recent session stands in for Files', () {
      var now = DateTime(2026, 1, 1);
      final s = CodeSessionStore(
        directoryProvider: () async => temp,
        idGenerator: () => 's${counter++}',
        clock: () => now = now.add(const Duration(minutes: 1)),
      );
      expect(s.activeOrLatest, isNull);
      s.create(title: 'older');
      final newer = s.create(title: 'newer');
      s.clearActive();
      expect(s.active, isNull);
      expect(s.activeOrLatest!.id, newer.id);
    });

    test('clearActive shows the blank screen without losing anything', () {
      final s = store();
      final session = s.create();
      s.clearActive();
      expect(s.active, isNull);
      expect(s.byId(session.id), isNotNull);
      s.activate(session.id);
      expect(s.active!.id, session.id);
    });

    test('a corrupt file starts empty instead of failing', () async {
      await Directory('${temp.path}/code').create(recursive: true);
      await File('${temp.path}/code/sessions.json').writeAsString('{not json');
      final s = store();
      await s.initialize();
      expect(s.initialized, isTrue);
      expect(s.sessions, isEmpty);
    });

    test('deleting storage clears sessions and folders', () async {
      final s = store();
      final session = s.create();
      await (await s.workspaceOf(session.id)).writeFile('a.txt', 'x');
      await s.flush();

      final failures = await s.deleteStorage();

      expect(failures, isEmpty);
      expect(s.sessions, isEmpty);
      expect(Directory('${temp.path}/code').existsSync(), isFalse);
    });
  });

  group('CodeSettingsStore', () {
    test('defaults are the cautious ones', () {
      final s = CodeSettingsStore(directoryProvider: () async => temp);
      expect(s.settings.permissionMode, CodePermissionMode.acceptEdits);
      expect(s.settings.allowNetwork, isFalse);
      expect(s.settings.maxSteps, isNull);
    });

    test('changes persist and bad stored values are clamped', () async {
      final first = CodeSettingsStore(directoryProvider: () async => temp);
      await first.update((s) => s.copyWith(
            permissionMode: CodePermissionMode.autoRun,
            maxSteps: () => 12,
            allowNetwork: true,
          ));

      final second = CodeSettingsStore(directoryProvider: () async => temp);
      await second.initialize();
      expect(second.settings.permissionMode, CodePermissionMode.autoRun);
      expect(second.settings.maxSteps, 12);
      expect(second.settings.allowNetwork, isTrue);

      await File('${temp.path}/code/settings.json').writeAsString(
        jsonEncode({'permission': 'nonsense', 'maxSteps': 9999, 'timeout': 1}),
      );
      final third = CodeSettingsStore(directoryProvider: () async => temp);
      await third.initialize();
      expect(third.settings.permissionMode, CodePermissionMode.acceptEdits);
      expect(third.settings.maxSteps, 50);
      expect(third.settings.commandTimeoutSeconds, 5);
    });
  });

  group('CodeProviderStore', () {
    late MemoryCodeSecretStore secrets;

    CodeProviderStore store({http.Client? client}) => CodeProviderStore(
          secrets: secrets,
          client: CodeProviderClient(
            client: client ?? MockClient((_) async => http.Response('', 500)),
          ),
          directoryProvider: () async => temp,
          clock: () => DateTime.utc(2026, 10, 3),
        );

    setUp(() => secrets = MemoryCodeSecretStore());

    test('the on-device model is the default and always configured', () {
      final s = store();
      expect(s.active, CodeModelRef.local);
      expect(s.isConfigured(CodeProvider.finn), isTrue);
      expect(s.isConfigured(CodeProvider.openRouter), isFalse);
    });

    test('a key goes to secure storage; only its last four are on disk',
        () async {
      final s = store();
      await s.saveKey(CodeProvider.openRouter, '  sk-or-v1-abcdef123456  ');

      expect(s.hasKey(CodeProvider.openRouter), isTrue);
      expect(s.settingsOf(CodeProvider.openRouter).keyHint, '3456');
      expect(await s.keyFor(CodeProvider.openRouter), 'sk-or-v1-abcdef123456');
      expect(s.isConfigured(CodeProvider.openRouter), isTrue);

      final disk =
          await File('${temp.path}/code/providers.json').readAsString();
      expect(disk, isNot(contains('abcdef')));
      expect(disk, isNot(contains('sk-or')));
      expect(disk, contains('3456'));
    });

    test('an empty key is refused and the local model cannot have one',
        () async {
      final s = store();
      await expectLater(
        s.saveKey(CodeProvider.openRouter, '   '),
        throwsArgumentError,
      );
      await expectLater(s.saveKey(CodeProvider.finn, 'x'), throwsArgumentError);
    });

    test('removing a key forgets models and falls back to the local model',
        () async {
      final s = store(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'data': [
                  {'id': 'm1', 'name': 'M1'},
                ],
              }),
              200,
            )),
      );
      await s.saveKey(CodeProvider.openRouter, 'key-1234');
      await s.refreshModels(CodeProvider.openRouter);
      await s.select(const CodeModelRef(CodeProvider.openRouter, 'm1'));
      expect(s.active.provider, CodeProvider.openRouter);

      await s.removeKey(CodeProvider.openRouter);

      expect(s.hasKey(CodeProvider.openRouter), isFalse);
      expect(await s.keyFor(CodeProvider.openRouter), isNull);
      expect(s.settingsOf(CodeProvider.openRouter).models, isEmpty);
      expect(s.active, CodeModelRef.local);
    });

    test('selecting a provider that is not set up is ignored', () async {
      final s = store();
      await s.select(const CodeModelRef(CodeProvider.commandCode, 'x'));
      expect(s.active, CodeModelRef.local);
    });

    test('models are fetched live, cached, and survive a restart', () async {
      var calls = 0;
      String? auth;
      final client = MockClient((request) async {
        calls++;
        auth = request.headers['authorization'];
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'a/free-model:free',
                'name': 'A free',
                'context_length': 8192,
                'pricing': {'prompt': '0', 'completion': '0'},
              },
            ],
          }),
          200,
        );
      });
      final first = store(client: client);
      await first.saveKey(CodeProvider.openRouter, 'key-9999');

      final models = await first.refreshModels(CodeProvider.openRouter);
      expect(models.single.free, isTrue);
      expect(auth, 'Bearer key-9999');
      expect(first.availableModels.single.id, 'a/free-model:free');
      expect(
        first.modelFor(
            const CodeModelRef(CodeProvider.openRouter, 'a/free-model:free')),
        isNotNull,
      );

      // Fresh list: ensureModels does not call again.
      await first.ensureModels(CodeProvider.openRouter);
      expect(calls, 1);

      final second = store(client: client);
      await second.initialize();
      expect(second.settingsOf(CodeProvider.openRouter).models.length, 1);
      expect(second.hasKey(CodeProvider.openRouter), isTrue);
    });

    test('a failed refresh keeps the old list and records the error', () async {
      var fail = false;
      final client = MockClient((request) async => fail
          ? http.Response('{"error":{"message":"down"}}', 503)
          : http.Response(
              jsonEncode({
                'data': [
                  {'id': 'm'},
                ],
              }),
              200,
            ));
      final s = store(client: client);
      await s.saveKey(CodeProvider.openCodeZen, 'k');
      await s.refreshModels(CodeProvider.openCodeZen);

      fail = true;
      await expectLater(
        s.refreshModels(CodeProvider.openCodeZen),
        throwsA(isA<ProviderException>()),
      );

      expect(s.settingsOf(CodeProvider.openCodeZen).models.length, 1);
      expect(
          s.errorOf(CodeProvider.openCodeZen)!.failure, ProviderFailure.server);
      expect(s.isLoadingModels(CodeProvider.openCodeZen), isFalse);
    });

    test('OpenRouter allowance is stored; other providers have none', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/key')) {
          return http.Response(
            jsonEncode({
              'data': {'limit': 10, 'limit_remaining': 4.0, 'usage': 6.0},
            }),
            200,
          );
        }
        return http.Response('{}', 403);
      });
      final s = store(client: client);
      await s.saveKey(CodeProvider.openRouter, 'k');
      await s.saveKey(CodeProvider.commandCode, 'k');

      final allowance = await s.refreshAllowance(CodeProvider.openRouter);
      expect(allowance!.remaining, 4.0);
      expect(s.settingsOf(CodeProvider.openRouter).allowance!.used, 6.0);
      expect(await s.refreshAllowance(CodeProvider.commandCode), isNull);
      expect(CodeProvider.commandCode.hasAllowanceApi, isFalse);
    });

    test('a new key clears the old account\'s allowance', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'data': {'limit': null, 'usage': 1.0},
            }),
            200,
          ));
      final s = store(client: client);
      await s.saveKey(CodeProvider.openRouter, 'old-key');
      await s.refreshAllowance(CodeProvider.openRouter);
      expect(s.settingsOf(CodeProvider.openRouter).allowance, isNotNull);

      await s.saveKey(CodeProvider.openRouter, 'new-key');
      expect(s.settingsOf(CodeProvider.openRouter).allowance, isNull);
    });

    test('the remembered request shape is tried first', () {
      final s = store();
      const model = CodeModel(
        provider: CodeProvider.openCodeZen,
        id: 'qwen3.8-max',
        name: 'qwen3.8-max',
        wires: [CodeWire.chatCompletions, CodeWire.anthropicMessages],
      );
      expect(s.withRememberedWire(model).wires.first, CodeWire.chatCompletions);

      s.rememberWire(
          CodeProvider.openCodeZen, model.id, CodeWire.anthropicMessages);
      expect(s.withRememberedWire(model).wires,
          [CodeWire.anthropicMessages, CodeWire.chatCompletions]);
    });

    test('cloud acknowledgement is remembered per provider', () async {
      final first = store();
      expect(
          first.settingsOf(CodeProvider.openRouter).acknowledgedCloud, isFalse);
      await first.acknowledgeCloud(CodeProvider.openRouter);

      final second = store();
      await second.initialize();
      expect(
          second.settingsOf(CodeProvider.openRouter).acknowledgedCloud, isTrue);
      expect(second.settingsOf(CodeProvider.commandCode).acknowledgedCloud,
          isFalse);
    });

    test('a custom server needs an address before it is configured', () async {
      final s = store();
      await s.saveKey(CodeProvider.custom, 'k');
      expect(s.isConfigured(CodeProvider.custom), isFalse);

      expect(await s.setCustomBaseUrl('ftp://nope'), isFalse);
      expect(await s.setCustomBaseUrl('https://llm.example.com/v1/'), isTrue);
      expect(s.baseUrlOf(CodeProvider.custom), 'https://llm.example.com/v1');
      expect(s.isConfigured(CodeProvider.custom), isTrue);
    });

    test('a custom server needs no key', () async {
      final s = store();
      await s.setCustomBaseUrl('http://192.168.1.20:11434/v1');
      expect(s.isConfigured(CodeProvider.custom), isTrue);
      expect(CodeProvider.custom.keyRequired, isFalse);
      expect(CodeProvider.openRouter.keyRequired, isTrue);
    });

    test('delete-all removes keys, files and the selection', () async {
      final s = store();
      await s.saveKey(CodeProvider.openRouter, 'key-1234');
      await s.saveKey(CodeProvider.commandCode, 'key-5678');

      final failures = await s.deleteStorage();

      expect(failures, isEmpty);
      expect(secrets.values, isEmpty);
      expect(s.hasKey(CodeProvider.openRouter), isFalse);
      expect(s.active, CodeModelRef.local);
      expect(File('${temp.path}/code/providers.json').existsSync(), isFalse);
    });
  });

  group('base URL validation', () {
    String? v(String s) => CodeProviderStore.validateBaseUrl(s);

    test('https is accepted and a trailing slash removed', () {
      expect(v('https://api.example.com/v1'), 'https://api.example.com/v1');
      expect(v(' https://api.example.com/v1/ '), 'https://api.example.com/v1');
      expect(v('https://api.example.com'), 'https://api.example.com');
    });

    test('plain http only for the user\'s own machines', () {
      expect(v('http://localhost:11434/v1'), isNotNull);
      expect(v('http://127.0.0.1:8080/v1'), isNotNull);
      expect(v('http://10.0.2.2:8080/v1'), isNotNull);
      expect(v('http://192.168.1.5:1234/v1'), isNotNull);
      expect(v('http://172.20.0.4/v1'), isNotNull);
      expect(v('http://mac-studio.local:8080/v1'), isNotNull);

      expect(v('http://api.example.com/v1'), isNull);
      expect(v('http://8.8.8.8/v1'), isNull);
      expect(v('http://172.32.0.1/v1'), isNull);
      expect(v('http://192.169.0.1/v1'), isNull);
    });

    test('anything that could leak or confuse is refused', () {
      expect(v(''), isNull);
      expect(v('api.example.com/v1'), isNull);
      expect(v('ftp://api.example.com'), isNull);
      expect(v('https://user:pass@api.example.com/v1'), isNull);
      expect(v('https://api.example.com/v1?key=abc'), isNull);
      expect(v('https://api.example.com/v1#frag'), isNull);
      expect(v('https://'), isNull);
    });
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';

class _Keys implements SecureKeyStorage {
  final _data = <String, Uint8List>{};
  @override
  Future<Uint8List?> readKey(String alias) async => _data[alias];
  @override
  Future<void> writeKey(String alias, Uint8List key) async =>
      _data[alias] = key;
  @override
  Future<void> deleteKey(String alias) async => _data.remove(alias);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a flow result is added without taking over the open conversation',
      () async {
    final directory = await Directory.systemTemp.createTemp('finn_standalone');
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = ConversationStore(
      keyStorage: _Keys(),
      directoryProvider: () async => directory,
    );
    await store.initialize();
    final reading = store.startNew();

    final result = store.addStandaloneReply(
      title: 'Morning brief',
      text: '- a\n- b',
      sources: [
        WebSource(title: 't', url: Uri.parse('https://e.com'), snippet: 's'),
      ],
    );

    expect(store.active?.id, reading.id, reason: 'the reader is not moved');
    final added = store.conversationById(result.id)!;
    expect(added.title, 'Morning brief');
    expect(added.messages.single.role, ConversationRole.assistant);
    expect(added.messages.single.status, ConversationMessageStatus.complete);
    expect(added.messages.single.sources, hasLength(1));
    expect(store.conversations.first.id, result.id, reason: 'newest first');
  });
}

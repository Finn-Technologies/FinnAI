import 'package:flutter_test/flutter_test.dart';
import 'package:flux_local/src/conversations/conversation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationStore Rename & Delete Tests', () {
    test('renameConversation updates title and notifies listeners', () {
      final store = ConversationStore.instance;
      final conv = store.startNew();
      final originalId = conv.id;

      bool notified = false;
      store.addListener(() => notified = true);

      store.renameConversation(originalId, 'Project Roadmap Notes');

      final updated = store.conversations.firstWhere((c) => c.id == originalId);
      expect(updated.title, 'Project Roadmap Notes');
      expect(notified, true);
    });

    test('deleteConversation removes item and switches active id if needed', () {
      final store = ConversationStore.instance;
      final conv1 = store.startNew();
      final conv2 = store.startNew();

      expect(store.active?.id, conv2.id);

      store.deleteConversation(conv2.id);

      expect(store.conversations.any((c) => c.id == conv2.id), false);
      expect(store.active?.id, conv1.id);
    });
  });
}

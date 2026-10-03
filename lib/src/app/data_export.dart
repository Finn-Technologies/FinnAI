import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/creations/home_screen_service.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/features/you/you_profile_store.dart';

/// Hands a file to the system share sheet. Returns false when it could not be.
Future<bool> shareLocalFile(String path, String mimeType, String label) async {
  try {
    return await HomeScreenService().shareFile(
      path: path,
      mimeType: mimeType,
      label: label,
    );
  } on Object {
    return false;
  }
}

/// Writes everything the user has made in FinnAI to one JSON file and hands it
/// to the system share sheet. Returns false when it could not be shared.
///
/// Lives in `app/` because it reads from several features, which no single
/// feature is allowed to do.
Future<bool> exportEverything() async {
  try {
    final data = <String, Object?>{
      'exportedAt': DateTime.now().toIso8601String(),
      'chats': [
        for (final conversation in ConversationStore.instance.conversations)
          {
            'title': conversation.title,
            'messages': [
              for (final message in conversation.messages)
                {'role': message.role.name, 'text': message.text},
            ],
          },
      ],
      'you': YouProfileStore.instance.profile.toJson(),
      'flows': [
        for (final flow in FlowsStore.instance.flows)
          {'name': flow.name, 'description': flow.description},
      ],
    };
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/finnai-export.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return await HomeScreenService().shareFile(
      path: file.path,
      mimeType: 'application/json',
      label: 'FinnAI',
    );
  } on Object {
    return false;
  }
}

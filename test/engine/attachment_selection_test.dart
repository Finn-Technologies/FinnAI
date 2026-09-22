import 'dart:typed_data';

import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only the newest attachment may be fed back into a prompt. Re-sending every
/// historic image as media is how a document attachment got ignored: the model
/// was handed the older picture with a media marker right before the question,
/// answered about the picture, and never mentioned the file.
void main() {
  LocalChatTurn text(String content) =>
      LocalChatTurn(role: 'user', content: content);
  LocalChatTurn attached(String content, String path) =>
      LocalChatTurn(role: 'user', content: content, imagePath: path);

  test('empty history has no attachment', () {
    expect(newestAttachmentTurn(const <LocalChatTurn>[]), isNull);
  });

  test('a text-only history has no attachment', () {
    expect(
      newestAttachmentTurn([text('hello'), text('what is the capital?')]),
      isNull,
    );
  });

  test('a document is the attachment', () {
    final history = [text('summarise this'), attached('', '/tmp/notes.txt')];
    expect(newestAttachmentTurn(history)?.imagePath, '/tmp/notes.txt');
  });

  test('a document attached after a photo wins over the photo', () {
    final history = [
      attached('what colour is the circle', '/tmp/photo.jpg'),
      text('The circle in the image is blue.'),
      attached('what is blocking the rollout', '/tmp/notes.txt'),
    ];
    expect(
      newestAttachmentTurn(history)?.imagePath,
      '/tmp/notes.txt',
      reason: 'the file the user just attached must outrank an older image',
    );
  });

  test('a follow-up with no attachment keeps the previous image', () {
    final history = [
      attached('what colour is the circle', '/tmp/photo.jpg'),
      text('The circle in the image is blue.'),
      text('and the shape?'),
    ];
    expect(newestAttachmentTurn(history)?.imagePath, '/tmp/photo.jpg');
  });

  test('in-memory bytes count as an attachment without a path', () {
    final history = [
      text('what is this'),
      LocalChatTurn(
        role: 'user',
        content: 'what is this',
        imageBytes: Uint8List.fromList(const [1, 2, 3]),
      ),
    ];
    expect(newestAttachmentTurn(history)?.imageBytes, isNotNull);
  });

  test('an empty path is not an attachment', () {
    expect(newestAttachmentTurn([attached('hi', '')]), isNull);
  });
}

import 'dart:io';

import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('All FigmaAssets paths exist in the local filesystem', () {
    final paths = [
      FigmaAssets.back,
      FigmaAssets.welcomeArrow,
      FigmaAssets.privacy,
      FigmaAssets.magic,
      FigmaAssets.security,
      FigmaAssets.download,
      FigmaAssets.menu,
      FigmaAssets.modelChevron,
      FigmaAssets.send,
      FigmaAssets.activeSend,
      FigmaAssets.add,
      FigmaAssets.sidebarActions,
      FigmaAssets.sidebarCreations,
      FigmaAssets.sidebarYou,
      FigmaAssets.sidebarFlows,
      FigmaAssets.noHistory,
      FigmaAssets.creationBack,
      FigmaAssets.creationSend,
      FigmaAssets.creationAdd,
    ];

    for (final path in paths) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Asset file does not exist at path: $path',
      );
    }
  });
}

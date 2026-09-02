import 'package:finn_ai/src/openharmony/openharmony_path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [OpenHarmonyPathProvider] against a faked OHOS method channel.
///
/// On device the channel `plugins.flutter.io/path_provider` is answered by
/// EntryAbility's inline handler (see
/// ohos/entry/src/main/ets/entryability/EntryAbility.ets); the mock below
/// stands in for it. Every getter must consult the channel first and only
/// fall back to the hardcoded el2 paths when the channel throws, returns
/// null, or returns an empty string.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The handler registry is keyed by channel name, so a fresh channel with
  // the same name reaches the private one used by the provider.
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const downloads = '/data/storage/el2/base/haps/entry/downloads';
  const files = '/data/storage/el2/base/haps/entry/files';

  void stub(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => stub(null));

  test('getDownloadsPath returns the path reported by the OHOS channel',
      () async {
    stub((call) async {
      expect(call.method, 'getDownloadsPath');
      return downloads;
    });

    final path = await OpenHarmonyPathProvider().getDownloadsPath();
    expect(path, downloads);
  });

  test('getDownloadsPath falls back to the files dir when unimplemented',
      () async {
    // EntryAbility answers getDownloadsPath with notImplemented() today,
    // which surfaces here as a MissingPluginException.
    stub((call) async => throw MissingPluginException());

    final path = await OpenHarmonyPathProvider().getDownloadsPath();
    expect(path, files);
  });

  test('getDownloadsPath ignores empty channel results', () async {
    stub((call) async => '');

    final path = await OpenHarmonyPathProvider().getDownloadsPath();
    expect(path, files);
  });

  test('every getter consults the channel before falling back', () async {
    final methods = <String>[];
    stub((call) async {
      methods.add(call.method);
      return null;
    });
    final provider = OpenHarmonyPathProvider();

    await provider.getTemporaryPath();
    await provider.getApplicationSupportPath();
    await provider.getApplicationDocumentsPath();
    await provider.getLibraryPath();
    await provider.getExternalStoragePath();
    await provider.getDownloadsPath();

    expect(methods, [
      'getTemporaryPath',
      'getApplicationSupportPath',
      'getApplicationDocumentsPath',
      'getLibraryPath',
      'getExternalStoragePath',
      'getDownloadsPath',
    ]);
  });
}

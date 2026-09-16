import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/creations/creation_palette.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';

/// Talks to the Android launcher-widget and sharing bridge.
///
/// Every call degrades to `false` when the platform has no implementation, so
/// callers can offer the affordance unconditionally and hide it based on
/// [isSupported]. OpenHarmony has no `AppWidget` API at all, so it is Android
/// only — see `docs/architecture/CREATIONS.md`.
class HomeScreenService {
  HomeScreenService({
    MethodChannel? channel,
    CreationStore? store,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _store = store ?? CreationStore.instance;

  static const String channelName = 'finn_ai/home_screen';

  static final HomeScreenService instance = HomeScreenService();

  /// Sub-directory of the creations folder that native reads specs from.
  ///
  /// The path is deliberately derivable from `filesDir` on the Kotlin side, so
  /// an `AppWidgetProvider` can render when the Flutter engine is not running.
  static const String widgetSpecFolder = 'home_widgets';

  final MethodChannel _channel;
  final CreationStore _store;

  /// Whether this device can host launcher widgets.
  Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    return (await _invoke<bool>('isSupported')) ?? false;
  }

  /// Writes [spec] where the widget provider will look for it and returns the
  /// file path, which is what gets handed to native.
  Future<String> writeWidgetSpec({
    required String creationId,
    required HomeWidgetSpec spec,
  }) async {
    final directory = await _widgetSpecsDirectory();
    final file = File('${directory.path}/${_safeName(creationId)}.json');
    final payload = <String, Object?>{
      'creationId': creationId,
      'title': spec.title,
      // Resolved here so Kotlin needs no colour table of its own.
      'accent': CreationPalette.pastel(spec.accent).toARGB32(),
      'rows': [
        for (final row in spec.rows) {'label': row.label, 'value': row.value},
      ],
      'footer': spec.footer,
    };
    await file.writeAsString(jsonEncode(payload), flush: true);
    return file.path;
  }

  /// Pins a widget to the launcher, using [spec] as its content.
  ///
  /// Android assigns the widget id only after the pin is accepted, so this
  /// stages the spec as "pending" and the provider claims it on first update.
  Future<bool> addWidgetToHomeScreen({
    required String creationId,
    required HomeWidgetSpec spec,
    required String label,
  }) async {
    final path = await writeWidgetSpec(creationId: creationId, spec: spec);
    final staged = await _invoke<bool>('stagePendingWidget', {
      'specPath': path,
      'label': label,
    });
    if (staged != true) return false;
    return await _invoke<bool>('requestPinWidget') ?? false;
  }

  /// Pins a launcher shortcut that deep-links into a creation.
  Future<bool> addCreationShortcut({
    required String creationId,
    required String label,
  }) async {
    return await _invoke<bool>('requestPinShortcut', {
          'shortcutId': 'creation-${_safeName(creationId)}',
          'creationId': creationId,
          'label': label,
        }) ??
        false;
  }

  /// Asks every placed widget to re-render from its stored spec.
  Future<void> refreshWidgets() async {
    await _invoke<bool>('refreshWidgets');
  }

  /// Opens the system share sheet for a file Finn wrote.
  Future<bool> shareFile({
    required String path,
    required String mimeType,
    String? label,
  }) async {
    return await _invoke<bool>('shareFile', {
          'path': path,
          'mimeType': mimeType,
          'label': label,
        }) ??
        false;
  }

  Future<Directory> _widgetSpecsDirectory() async {
    final root = await _store.exportsDirectory();
    final directory = Directory('${root.parent.path}/$widgetSpecFolder');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _safeName(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      // Desktop, tests and OpenHarmony export no such channel.
      return null;
    } on PlatformException {
      return null;
    }
  }
}

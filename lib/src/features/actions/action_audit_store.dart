import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/actions/device_action.dart';

/// A record that the app acted on the user's device.
///
/// The approval path is one tap: a pill under an assistant sentence runs
/// `executor.execute` immediately. That is the right trade — a second dialog
/// on top of a confirmation is one too many taps — but it means the only trace
/// of what the app did on their phone was the `pendingAction` on the message
/// that proposed it. Once that was cleared, nothing recorded that the alarm had
/// been set.
///
/// This is that record.
///
/// **It holds no prompt text and no assistant text.** An audit log is written
/// to disk and read back on device; what belongs in it is *which action ran*,
/// *whether it was approved or refused*, and *when*. What the user typed
/// already lives in the encrypted conversation store, under a key the user
/// controls, and duplicating it into a plaintext log would make the log the
/// weaker place to keep a secret.
class ActionAuditStore extends ChangeNotifier {
  ActionAuditStore({this.directoryProvider});

  static final instance = ActionAuditStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  List<ActionAuditEntry> _entries = const [];
  bool _initialized = false;
  Future<void>? _initializeJob;
  Future<void> _writeQueue = Future<void>.value();

  /// How many entries are kept.
  ///
  /// Bounded because this is an append-only file on a device where storage is
  /// user-visible space, and because an audit log nobody reads past the last
  /// few days is just a file.
  static const int maxEntries = 100;

  List<ActionAuditEntry> get entries => List.unmodifiable(_entries);
  bool get initialized => _initialized;

  /// The most recent entries for one action, newest first.
  List<ActionAuditEntry> entriesFor(String action) =>
      List.unmodifiable(_entries.where((e) => e.actionName == action));

  Future<void> initialize() async {
    if (_initialized) return;
    final running = _initializeJob;
    if (running != null) return running;
    final job = _initialize();
    _initializeJob = job;
    try {
      await job;
    } finally {
      if (identical(_initializeJob, job)) _initializeJob = null;
    }
  }

  Future<void> _initialize() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          _entries = [
            for (final item in decoded)
              if (item is Map)
                ActionAuditEntry.fromJson(item.cast<String, Object?>()),
          ].take(maxEntries).toList(growable: false);
        }
      }
    } catch (error) {
      // A missing or corrupt audit log must never cost the user their app.
      debugPrint('FINN_AUDIT read failed: $error');
      _entries = const [];
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Records that an action was approved and run.
  Future<void> recordRan(
    DeviceActionInvocation invocation,
    DeviceActionResult result, {
    required String source,
  }) =>
      _record(
        ActionAuditEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          actionName: invocation.action.name,
          actionTier: invocation.action.tier.name,
          outcome: result.outcome.name,
          source: source,
          ranAt: DateTime.now(),
        ),
      );

  /// Records that an action was refused.
  ///
  /// A refusal is the more important half of the log: an action the user
  /// declined is exactly the one they would want to know about later.
  Future<void> recordRefused(
    DeviceActionInvocation invocation, {
    required String source,
  }) =>
      _record(
        ActionAuditEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          actionName: invocation.action.name,
          actionTier: invocation.action.tier.name,
          outcome: 'refused',
          source: source,
          ranAt: DateTime.now(),
        ),
      );

  Future<void> _record(ActionAuditEntry entry) async {
    _entries = [entry, ..._entries].take(maxEntries).toList(growable: false);
    notifyListeners();
    // Serialised: two approvals in quick succession must not interleave their
    // writes and leave a half-written file.
    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _file();
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
          jsonEncode([for (final e in _entries) e.toJson()]),
          flush: true,
        );
        await temporary.rename(file.path);
      } catch (error) {
        debugPrint('FINN_AUDIT write failed: $error');
      }
    });
    await _writeQueue;
  }

  /// Removes the log entirely. Wired into "delete all local data".
  Future<void> deleteAll() async {
    _entries = const [];
    notifyListeners();
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
      final temporary = File('${file.path}.tmp');
      if (await temporary.exists()) await temporary.delete();
    } catch (error) {
      debugPrint('FINN_AUDIT delete failed: $error');
    }
  }

  @visibleForTesting
  Future<File> fileForTest() => _file();

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}action_audit.json',
    );
  }
}

/// One line of the audit log.
@immutable
class ActionAuditEntry {
  const ActionAuditEntry({
    required this.id,
    required this.actionName,
    required this.actionTier,
    required this.outcome,
    required this.source,
    required this.ranAt,
  });

  final String id;

  /// The catalog action's name, e.g. `set_alarm`.
  ///
  /// Only the *name* is recorded, never the arguments — a `dial` action's
  /// number and a `compose_sms` action's recipient are the user's data, and
  /// they are not needed to answer "what has this app done to my phone".
  final String actionName;

  /// `execute` or `open`, so a reader can tell a real state change from
  /// merely raising a screen.
  final String actionTier;

  /// `performed` / `opened` / `unavailable` / `failed` / `refused`.
  final String outcome;

  /// Where the request came from: `chat`, `flow`, or `assistant`.
  final String source;

  final DateTime ranAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'action': actionName,
        'tier': actionTier,
        'outcome': outcome,
        'source': source,
        'at': ranAt.toIso8601String(),
      };

  factory ActionAuditEntry.fromJson(Map<String, Object?> json) =>
      ActionAuditEntry(
        id: json['id']?.toString() ?? '',
        actionName: json['action']?.toString() ?? '',
        actionTier: json['tier']?.toString() ?? '',
        outcome: json['outcome']?.toString() ?? '',
        source: json['source']?.toString() ?? 'chat',
        ranAt: DateTime.tryParse(json['at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

/// What came back from one command.
@immutable
class ShellResult {
  const ShellResult({
    required this.exitCode,
    required this.output,
    this.truncated = false,
    this.timedOut = false,
    this.denied,
    this.deniedDetail = '',
    this.duration = Duration.zero,
  });

  /// A command the policy refused to start.
  const ShellResult.denied(PolicyReason reason, [String detail = ''])
      : exitCode = 126,
        output = '',
        truncated = false,
        timedOut = false,
        denied = reason,
        deniedDetail = detail,
        duration = Duration.zero;

  final int exitCode;

  /// Standard output and standard error, in the order they arrived.
  final String output;

  /// True when [output] was cut at the size cap.
  final bool truncated;
  final bool timedOut;
  final PolicyReason? denied;
  final String deniedDetail;
  final Duration duration;

  bool get ok => denied == null && !timedOut && exitCode == 0;
}

/// Starts a process. Replaced in tests; the real one is [Process.start].
typedef ProcessLauncher = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment,
});

/// Runs shell commands in a session's project folder.
///
/// This is a workspace shell, not a virtual machine: the commands are the
/// phone's own (`ls`, `grep`, `sed`, `cat`…), run as the app's unprivileged
/// user with `HOME` and the working directory set to the project folder, a
/// timeout, a size cap on what comes back, and [CommandPolicy] in front.
/// `docs/decisions/0010-finnai-code.md` explains why that is the boundary and
/// what a real Linux environment would need.
class ShellSandbox {
  ShellSandbox({
    required this.workspace,
    CommandPolicy? policy,
    this.timeout = const Duration(seconds: 20),
    this.maxOutputBytes = 32 * 1024,
    ProcessLauncher? launcher,
    String? shellPath,
  })  : policy = policy ?? const CommandPolicy(),
        _launcher = launcher ?? _startProcess,
        _shellPath = shellPath ?? defaultShellPath;

  final CodeWorkspace workspace;
  final CommandPolicy policy;
  final Duration timeout;
  final int maxOutputBytes;
  final ProcessLauncher _launcher;
  final String _shellPath;

  /// Whether this platform lets an app start a shell at all. iOS and
  /// HarmonyOS do not (on HarmonyOS 6.1 starting `/bin/sh` from the app is
  /// "Permission denied", checked on the API 24 emulator), so FinnAI Code
  /// there runs commands only in the emulated container, or not at all.
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isLinux || Platform.isMacOS);

  static String get defaultShellPath =>
      Platform.isAndroid ? '/system/bin/sh' : '/bin/sh';

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
  }) =>
      Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
      );

  /// The environment a command sees. Nothing is inherited from the app: its
  /// variables are not the model's business.
  Map<String, String> get environment {
    final root = workspace.root.path;
    return {
      'HOME': root,
      'PWD': root,
      'TMPDIR': '$root/${CodeWorkspace.scratchDir}',
      'TERM': 'dumb',
      'LANG': 'C.UTF-8',
      'PATH': Platform.isAndroid
          ? '/system/bin:/system/xbin'
          : '/usr/bin:/bin:/usr/sbin:/sbin',
      'PS1': r'$ ',
    };
  }

  Future<ShellResult> run(String command, {Duration? limit}) async {
    if (!supported) {
      return const ShellResult(
        exitCode: 127,
        output: 'Commands cannot run on this device.',
      );
    }
    await workspace.ensureCreated();
    final verdict = policy.check(command, workspaceRoot: workspace.root.path);
    if (!verdict.allowed) {
      return ShellResult.denied(verdict.reason!, verdict.detail);
    }

    final started = DateTime.now();
    final Process process;
    try {
      process = await _launcher(
        _shellPath,
        ['-c', command],
        workingDirectory: workspace.root.path,
        environment: environment,
        includeParentEnvironment: false,
      );
    } on ProcessException catch (error) {
      return ShellResult(exitCode: 127, output: error.message);
    }
    // Nothing is ever written to the child, and closing stdin up front stops
    // a command that reads it (`cat`, `read`) from waiting forever.
    unawaited(process.stdin.close().catchError((Object _) {}));

    final buffer = BytesBuilder(copy: false);
    var truncated = false;
    void collect(List<int> chunk) {
      final room = maxOutputBytes - buffer.length;
      if (room <= 0) {
        truncated = true;
        return;
      }
      if (chunk.length > room) {
        buffer.add(chunk.sublist(0, room));
        truncated = true;
      } else {
        buffer.add(chunk);
      }
    }

    // Both streams are always drained, even past the cap, so a chatty command
    // is never blocked on a full pipe.
    final drained = Future.wait([
      process.stdout.forEach(collect),
      process.stderr.forEach(collect),
    ]);

    var timedOut = false;
    final timer = Timer(limit ?? timeout, () {
      timedOut = true;
      process.kill(ProcessSignal.sigkill);
    });
    final exitCode = await process.exitCode;
    timer.cancel();
    try {
      await drained.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // A background child kept a pipe open; what arrived is what we have.
    }

    return ShellResult(
      exitCode: timedOut ? 124 : exitCode,
      output: utf8.decode(buffer.takeBytes(), allowMalformed: true),
      truncated: truncated,
      timedOut: timedOut,
      duration: DateTime.now().difference(started),
    );
  }
}

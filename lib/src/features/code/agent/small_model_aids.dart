import 'package:finn_ai/src/features/code/agent/agent_protocol.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';

/// What makes the on-device 1.6B model finish real tasks: recovering its
/// common format slips, opening its reply when the next step is clear, and
/// one-line hints after failures it would otherwise repeat. Each rule comes
/// from a run on a Mi 11 Lite with "create count.sh … then run it". None of
/// it is used for a cloud model.
abstract final class SmallModelAids {
  /// The file a request asks to be created, when it names exactly one:
  /// "Create a shell script count.sh that…" → `count.sh`.
  static String? fileToCreate(String request) {
    final asks = RegExp(
      r'\b(create|write|make|add|build|generate|new)\b',
      caseSensitive: false,
    ).hasMatch(request);
    if (!asks) return null;
    final names = {
      for (final match in RegExp(
        r'(?<![\w/.-])([\w-]+(?:/[\w-]+)*\.(?:sh|py|js|mjs|ts|txt|md|json|html|'
        r'css|c|h|cpp|rs|go|java|kt|rb|php|lua|yaml|yml|toml|csv|xml|sql))\b',
      ).allMatches(request))
        match.group(1)!,
    };
    return names.length == 1 ? names.single : null;
  }

  /// Recovers the two format slips the on-device model makes most, measured
  /// on a Mi 11 Lite with "create count.sh … then run it":
  ///
  /// - a script written as a command (a `sh` block opening with `#!`): it is
  ///   the file's content, so it becomes a write to the file [request] names;
  /// - a command written as a bare line of prose (`seq 1 5`): it is run.
  ///
  /// Only for the small model; a cloud model that writes prose means prose.
  static ParsedReply repair(ParsedReply reply, {required String request}) {
    final action = reply.action;
    if (action != null) {
      if (!action.isShell || !action.command.startsWith('#!')) return reply;
      final target = fileToCreate(request);
      if (target == null) return reply;
      return ParsedReply(
        prose: reply.prose,
        action: CodeAction.write(target, '${action.command}\n'),
        ignoredActions: reply.ignoredActions,
      );
    }
    if (reply.cutOff) return reply;
    // `seq 1 5` followed by an empty ```sh block: the command went in the
    // prose and the block came out empty.
    final lines = [
      for (final line in reply.prose.trim().split('\n'))
        if (!reply.malformed || !RegExp(r'^\s*`{3,}\w*\s*$').hasMatch(line))
          line,
    ];
    if (reply.malformed && lines.length > 1) return reply;
    final line = lines.last.replaceAll(RegExp(r'^`+|`+$'), '').trim();
    if (line.isEmpty || lines.length > 1 || line.length > 120) return reply;
    if (!bareCommand.hasMatch(line)) return reply;
    return ParsedReply(prose: '', action: CodeAction.shell(line));
  }

  static final RegExp bareCommand = RegExp(
    r'^(ls|cat|sh|bash|seq|echo|printf|python3?|node|npm|npx|pip3?|mkdir|'
    r'touch|grep|find|head|tail|wc|chmod|cp|mv|rm|git|apk|apt|apt-get|make|'
    r'gcc|cc|go|cargo|sed|awk|sort|diff|\./[\w.-]+)( [^\n]*)?$',
  );

  /// The start of the next reply, when the next step is already clear from
  /// the request and what has happened since — for the on-device model only.
  ///
  /// Asked to "create count.sh that prints 1 to 5, then run it", the 1.6B
  /// model ran the loop inline, ran count.sh before writing it, or wrote it
  /// three times; hints in the prompt did not change that. Opening its reply
  /// with ```file count.sh (and later with the run command) leaves it only
  /// the part it is good at: the file's content.
  static String? forcedStart(List<CodeMessage> messages,
      {required bool shell}) {
    final requestIndex = messages.lastIndexWhere((m) => m.isUser);
    if (requestIndex < 0) return null;
    final target = fileToCreate(messages[requestIndex].text);
    if (target == null) return null;
    final actions = [
      for (final message in messages.skip(requestIndex + 1))
        if (message.action != null) message.action!,
    ];
    final written = actions.lastIndexWhere((a) =>
        !a.isShell &&
        a.status == CodeActionStatus.done &&
        CodeWorkspace.samePath(a.path, target));
    if (written < 0) {
      // Only before anything else happened: once the model has been told why
      // something failed, it decides again.
      return actions.isEmpty ? '```file $target\n' : null;
    }
    final run = runCommandFor(target);
    final wantsRun =
        RegExp(r'\b(run|execute|test|start|try)\b', caseSensitive: false)
            .hasMatch(messages[requestIndex].text);
    final since = actions.skip(written + 1).toList();
    if (shell && run != null && wantsRun && !since.any((a) => a.isShell)) {
      return '```sh\n$run';
    }
    // The script ran and the result says what is wrong with it: the fix is a
    // new version of the file. Twice at most, then the model decides.
    final last = since.lastOrNull;
    final rewrites = actions
        .where((a) => !a.isShell && CodeWorkspace.samePath(a.path, target))
        .length;
    if (last != null &&
        last.isShell &&
        last.command.contains(target) &&
        hintFor(last) != null &&
        rewrites < 3) {
      return '```file $target\n';
    }
    return null;
  }

  /// How to run [path], when it is a script.
  static String? runCommandFor(String path) => switch (path.split('.').last) {
        'sh' => 'sh $path',
        'py' => 'python3 $path',
        'js' || 'mjs' => 'node $path',
        _ => null,
      };

  /// One line on how to get past a failure a small model keeps repeating.
  /// Only for failures with an unambiguous cause, read from the output.
  static String? hintFor(CodeAction action) {
    if (!action.isShell) return null;
    final output = action.output;
    final command = action.command.trim();
    // sh prints the range back instead of expanding it, and exits 0.
    if (RegExp(r'^\{\d+\.\.\d+\}$', multiLine: true).hasMatch(output)) {
      return r'This shell has no {1..5} ranges. Use $(seq 1 5) instead.';
    }
    if (action.status != CodeActionStatus.failed) return null;
    // The line that failed is usually the last one that runs a script.
    final first = command
        .split('\n')
        .map((line) => line.trim().split(RegExp(r'\s+')).first)
        .lastWhere(
          (word) => RegExp(r'^(\./)?[\w./-]+\.(sh|py|js)$').hasMatch(word),
          orElse: () => command.split(RegExp(r'\s+')).first,
        );
    final script = RegExp(r'^(\./)?[\w./-]+\.(sh|py|js)$').hasMatch(first);
    final missing = RegExp(
      r'No such file|not found|inaccessible|cannot open|does not exist',
      caseSensitive: false,
    ).hasMatch(output);
    if (script && missing) {
      final name = first.replaceFirst('./', '');
      final runner = switch (name.split('.').last) {
        'py' => 'python3',
        'js' => 'node',
        _ => 'sh',
      };
      return 'If $name does not exist yet, create it with ```file $name. '
          'Run it with: $runner $name';
    }
    if (script &&
        RegExp(r'[Pp]ermission denied|can.t execute').hasMatch(output)) {
      return 'Run it with: sh ${first.replaceFirst('./', '')}';
    }
    return null;
  }
}

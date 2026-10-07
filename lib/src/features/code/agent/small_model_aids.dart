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
  static String? fileToCreate(String request) => _fileNamed(request, _create);

  /// The file a request asks to be changed: "Change hello.py to print
  /// cubes" → `hello.py`. Only when it asks for no new file.
  static String? fileToEdit(String request) =>
      fileToCreate(request) == null ? _fileNamed(request, _edit) : null;

  static final RegExp _create = RegExp(
    r'\b(create|write|make|add|build|generate|new)\b',
    caseSensitive: false,
  );
  static final RegExp _edit = RegExp(
    r'\b(change|edit|update|modify|fix|rewrite|refactor|improve|extend)\b',
    caseSensitive: false,
  );

  /// The files a request asks to be created when it names two or more, in
  /// the order it names them: "create a.txt with hello, then b.txt with
  /// world" → [a.txt, b.txt]. Empty otherwise.
  ///
  /// Conservative: every named file must be one to create, either after a
  /// create verb or joined to the previous one by only "," / "and" /
  /// "then". "Add a function to a.py that reads b.json" names an input, so
  /// nothing is forced.
  static List<String> filesToCreate(String request) {
    if (!_create.hasMatch(request)) return const [];
    final matches = _fileName
        .allMatches(request)
        .where((m) => !_notFiles.contains(m.group(1)!.toLowerCase()));
    final files = <String>[];
    var from = 0;
    for (final match in matches) {
      final between = request.substring(from, match.start);
      final joined = files.isNotEmpty && _joiner.hasMatch(between);
      if (!_create.hasMatch(between) && !joined) return const [];
      if (!files.contains(match.group(1))) files.add(match.group(1)!);
      from = match.end;
    }
    return files.length > 1 ? files : const [];
  }

  /// Each file of [filesToCreate] with only its own part of the request:
  /// "create a.txt with hello then create b.txt with world" → a.txt: "with
  /// hello", b.txt: "with world". Told to the small model, which otherwise
  /// put both parts in both files.
  static List<(String, String)> filePlan(String request) {
    final files = filesToCreate(request);
    if (files.isEmpty) return const [];
    final matches = _fileName.allMatches(request).toList();
    return [
      for (final (i, match) in matches.indexed)
        if (files.contains(match.group(1)))
          (
            match.group(1)!,
            request
                .substring(
                  match.end,
                  i + 1 < matches.length ? matches[i + 1].start : null,
                )
                .replaceAll(_trailingLink, '')
                .trim(),
          ),
    ];
  }

  static final RegExp _trailingLink = RegExp(
    r'([\s,.;:]|\b(and|then|also|create|write|make|add|a|an|new|file|'
    r'named|called)\b)+$',
    caseSensitive: false,
  );

  static final RegExp _joiner =
      RegExp(r'^\s*(,|and|&|then|,\s*then|,\s*and)?\s*(also\s*)?$');

  static final RegExp _fileName = RegExp(
    r'(?<![\w/.-])([\w-]+(?:/[\w-]+)*\.(?:sh|py|js|mjs|ts|txt|md|json|html|'
    r'css|c|h|cpp|rs|go|java|kt|rb|php|lua|yaml|yml|toml|csv|xml|sql))\b',
  );

  /// The files of [filesToCreate] not yet written since the request.
  static List<String> _pending(List<String> files, List<CodeAction> actions) =>
      [
        for (final file in files)
          if (!actions.any((a) =>
              !a.isShell &&
              a.status == CodeActionStatus.done &&
              CodeWorkspace.samePath(a.path, file)))
            file,
      ];

  static String? _fileNamed(String request, RegExp verbs) {
    if (!verbs.hasMatch(request)) return null;
    final names = {
      for (final match in RegExp(
        r'(?<![\w/.-])([\w-]+(?:/[\w-]+)*\.(?:sh|py|js|mjs|ts|txt|md|json|html|'
        r'css|c|h|cpp|rs|go|java|kt|rb|php|lua|yaml|yml|toml|csv|xml|sql))\b',
      ).allMatches(request))
        match.group(1)!,
    };
    // Product names that look like files: "a Node.js script fib.js".
    names.removeWhere((name) => _notFiles.contains(name.toLowerCase()));
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
    // The right code in an ordinary ```python block instead of a file
    // action: it is the file the request names.
    final target = fileToCreate(request);
    if (target != null && !reply.malformed) {
      final block = _blockFor(reply.prose, target);
      if (block != null) {
        return ParsedReply(prose: '', action: CodeAction.write(target, block));
      }
    }
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

  static const Map<String, Set<String>> _languages = {
    'py': {'python', 'py', 'python3'},
    'js': {'javascript', 'js', 'node'},
    'mjs': {'javascript', 'js', 'node'},
    'ts': {'typescript', 'ts'},
    'html': {'html'},
    'css': {'css'},
    'c': {'c'},
    'cpp': {'cpp', 'c++'},
    'rs': {'rust', 'rs'},
    'go': {'go'},
    'java': {'java'},
    'rb': {'ruby', 'rb'},
    'json': {'json'},
    'md': {'markdown', 'md'},
  };

  /// The body of the one fenced block in [prose] written in [target]'s
  /// language, if there is exactly one.
  static String? _blockFor(String prose, String target) {
    final languages = _languages[target.split('.').last];
    if (languages == null) return null;
    final blocks = [
      for (final match
          in RegExp(r'^```(\w[\w+]*)\s*\n([\s\S]*?)\n```\s*$', multiLine: true)
              .allMatches(prose))
        if (languages.contains(match.group(1)!.toLowerCase())) match.group(2)!,
    ];
    return blocks.length == 1 ? '${blocks.single}\n' : null;
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
    final request = messages[requestIndex];
    // Several files: each in the order the request names them. The 1.6B
    // model asked for "a.txt … then b.txt" wrote b.txt and stopped.
    final many = filesToCreate(request.text);
    if (many.isNotEmpty) {
      final done = [
        for (final message in messages.skip(requestIndex + 1))
          if (message.action != null) message.action!,
      ];
      final next = _pending(many, done).firstOrNull;
      final last = done.lastOrNull;
      final clear = last == null ||
          (!last.isShell && last.status == CodeActionStatus.done);
      return next != null && clear ? '```file $next\n${headerFor(next)}' : null;
    }
    final created = fileToCreate(request.text);
    final target = created ?? fileToEdit(request.text);
    if (target == null) return null;
    // A file to change is read before it is rewritten, unless the request
    // brought its contents with an @mention.
    final editing = created == null;
    final header = editing ? '' : headerFor(target);
    final actions = [
      for (final message in messages.skip(requestIndex + 1))
        if (message.action != null) message.action!,
    ];
    final written = actions.lastIndexWhere((a) =>
        !a.isShell &&
        a.status == CodeActionStatus.done &&
        CodeWorkspace.samePath(a.path, target));
    if (written < 0) {
      if (editing) {
        final read = actions.isNotEmpty &&
            actions.last.isShell &&
            actions.last.status == CodeActionStatus.done &&
            actions.last.command.trim() == 'cat $target';
        if (actions.isEmpty) {
          return request.context.contains('Contents of $target')
              ? '```file $target\n'
              : '```sh\ncat $target';
        }
        if (read) return '```file $target\n';
        // Nothing to change: the file is not there. Write it new.
        final missing = actions.length == 1 &&
            actions.single.isShell &&
            actions.single.command.trim() == 'cat $target' &&
            actions.single.status == CodeActionStatus.failed;
        return missing ? '```file $target\n${headerFor(target)}' : null;
      }
      // Only before anything else happened: once the model has been told why
      // something failed, it decides again.
      return actions.isEmpty ? '```file $target\n$header' : null;
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
    final hint = last == null ? null : hintFor(last);
    // A missing tool is installed, not written around.
    final install = hint == null ? null : _installHint.firstMatch(hint);
    if (shell && install != null && last!.isShell) {
      return '```sh\napk add ${install.group(1)}';
    }
    // The tool is in now: run the script again.
    if (shell &&
        run != null &&
        wantsRun &&
        last != null &&
        last.isShell &&
        last.status == CodeActionStatus.done &&
        RegExp(r'^(apk add|apt(-get)? install|pip3? install|npm install)\b')
            .hasMatch(last.command.trim())) {
      return '```sh\n$run';
    }
    if (last != null &&
        last.isShell &&
        last.command.contains(target) &&
        (last.status == CodeActionStatus.failed || hint != null) &&
        rewrites < 3) {
      return '```file $target\n$header';
    }
    return null;
  }

  /// True when the request was "create X … run it" and X just ran cleanly:
  /// the small model would only re-run it or `cat` it before stopping.
  static bool finished(List<CodeMessage> messages) {
    final requestIndex = messages.lastIndexWhere((m) => m.isUser);
    if (requestIndex < 0) return false;
    final request = messages[requestIndex].text;
    // Several files and nothing to run: done once each is written.
    final many = filesToCreate(request);
    if (many.isNotEmpty) {
      final actions = [
        for (final message in messages.skip(requestIndex + 1))
          if (message.action != null) message.action!,
      ];
      return !_wantsRun.hasMatch(request) && _pending(many, actions).isEmpty;
    }
    final target = fileToCreate(request) ?? fileToEdit(request);
    final run = target == null ? null : runCommandFor(target);
    if (target == null || run == null) return false;
    if (!RegExp(r'\b(run|execute|test|start|try)\b', caseSensitive: false)
        .hasMatch(request)) {
      return false;
    }
    final actions = messages
        .skip(requestIndex + 1)
        .map((m) => m.action)
        .whereType<CodeAction>()
        .toList();
    // The file was (re)written in this request, then run cleanly after.
    final written = actions.lastIndexWhere((a) =>
        !a.isShell &&
        a.status == CodeActionStatus.done &&
        CodeWorkspace.samePath(a.path, target));
    final last = actions.lastOrNull;
    return written >= 0 &&
        last != null &&
        actions.indexOf(last) > written &&
        last.isShell &&
        last.status == CodeActionStatus.done &&
        last.command.trim() == run &&
        hintFor(last) == null;
  }

  static final RegExp _wantsRun =
      RegExp(r'\b(run|execute|test|start|try)\b', caseSensitive: false);

  static final RegExp _installHint =
      RegExp(r'^Install it first: apk add (.+)$');

  static const Set<String> _notFiles = {
    'node.js',
    'vue.js',
    'next.js',
    'nuxt.js',
    'react.js',
    'express.js',
    'three.js',
    'd3.js',
    'chart.js',
    'p5.js',
    'nest.js',
    'ember.js',
    'backbone.js',
    'socket.io',
    'deno.land',
    'asp.net',
    'vb.net',
  };

  /// A first line that names the file's language. The 1.6B model wrote
  /// shell loops into hello.py every time; starting the file with
  /// `# Python 3` is what made it write Python.
  static String headerFor(String path) => switch (path.split('.').last) {
        'py' => '# Python 3\n',
        'sh' => '#!/bin/sh\n',
        'js' || 'mjs' => '// JavaScript (Node.js)\n',
        'ts' => '// TypeScript\n',
        'c' => '// C\n#include <stdio.h>\n',
        'go' => 'package main\n',
        'rs' => '// Rust\n',
        _ => '',
      };

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
    // A tool that is not installed: say how to get it (Alpine names).
    final missingTool = RegExp(r'(?:^|\s|/)([\w.+-]+): (?:command )?not found')
        .firstMatch(output)
        ?.group(1);
    if (missingTool != null) {
      final package = switch (missingTool) {
        'node' || 'npm' || 'npx' => 'nodejs npm',
        'python' || 'python3' => 'python3',
        'pip' || 'pip3' => 'py3-pip',
        'gcc' || 'cc' || 'make' || 'g++' => 'build-base',
        'git' || 'curl' || 'wget' || 'bash' || 'go' || 'cargo' => missingTool,
        _ => null,
      };
      if (package != null) return 'Install it first: apk add $package';
    }
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

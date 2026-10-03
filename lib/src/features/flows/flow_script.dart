import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/action_matcher.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_phrases.dart';

/// A flow written as a few plain lines.
///
/// This is the one format the on-device model is asked to write. A 1.6B model
/// cannot be trusted with nested JSON, but it can follow a short list of
/// `key: value` lines it has seen examples of, and each line is read by the
/// same phrase rules as a typed sentence, so a line that does not parse is
/// dropped and reported instead of becoming something the user did not ask for.
///
/// ```text
/// name: Flashlight on charge
/// when: charger connected
/// only if: battery below 30
/// do: action torch on=true
/// do: notify "Charging started"
/// ```
abstract final class FlowScript {
  /// Reads [source] into a flow. `flow` is null when nothing runnable was
  /// found; `problems` lists the lines that were not understood.
  static ({FinnFlow? flow, List<String> problems}) parse(
    String source, {
    required String id,
    String fallbackName = '',
  }) {
    var name = fallbackName;
    final triggers = <FlowTrigger>[];
    final conditions = <FlowCondition>[];
    final blocks = <FlowBlock>[];
    final problems = <String>[];

    for (final raw in source.split('\n')) {
      final line = raw
          .trim()
          .replaceFirst(RegExp(r'^(?:[-*•]|\d+[.)])\s*'), '')
          .replaceAll('**', '')
          .trim();
      final split = line.indexOf(':');
      if (split <= 0) continue;
      final key = line.substring(0, split).trim().toLowerCase();
      final value = line.substring(split + 1).trim();
      if (value.isEmpty) continue;
      switch (key) {
        case 'name' || 'title':
          name =
              value.length <= 50 ? value : value.substring(0, 50).trimRight();
        case 'when' || 'trigger':
          final trigger = _trigger(value);
          if (trigger == null) {
            problems.add(line);
          } else if (!trigger.isManual &&
              triggers.length < FlowTrigger.maxPerFlow) {
            triggers.add(trigger);
          }
        case 'only if' || 'if' || 'condition' || 'only when':
          final found = FlowPhrases.findConditions('only if $value');
          if (found.conditions.isEmpty) {
            problems.add(line);
          } else {
            conditions.addAll(found.conditions);
          }
        case 'do' || 'then' || 'step' || 'action':
          final block = parseStep(value);
          if (block == null) {
            problems.add(line);
          } else if (blocks.length < FlowBlock.maxPerFlow) {
            blocks.add(block);
          }
      }
    }
    if (blocks.isEmpty) return (flow: null, problems: problems);
    return (
      flow: FinnFlow(
        id: id,
        name: name.isEmpty ? 'My flow' : name,
        description: '',
        instructions: '',
        category: 'Automation',
        blocks: blocks,
        triggers: triggers,
        conditions: conditions.take(FlowCondition.maxPerFlow).toList(),
      ),
      problems: problems,
    );
  }

  static FlowTrigger? _trigger(String value) {
    final lower = value.toLowerCase().trim();
    if (const {'manual', 'manually', 'on demand', 'when i ask', 'button'}
        .contains(lower)) {
      return const FlowTrigger.manual();
    }
    return FlowPhrases.findTrigger(value)?.trigger;
  }

  /// One `do:` line. Null when it is not a step this app can run.
  static FlowBlock? parseStep(String text) {
    final line = text.trim();
    final lower = line.toLowerCase();

    String rest(String verb) => _unquote(line.substring(verb.length).trim());

    for (final verb in const ['notify', 'notification', 'alert']) {
      if (lower.startsWith('$verb ') || lower == verb) {
        return FlowBlock.notify(_clip(rest(verb)));
      }
    }
    for (final verb in const ['ask', 'prompt', 'ask finn', 'ask finnai']) {
      if (lower.startsWith('$verb ')) {
        final prompt = _clip(rest(verb));
        return prompt.isEmpty ? null : FlowBlock.ask(prompt);
      }
    }
    for (final verb in const ['look up', 'search', 'web', 'browse']) {
      if (lower.startsWith('$verb ')) {
        final query = _clip(rest(verb));
        return query.isEmpty ? null : FlowBlock.web(query);
      }
    }
    for (final verb in const ['speak', 'say', 'read out', 'announce']) {
      if (lower.startsWith('$verb ') || lower == verb) {
        return FlowBlock.speak(_clip(rest(verb)));
      }
    }
    final wait = RegExp(
            r'^(?:wait|pause|delay)\s+(\d+)\s*(s|sec|secs|seconds?|m|min|mins|minutes?)?')
        .firstMatch(lower);
    if (wait != null) {
      var seconds = int.parse(wait.group(1)!);
      if ((wait.group(2) ?? '').startsWith('m')) seconds *= 60;
      return FlowBlock.wait(seconds.clamp(0, FlowBlock.maxWaitSeconds));
    }
    if (RegExp(r'^(?:save|put|send)\b.*\b(?:chat|conversation|result)\b')
            .hasMatch(lower) ||
        lower == 'save') {
      return const FlowBlock.saveToChat();
    }
    if (lower == 'stop' || lower == 'end') return const FlowBlock.stop();

    // `action torch on=true`, or the same thing in words.
    final explicit = RegExp(r'^action\s+([a-z_]+)\s*(.*)$').firstMatch(lower);
    if (explicit != null) {
      final action = DeviceActionCatalog.byName(explicit.group(1)!);
      if (action == null) return null;
      final arguments = <String, String>{};
      for (final pair in RegExp(r'([a-z_]+)\s*=\s*("[^"]*"|\S+)').allMatches(
        line.substring(line.toLowerCase().indexOf(explicit.group(1)!) +
            explicit.group(1)!.length),
      )) {
        arguments[pair.group(1)!] = _unquote(pair.group(2)!);
      }
      for (final param in action.params) {
        if (param.required && !arguments.containsKey(param.name)) return null;
      }
      return FlowBlock.action(action.name, arguments);
    }
    return actionFromPhrase(line);
  }

  /// "turn on the flashlight", "set an alarm for 7" → an action block.
  static FlowBlock? actionFromPhrase(String phrase) {
    final invocation = const DeviceActionMatcher().match(phrase);
    if (invocation == null) return null;
    return FlowBlock.action(invocation.action.name, {
      for (final entry in invocation.arguments.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    });
  }

  static String _unquote(String text) {
    final t = text.trim();
    if (t.length >= 2 &&
        ((t.startsWith('"') && t.endsWith('"')) ||
            (t.startsWith('“') && t.endsWith('”')) ||
            (t.startsWith("'") && t.endsWith("'")))) {
      return t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  static String _clip(String text) => text.length <= FlowBlock.maxTextLength
      ? text
      : text.substring(0, FlowBlock.maxTextLength);
}

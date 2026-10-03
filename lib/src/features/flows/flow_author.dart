import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/flows/flow_intent.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flow_phrases.dart';
import 'package:finn_ai/src/features/flows/flow_script.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

/// A flow made from a sentence, before the user has accepted it.
class FlowDraft {
  const FlowDraft({
    required this.flow,
    this.fromModel = false,
    this.notUnderstood = const [],
  });

  final FinnFlow flow;

  /// Whether the model wrote it (as opposed to the app's own phrase rules).
  final bool fromModel;

  /// Parts of the request that were not turned into anything, shown so the user
  /// can see what is missing instead of trusting a flow that silently does less.
  final List<String> notUnderstood;
}

/// Turns "when I plug in my charger, turn on the flashlight" into a flow.
///
/// Two stages, cheapest first. The app's own phrase rules read the sentence
/// (a trigger, optional "only if" conditions, then what to do), which handles
/// the requests people actually make with no model call at all. When they find
/// nothing runnable, [modelPrompt] asks the model to write the flow as a few
/// lines of [FlowScript], and [fromScript] reads them. Either way the result is
/// checked by the same validator as a flow built by hand.
abstract final class FlowAuthor {
  static FlowDraft? fromSentence(
    String sentence, {
    required String id,
    DateTime? now,
  }) {
    final text = sentence.trim();
    if (text.isEmpty) return null;

    final foundTrigger = FlowPhrases.findTrigger(text);
    final afterTrigger = foundTrigger?.rest ?? text;
    final foundConditions = FlowPhrases.findConditions(afterTrigger);
    final what = foundConditions.rest;

    // A ready-made flow (morning brief, a web check, a reminder) when the words
    // point at one: its steps are better than anything assembled from clauses.
    final intent = FlowIntent.parse(what);
    if (intent != null &&
        _asksForSomething(what) &&
        !_looksLikeDeviceRequest(what)) {
      final values =
          SlotSanitizer.sanitize(intent.template.slots, intent.slots);
      final flow = intent.template.build(
        id,
        values,
        trigger: foundTrigger?.trigger ?? intent.trigger,
      );
      return FlowDraft(
        flow: flow.copyWith(
          conditions: foundConditions.conditions,
          description: _describe(text),
        ),
      );
    }

    final blocks = <FlowBlock>[];
    final missed = <String>[];
    for (final clause in _clauses(what)) {
      final made = _blocksFor(clause);
      if (made.isEmpty) {
        missed.add(clause);
      } else {
        blocks.addAll(made);
      }
    }
    if (blocks.isEmpty) return null;

    return FlowDraft(
      flow: FinnFlow(
        id: id,
        name: _name(what),
        description: _describe(text),
        instructions: '',
        category: 'Automation',
        blocks: blocks.take(FlowBlock.maxPerFlow).toList(),
        triggers: [
          if (foundTrigger != null && !foundTrigger.trigger.isManual)
            foundTrigger.trigger,
        ],
        conditions: foundConditions.conditions,
      ),
      notUnderstood: missed,
    );
  }

  /// A sentence that actually asks for something. "The weather is nice" names
  /// a topic but requests nothing, and must not become a weather brief.
  static bool _asksForSomething(String text) => RegExp(
        r'\b(?:give|tell|send|show|get|read|check|watch|monitor|track|remind|notify|summari[sz]e|brief|update|alert)\b',
        caseSensitive: false,
      ).hasMatch(text);

  static bool _looksLikeDeviceRequest(String text) => RegExp(
          r'\b(?:flashlight|torch|alarm|timer|volume|vibrate|play|pause|open|call|dial|navigate)\b',
          caseSensitive: false)
      .hasMatch(text);

  /// Splits "turn on the torch and notify me" into its clauses.
  static List<String> _clauses(String text) => text
      .split(RegExp(r'\s*(?:,\s*)?(?:\band then\b|\bthen\b|\band\b|,|;)\s+',
          caseSensitive: false))
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();

  /// A request for the assistant to write something ("tell me a joke",
  /// "summarise my day") rather than for a notification with fixed words.
  static final _askLike = RegExp(
    r'^(?:please\s+)?(?:tell me|give me|show me|write|summari[sz]e|explain|ask|what|how|why|who)\b'
    r'\s*(?:a|an|the|about|some|something|one|is|are|do|does|to)?\b',
    caseSensitive: false,
  );
  static final _fixedWords = RegExp(
    r'^(?:tell me|let me know|alert me)\s+(?:that\b|to\b)',
    caseSensitive: false,
  );

  static List<FlowBlock> _blocksFor(String clause) {
    final lower = clause.toLowerCase();
    if (_askLike.hasMatch(lower) &&
        !_fixedWords.hasMatch(lower) &&
        !RegExp(r'^(?:remind|notify|send me a notification)').hasMatch(lower)) {
      return [
        FlowBlock.ask(
          '${_capital(clause)}. Answer in a few short lines. '
          'Reply in the language of the question.',
        ),
        const FlowBlock.notify(''),
        const FlowBlock.saveToChat(),
      ];
    }
    final single = _blockFor(clause);
    return single == null ? const [] : [single];
  }

  static FlowBlock? _blockFor(String clause) {
    final lower = clause.toLowerCase();

    final speak = RegExp(
      r'^(?:please\s+)?(?:say|speak|read out(?: loud)?|announce)\s+(.*)$',
    ).firstMatch(lower);
    if (speak != null) {
      return FlowBlock.speak(_original(clause, speak.group(1)!));
    }

    final notify = RegExp(
      r'^(?:please\s+)?(?:remind me(?:\s+to)?|notify me(?:\s+(?:that|to))?|'
      r'send me a notification(?:\s+(?:saying|that))?|let me know(?:\s+that)?|'
      r'tell me(?:\s+that)?|alert me(?:\s+that)?|show a notification(?:\s+saying)?)\s*(.*)$',
    ).firstMatch(lower);
    if (notify != null) {
      final message = _original(clause, notify.group(1)!);
      return FlowBlock.notify(message.isEmpty ? 'Reminder' : _capital(message));
    }

    return FlowScript.actionFromPhrase(clause);
  }

  /// The part of [clause] that [lowered] came from, with the original casing.
  static String _original(String clause, String lowered) {
    if (lowered.isEmpty) return '';
    final index = clause.toLowerCase().lastIndexOf(lowered);
    return index < 0 ? lowered : clause.substring(index).trim();
  }

  static String _capital(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  static String _name(String what) {
    final words = what
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(6)
        .join(' ');
    return words.isEmpty ? 'My flow' : _capital(words);
  }

  static String _describe(String text) =>
      text.length <= 140 ? text : '${text.substring(0, 140).trimRight()}…';

  // ---- model fallback ---------------------------------------------------

  /// The prompt that asks the model to write a flow as [FlowScript] lines.
  ///
  /// Everything it may choose from is listed, and two examples show the shape,
  /// because a small model copies a format far more reliably than it follows a
  /// description of one.
  static String modelPrompt(String request) {
    final actions = [
      for (final action in DeviceActionCatalog.all)
        if (DeviceActionCatalog.runsInBackground(action.name)) action.name,
    ].join(', ');
    return '''
Write an automation for a phone as a few lines. Use only these line types:
name: a short name
when: charger connected | charger disconnected | battery low | headphones connected | headphones disconnected | wifi connected | wifi disconnected | phone starts | screen unlocked | every day at 07:30 | every 30 minutes
only if: battery below 30 | charging | wifi connected | on weekdays   (optional)
do: notify "message" | ask "question for the assistant" | look up topic | say "text" | wait 5 seconds | save to chat | action NAME key=value
Actions you may use with "action": $actions.

Example request: when I plug in my charger turn on the flashlight
name: Flashlight on charge
when: charger connected
do: action torch on=true

Example request: every morning at 7 tell me the news
name: Morning news
when: every day at 07:00
do: look up news: top headlines
do: ask "Write a short summary of the news above in 3 bullet points."
do: notify
do: save to chat

Request: $request
'''
        .trim();
  }

  /// Reads the model's lines into a draft, or null if nothing runnable came
  /// back. Lines it could not read are returned in [FlowDraft.notUnderstood].
  static FlowDraft? fromScript(
    String script, {
    required String id,
    String fallbackName = '',
  }) {
    final parsed = FlowScript.parse(script, id: id, fallbackName: fallbackName);
    final flow = parsed.flow;
    if (flow == null) return null;
    if (!FlowsValidationLite.isUsable(flow)) return null;
    return FlowDraft(
      flow: flow,
      fromModel: true,
      notUnderstood: parsed.problems,
    );
  }

  // ---- chat routing -----------------------------------------------------

  static final _create = RegExp(
    r'\b(?:(?:make|create|build|set up|setup|write|add)\s+(?:me\s+)?(?:an?\s+|the\s+|my\s+)?(?:new\s+)?'
    r'(?:flow|automation|routine|macro|workflow|shortcut)|automate|automatise|'
    r'automatically|every time i|whenever i|whenever my|when i plug|when my (?:battery|phone))\b',
    caseSensitive: false,
  );

  /// Whether a chat message is asking for something to be automated.
  ///
  /// Deliberately conservative: a flow is never created from a message that did
  /// not ask for one, so "remind me about the dentist" stays a chat answer and
  /// "every day at 8 remind me to stretch" is the only kind of reminder that
  /// becomes a flow (it has a trigger of its own).
  static bool isFlowRequest(String text) {
    if (_create.hasMatch(text)) return true;
    final trigger = FlowPhrases.findTrigger(text);
    if (trigger == null || trigger.trigger.isManual) return false;
    final lower = text.toLowerCase();
    // "every day" inside a sentence about routines is not a schedule; a time or
    // a part of the day is.
    if (trigger.trigger.kind == FlowTriggerKind.timeOfDay &&
        !RegExp(
          r'\bat\s+\d|\b(?:morning|evening|night|afternoon|daily|weekdays?|weekends?)\b',
        ).hasMatch(lower)) {
      return false;
    }
    return RegExp(
            r'\b(?:remind|notify|tell|text|alert|turn|play|pause|open|set|send|check|read|say|give)\b')
        .hasMatch(lower);
  }
}

/// A small guard for flows made from model text: has something to do, and no
/// block is outside what the validator accepts. Kept here, not in the store, so
/// authoring has no dependency on persistence.
abstract final class FlowsValidationLite {
  static bool isUsable(FinnFlow flow) {
    if (flow.blocks.isEmpty) return false;
    for (final block in flow.allBlocks) {
      if (block.kind == FlowBlockKind.action) {
        final action = DeviceActionCatalog.byName(block.actionName ?? '');
        if (action == null) return false;
        for (final param in action.params) {
          if (param.required && !block.arguments.containsKey(param.name)) {
            return false;
          }
        }
      }
    }
    return flow.triggers.every((t) => t.isValid) &&
        flow.conditions.every((c) => c.isValid);
  }
}

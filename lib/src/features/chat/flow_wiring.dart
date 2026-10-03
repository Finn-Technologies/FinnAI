import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/flows/flow_environment.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/features/search/providers/news_provider.dart';
import 'package:finn_ai/src/features/search/providers/weather_provider.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/features/search/search_turn.dart';
import 'package:finn_ai/src/features/voice/read_aloud.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';

/// Connects the flow runner to the real engine, search and conversation store.
///
/// Lives in `chat/` because the chat feature is the composition root: `flows/`
/// may not import the engine, the search feature or the conversation store, so
/// it declares the ports it needs and this file plugs the real things in.
FlowRunner buildFlowRunner({
  required ConversationFlowSink sink,
  required SearchTurn search,
  required FlowNotifier notifier,
  FinnInference? inference,
  FlowsStore? store,
  FlowSpeaker? speaker,
  FlowEnvironment? environment,
}) =>
    FlowRunner(
      store: store,
      model: EngineFlowModel(inference ?? FinnInference.instance),
      search: SearchTurnFlowSearch(search),
      sink: sink,
      notifier: notifier,
      speaker: speaker ?? ReadAloudFlowSpeaker(),
      environment: environment ?? const PlatformFlowEnvironment(),
    );

/// Speaks a flow's text with the phone's own voice, the one "read aloud" uses.
class ReadAloudFlowSpeaker implements FlowSpeaker {
  @override
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    await ReadAloud.instance.speak(text);
    return true;
  }
}

/// Answers a flow's prompt with the on-device model.
class EngineFlowModel implements FlowModel {
  EngineFlowModel(this._inference);

  final FinnInference _inference;

  @override
  Future<String> answer(
    String prompt, {
    String groundedContext = '',
    int? maxTokens,
  }) async {
    final output = StringBuffer();
    await for (final token in _inference.generateReplyQueued(
      prompt,
      // A conversation of its own, so a flow never disturbs the user's chat
      // session (the session cache holds one entry per conversation id).
      conversationId: 'flow-${DateTime.now().microsecondsSinceEpoch}',
      groundedContext: groundedContext,
      maxOutputTokens: maxTokens,
      // A brief is factual and short: the quick-question sampler, not the
      // creative one.
      samplerProfile: PromptIntentPolicy.sampler(PromptIntent.quickQuestion),
    )) {
      output.write(token);
    }
    // A small model sometimes wraps its answer in a made-up <Answer> tag,
    // which renders as an empty block. It is never content.
    final text = output
        .toString()
        .replaceAll(RegExp(r'</?answer>', caseSensitive: false), '')
        .trim();
    if (!kReleaseMode) {
      // Debug only: telling an empty answer from a filtered one needs the text.
      debugPrint('FINN_FLOW_ANSWER chars=${text.length} '
          'head=${text.length > 160 ? text.substring(0, 160) : text}');
    }
    return text;
  }
}

/// One bounded search per browse step, through the same [SearchTurn] chat uses.
class SearchTurnFlowSearch implements FlowSearch {
  SearchTurnFlowSearch(this._search);

  final SearchTurn _search;

  /// A step's text may begin `news:` or `weather:` to use that source instead
  /// of general web search: `weather: Rome`, `news: football`.
  static ({String? provider, String query}) route(String text) {
    final match = RegExp(r'^(news|weather):\s*(.*)$', dotAll: true)
        .firstMatch(text.trim());
    return match == null
        ? (provider: null, query: text.trim())
        : (provider: match.group(1), query: match.group(2)!.trim());
  }

  /// Sources as a short numbered list under the marker the prompt builders key
  /// on. Excerpts are capped so a full day of headlines stays under ~200 tokens.
  static String compactContext(List<WebSource> sources) {
    if (sources.isEmpty) return '';
    final buffer = StringBuffer('${PromptFormatter.groundedContextMarker}:');
    for (var i = 0; i < sources.length; i++) {
      final snippet = sources[i].snippet.length <= 220
          ? sources[i].snippet
          : '${sources[i].snippet.substring(0, 220)}…';
      buffer.write('\n[${i + 1}] $snippet');
    }
    return buffer.toString();
  }

  @override
  Future<FlowSearchResult> search(String query) async {
    final routed = route(query);
    final result = await _search.run(
      SearchPlan.search(
        routed.query,
        SearchPlanReason.explicit,
        provider: routed.provider,
      ),
    );
    // The "no results" note is for chat's prompt; a flow's prompt is told there
    // was nothing by an empty context instead. And a flow's own prompt carries
    // the instructions, so it gets the sources without chat's long answer-shape
    // rules: a two-search brief was a 1,500-token prompt and 15 s to first word.
    return FlowSearchResult(
      groundedContext: result.failed ? '' : compactContext(result.sources),
      sources: result.sources,
      failed: result.failed,
    );
  }
}

/// Saves a flow's written result as a conversation the user can open.
class ConversationFlowSink implements FlowOutputSink {
  ConversationFlowSink(this._conversations, {String Function(String)? titleFor})
      : _titleFor = titleFor ?? _defaultTitle;

  final ConversationStore _conversations;
  final String Function(String flowName) _titleFor;

  /// The id of the conversation written last, so the caller can open it.
  String? lastConversationId;

  static String _defaultTitle(String name) {
    final now = DateTime.now();
    return '$name · ${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> deliver(
    FinnFlow flow,
    String text,
    List<WebSource> sources,
  ) async {
    final conversation = _conversations.addStandaloneReply(
      title: _titleFor(flow.name),
      text: text,
      sources: sources,
    );
    lastConversationId = conversation.id;
  }
}

/// Everything the chat shell needs to run flows: the scheduler (alarms and
/// notifications), the sink that turns a result into a chat, the search a
/// flow gets, and the runner that ties them to the engine.
class FlowHost {
  FlowHost({
    required ConversationStore conversations,
    required WebSearchService webSearch,
  })  : scheduler = FlowScheduler(),
        sink = ConversationFlowSink(conversations) {
    // A flow is not waiting on a keyboard, so its searches get longer than a
    // chat turn's 5 seconds: a phone on a slow radio still gets its headlines.
    _search = SearchTurn(
      agent: SearchAgent(searchService: webSearch),
      budget: const Duration(seconds: 14),
      providers: [
        NewsProvider(timeout: const Duration(seconds: 9)),
        WeatherProvider(timeout: const Duration(seconds: 9)),
      ],
    );
    runner = buildFlowRunner(sink: sink, search: _search, notifier: scheduler);
    actions = FlowsActions(
      store: FlowsStore.instance,
      runner: runner,
      scheduler: scheduler,
      onOpenResult: () => onOpenResult?.call(),
    );
  }

  /// What "Open result" does once a flow wrote a chat; set by the chat shell,
  /// which owns navigation.
  VoidCallback? onOpenResult;

  final FlowScheduler scheduler;
  final ConversationFlowSink sink;
  late final SearchTurn _search;
  late final FlowRunner runner;

  /// What the Flows screens and the chat cards do to a flow.
  late final FlowsActions actions;
}

/// A run nobody was watching: say so only when it needs the user.
///
/// Shared by the app (a flow that fires while it is open) and the screenless
/// engine (a flow that fires while it is closed), so both tell the same story.
Future<void> tellAboutFlowRun(
  FlowNotifier notifier,
  FinnFlow flow,
  FlowRun run,
  AppLocalizations l10n,
) async {
  switch (run.outcome) {
    case FlowRunOutcome.needsScreen:
      await notifier.notify(
        flowId: flow.id,
        title: flow.name,
        body: l10n.flowsNeedsScreenBody(flow.name),
      );
    case FlowRunOutcome.needsGrant:
      await notifier.notify(
        flowId: flow.id,
        title: flow.name,
        body: l10n.flowsNeedsGrantBody(flow.name),
      );
    default:
      break;
  }
}

import 'dart:async';

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/features/search/search_policy.dart';
import 'package:finn_ai/src/features/search/search_turn.dart';
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
}) =>
    FlowRunner(
      store: store,
      model: EngineFlowModel(inference ?? FinnInference.instance),
      search: SearchTurnFlowSearch(search),
      sink: sink,
      notifier: notifier,
    );

/// Answers a flow's prompt with the on-device model.
class EngineFlowModel implements FlowModel {
  EngineFlowModel(this._inference);

  final FinnInference _inference;

  @override
  Future<String> answer(String prompt, {String groundedContext = ''}) async {
    final output = StringBuffer();
    await for (final token in _inference.generateReplyQueued(
      prompt,
      // A conversation of its own, so a flow never disturbs the user's chat
      // session (the session cache holds one entry per conversation id).
      conversationId: 'flow-${DateTime.now().microsecondsSinceEpoch}',
      groundedContext: groundedContext,
      // A brief is factual and short: the quick-question sampler, not the
      // creative one.
      samplerProfile: PromptIntentPolicy.sampler(PromptIntent.quickQuestion),
    )) {
      output.write(token);
    }
    return output.toString();
  }
}

/// One bounded search per browse step, through the same [SearchTurn] chat uses.
class SearchTurnFlowSearch implements FlowSearch {
  SearchTurnFlowSearch(this._search);

  final SearchTurn _search;

  @override
  Future<FlowSearchResult> search(String query) async {
    final result = await _search.run(
      SearchPlan.search(query, SearchPlanReason.explicit),
    );
    // The "no results" note is for chat's prompt; a flow's prompt is told there
    // was nothing by an empty context instead.
    return FlowSearchResult(
      groundedContext: result.failed ? '' : result.groundedContext,
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

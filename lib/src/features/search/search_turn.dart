import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';

/// The app's decision for one turn: search once, or do not.
@immutable
class SearchPlan {
  const SearchPlan._(this.search, this.query, this.reason);

  const SearchPlan.skip(SearchPlanReason reason) : this._(false, '', reason);

  const SearchPlan.search(String query, SearchPlanReason reason)
      : this._(true, query, reason);

  final bool search;
  final String query;
  final SearchPlanReason reason;
}

/// Decides, deterministically, whether a turn should search the web.
///
/// The model never decides this (ADR 0001). A 1.6B model asked to call a tool
/// will vary the query forever or emit calls into its answer; a pure function
/// of the prompt cannot loop. The heuristics themselves are
/// [WebSearchPolicy]'s, because they are the tested, multilingual part.
class SearchPlanner {
  const SearchPlanner({this.policy = const WebSearchPolicy()});

  final WebSearchPolicy policy;

  SearchPlan plan(
    String prompt, {
    bool hasAttachment = false,
    bool enabled = true,
  }) {
    if (!enabled) return const SearchPlan.skip(SearchPlanReason.disabled);
    // An attachment is answered from the attachment; a search for it would
    // spend the turn on the web instead of on the file.
    if (hasAttachment) {
      return const SearchPlan.skip(SearchPlanReason.attachment);
    }
    final query = prompt.trim();
    final reason = policy.reasonFor(query);
    return reason.searches
        ? SearchPlan.search(query, reason)
        : SearchPlan.skip(reason);
  }
}

/// What one bounded search produced, ready to hand to the engine.
@immutable
class SearchTurnResult {
  const SearchTurnResult({
    this.groundedContext = '',
    this.sources = const [],
    this.failed = false,
    this.activity,
  });

  static const SearchTurnResult none = SearchTurnResult();

  /// Prompt context: the retrieved excerpts, or an honest "no results" note.
  final String groundedContext;
  final List<WebSource> sources;

  /// The plan asked for a search and the web did not answer in time.
  final bool failed;

  /// What the UI narrates ("Searched the web for …"); null when nothing ran.
  final ToolActivity? activity;

  bool get searched => activity != null;
}

/// Runs the single, time-boxed search a [SearchPlan] asks for.
///
/// At most one network round per turn, one fixed budget, no retry, no second
/// query. Failing fast is the feature: an unreachable web costs [budget], then
/// the answer says it had no sources.
class SearchTurn {
  SearchTurn({SearchAgent? agent, this.budget = defaultBudget})
      : _agent = agent ?? SearchAgent();

  static const Duration defaultBudget = Duration(seconds: 5);

  final SearchAgent _agent;
  final Duration budget;

  Future<SearchTurnResult> run(SearchPlan plan) async {
    if (!plan.search) return SearchTurnResult.none;
    final activity = ToolActivity(
      kind: ToolActivityKind.search,
      label: plan.query,
    );
    try {
      // An `async` closure returns a fresh future typed as nullable, so the
      // timeout's `null` is always a legal value even when the agent hands
      // back a non-null future (a fake, or a cached result), and a
      // synchronous throw lands in the catch below like any other failure.
      Future<GroundedSearchResult?> attempt() async =>
          _agent.searchAndFetch(plan.query);
      final grounded = await attempt().timeout(budget, onTimeout: () => null);
      if (grounded == null || grounded.search.sources.isEmpty) {
        return SearchTurnResult(
          groundedContext: noResultsNote,
          failed: true,
          activity: activity,
        );
      }
      return SearchTurnResult(
        groundedContext: grounded.groundedContext,
        sources: grounded.search.sources,
        activity: activity,
      );
    } catch (error) {
      // A search that throws is a search that found nothing. It must never
      // cost the user their answer.
      debugPrint('FINN_SEARCH failed: ${error.runtimeType}');
      return SearchTurnResult(
        groundedContext: noResultsNote,
        failed: true,
        activity: activity,
      );
    }
  }

  /// The note the model sees when retrieval produced nothing.
  static const String noResultsNote =
      'Note: a web search was attempted but no results were available '
      '(offline or unavailable). Answer carefully from general knowledge, '
      'say plainly that the answer may be out of date, and do not invent '
      'sources.';
}

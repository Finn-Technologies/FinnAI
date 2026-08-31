import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'web_search_service.dart';

@immutable
class GroundedSearchResult {
  const GroundedSearchResult({
    required this.search,
    required this.groundedContext,
  });

  final WebSearchResult search;
  final String groundedContext;
}

enum SearchDecisionKind { search, answerFromKnowledge }

@immutable
class SearchDecision {
  const SearchDecision({
    required this.kind,
    this.query,
    this.toolName = 'browser_search',
    this.arguments = const {},
  });

  final SearchDecisionKind kind;
  final String? query;
  final String toolName;
  final Map<String, dynamic> arguments;

  @override
  bool operator ==(Object other) =>
      other is SearchDecision &&
      other.kind == kind &&
      other.query == query &&
      other.toolName == toolName;

  @override
  int get hashCode => Object.hash(kind, query, toolName);
}

typedef ToolCallParser = SearchDecisionParser;

/// Parses tool calls emitted by the AI model during reasoning and inference.
///
/// Supports standard LLM tool calling XML schemas (`<tool_call>` JSON `</tool_call>`),
/// function-call signatures (`browser_search(query="...")`), and forgiving
/// variations (tagged, colon, and bare phrases). Unparseable output fails
/// safe to answering from knowledge rather than running a malformed query.
class SearchDecisionParser {
  const SearchDecisionParser();

  SearchDecision parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const SearchDecision(kind: SearchDecisionKind.answerFromKnowledge);
    }

    // 1. Explicit <tool_call>...</tool_call> XML blocks emitted by ChatML/Qwen models
    final toolCallTagMatch = RegExp(
      r'<tool_call>([\s\S]*?)(?:</tool_call>|$)',
      caseSensitive: false,
    ).firstMatch(value);
    if (toolCallTagMatch != null) {
      final inner = toolCallTagMatch.group(1)!.trim();
      final parsed = _parseToolCallContent(inner);
      if (parsed != null) return parsed;
    }

    // 2. Bare JSON object: {"name": "browser_search", "arguments": {"query": "..."}}
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(value);
    if (jsonMatch != null) {
      final parsed = _parseToolCallContent(jsonMatch.group(0)!);
      if (parsed != null) return parsed;
    }

    // 3. Function call syntax: browser_search(query="...") or search_browser("...")
    final funcMatch = RegExp(
      r'^(?:browser_search|search_browser|web_search|browse|search)\s*\(\s*(?:query\s*=\s*)?["'
      "'"
      r']?([^"'
      "'"
      r'\)]+)["'
      "'"
      r']?\s*\)',
      caseSensitive: false,
    ).firstMatch(value);

    if (funcMatch != null) {
      final q = _cleanQuery(funcMatch.group(1));
      if (q != null) {
        return SearchDecision(
          kind: SearchDecisionKind.search,
          query: q,
          toolName: 'browser_search',
        );
      }
    }

    // 4. Tagged forms: "<search>q</search>", "<browser_search>q</browser_search>",
    // "SEARCH: q", "BROWSER SEARCH: q", "web search: q"
    final tagged = RegExp(
      r'(?:<search>|<browser_search>|browser\s*search\s*:\s*|search\s*:\s*|web\s*search\s*:\s*)\s*([^<\n]+)',
      caseSensitive: false,
    ).firstMatch(value);
    final taggedQuery = _cleanQuery(tagged?.group(1));
    if (taggedQuery != null) {
      return SearchDecision(
        kind: SearchDecisionKind.search,
        query: taggedQuery,
        toolName: 'browser_search',
      );
    }

    // 5. Bare forms: "SEARCH q", "search for q", "look up q",
    // "search the web for q", "search the browser for q"
    final bare = RegExp(
      r'^(?:search|look\s*up|web\s*search|browser\s*search)(?:\s+the\s+(?:web|browser|internet))?(?:\s+for)?\s+([^\n]+)$',
      caseSensitive: false,
    ).firstMatch(value);
    final bareQuery = _cleanQuery(bare?.group(1));
    if (bareQuery != null) {
      return SearchDecision(
        kind: SearchDecisionKind.search,
        query: bareQuery,
        toolName: 'browser_search',
      );
    }

    return const SearchDecision(kind: SearchDecisionKind.answerFromKnowledge);
  }

  static SearchDecision? _parseToolCallContent(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final toolName = decoded['name']?.toString() ?? 'browser_search';
        final args = decoded['arguments'] ?? decoded['parameters'];
        if (args is Map<String, dynamic>) {
          final query = args['query']?.toString() ?? args['q']?.toString();
          final cleaned = _cleanQuery(query);
          if (cleaned != null) {
            return SearchDecision(
              kind: SearchDecisionKind.search,
              query: cleaned,
              toolName: toolName,
              arguments: args,
            );
          }
        } else if (decoded.containsKey('query')) {
          final query = decoded['query']?.toString();
          final cleaned = _cleanQuery(query);
          if (cleaned != null) {
            return SearchDecision(
              kind: SearchDecisionKind.search,
              query: cleaned,
              toolName: toolName,
              arguments: decoded,
            );
          }
        }
      }
    } catch (_) {
      // If not strict JSON, inspect content inside tool call tag
      final cleaned = _cleanQuery(trimmed);
      if (cleaned != null &&
          !cleaned.startsWith('{') &&
          !cleaned.toLowerCase().startsWith('answer')) {
        return SearchDecision(
          kind: SearchDecisionKind.search,
          query: cleaned,
          toolName: 'browser_search',
        );
      }
    }
    return null;
  }

  static String? _cleanQuery(String? raw) {
    if (raw == null) return null;
    final query = raw
        .replaceAll(
          RegExp(
            r'</?(?:search|browser_search|tool_call)>',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[<>]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?;]+$'), '')
        .trim();
    return query.isEmpty ? null : query;
  }
}

/// Coordinates search results and small, public-page excerpts without ever
/// sending conversation history or profile data to the network.
class SearchAgent {
  SearchAgent({WebSearchService? searchService, http.Client? client})
    : searchService = searchService ?? WebSearchService(client: client);

  final WebSearchService searchService;

  WebSearchPolicy get policy => searchService.policy;

  /// Hard cap on each fetched excerpt to keep prompt prefill extremely fast
  /// and KV memory tiny on entry-level and low-end mobile devices.
  static const int maxExcerptChars = 350;

  /// Rebuilds a bounded, citation-numbered prompt context from persisted sources.
  static String groundedContextForSources(List<WebSource> sources) {
    if (sources.isEmpty) return '';
    final context = StringBuffer('''
RETRIEVED BROWSER RESULTS
Use these factual excerpts from the background browser to answer the request accurately.
Cite matching source indices inline like [1], [2].
''');
    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      final excerpt = source.snippet.length <= maxExcerptChars
          ? source.snippet
          : '${source.snippet.substring(0, maxExcerptChars)}…';
      context
        ..writeln('\n[${index + 1}] ${source.title}')
        ..writeln('URL: ${source.url}')
        ..writeln('Excerpt: $excerpt');
    }
    return context.toString().trim();
  }

  Future<GroundedSearchResult?> searchAndFetch(String query) async {
    final search = await searchService.search(query);
    if (search == null) return null;

    final excerpts = await Future.wait([
      for (final source in search.sources.take(3))
        () async {
          // If the search snippet is already informative (>100 chars), use it directly
          // without an extra HTTP roundtrip to maximize speed.
          if (source.snippet.length >= 100 &&
              !source.snippet.contains('No excerpt available.')) {
            return source;
          }
          final pageText = await searchService
              .fetchPageText(source.url)
              .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
          return WebSource(
            title: source.title,
            url: source.url,
            snippet: pageText == null || pageText.isEmpty
                ? source.snippet
                : pageText,
          );
        }(),
    ]);
    final enriched = WebSearchResult(query: search.query, sources: excerpts);
    return GroundedSearchResult(
      search: enriched,
      groundedContext: groundedContextForSources(enriched.sources),
    );
  }
}

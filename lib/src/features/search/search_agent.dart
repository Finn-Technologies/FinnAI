import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:finn_ai/src/features/search/tiny_browser.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/inference/prompt_formatter.dart';

@immutable
class GroundedSearchResult {
  const GroundedSearchResult({
    required this.search,
    required this.groundedContext,
  });

  final WebSearchResult search;
  final String groundedContext;
}

enum SearchDecisionKind {
  search,
  open,
  find,
  answerFromKnowledge,
}

@immutable
class SearchDecision {
  const SearchDecision({
    required this.kind,
    this.query,
    this.url,
    this.toolName = 'browser_search',
    this.arguments = const {},
  });

  final SearchDecisionKind kind;
  final String? query;
  final String? url;
  final String toolName;
  final Map<String, dynamic> arguments;

  @override
  bool operator ==(Object other) =>
      other is SearchDecision &&
      other.kind == kind &&
      other.query == query &&
      other.url == url &&
      other.toolName == toolName;

  @override
  int get hashCode => Object.hash(kind, query, url, toolName);
}

typedef ToolCallParser = SearchDecisionParser;

/// Which browser tool a [ToolActivity] records.
enum ToolActivityKind { search, open, find }

/// One browser tool call the model made, as the UI shows it.
///
/// Kept as display-ready data so the chat can render "what the agent is doing"
/// without knowing anything about prompts or tool-call syntax.
@immutable
class ToolActivity {
  const ToolActivity({
    required this.kind,
    required this.label,
    this.detail = '',
  });

  final ToolActivityKind kind;

  /// The primary text: a search query, a page title, or a searched term.
  final String label;

  /// Supporting text: the opened URL, or the matched passage.
  final String detail;
}

/// Parses browser tool calls emitted by the AI model during reasoning and inference.
///
/// Supports standard LLM tool calling XML schemas (`<tool_call>` JSON `</tool_call>`),
/// function-call signatures (`browser_search(query="...")`, `browser_open(url="...")`),
/// and forgiving variations. Unparseable output fails safe to answering from knowledge.
class SearchDecisionParser {
  const SearchDecisionParser();

  SearchDecision parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const SearchDecision(kind: SearchDecisionKind.answerFromKnowledge);
    }

    // 1. Explicit <tool_call>...</tool_call> XML blocks emitted by ChatML/Qwen/Llama models
    //
    // A closing tag is required. The pattern used to accept an *unterminated*
    // tag too, so a generation that was cut off mid-call was parsed as a
    // complete call and browsed for whatever text came next.
    final toolCallTagMatch = RegExp(
      r'<tool_call>([\s\S]*?)</tool_call>',
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

    // 3. Function call syntax:
    // browser_open(url="https://...") or open_url("https://...")
    final openMatch = RegExp(
      r'^(?:browser_open|open_url|open|navigate|visit)\s*\(\s*(?:url\s*=\s*)?["'
      "'"
      r']?([^"'
      "'"
      r'\)]+)["'
      "'"
      r']?\s*\)',
      caseSensitive: false,
    ).firstMatch(value);

    if (openMatch != null) {
      final u = _cleanQuery(openMatch.group(1));
      if (u != null) {
        return SearchDecision(
          kind: SearchDecisionKind.open,
          url: u,
          query: u,
          toolName: 'browser_open',
        );
      }
    }

    // browser_search(query="...") or search_browser("...")
    final searchMatch = RegExp(
      r'^(?:browser_search|search_browser|web_search|browse|search)\s*\(\s*(?:query\s*=\s*)?["'
      "'"
      r']?([^"'
      "'"
      r'\)]+)["'
      "'"
      r']?\s*\)',
      caseSensitive: false,
    ).firstMatch(value);

    if (searchMatch != null) {
      final q = _cleanQuery(searchMatch.group(1));
      if (q != null) {
        return SearchDecision(
          kind: SearchDecisionKind.search,
          query: q,
          toolName: 'browser_search',
        );
      }
    }

    // browser_find(query="...")
    final findMatch = RegExp(
      r'^(?:browser_find|find_on_page|find)\s*\(\s*(?:query\s*=\s*)?["'
      "'"
      r']?([^"'
      "'"
      r'\)]+)["'
      "'"
      r']?\s*\)',
      caseSensitive: false,
    ).firstMatch(value);

    if (findMatch != null) {
      final q = _cleanQuery(findMatch.group(1));
      if (q != null) {
        return SearchDecision(
          kind: SearchDecisionKind.find,
          query: q,
          toolName: 'browser_find',
        );
      }
    }

    // 4. Tagged open forms: "<open>url</open>", "OPEN: url", "NAVIGATE: url"
    final taggedOpen = RegExp(
      r'(?:<open>|<browser_open>|open\s*:\s*|navigate\s*:\s*)\s*([^<\n]+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (taggedOpen != null) {
      final u = _cleanQuery(taggedOpen.group(1));
      if (u != null) {
        return SearchDecision(
          kind: SearchDecisionKind.open,
          url: u,
          query: u,
          toolName: 'browser_open',
        );
      }
    }

    // 5. Tagged search forms: "<search>q</search>", "<browser_search>q</browser_search>",
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

    // 6. Bare forms: "SEARCH q", "search for q", "look up q"
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
        final toolName =
            (decoded['name']?.toString() ?? 'browser_search').toLowerCase();
        final args = decoded['arguments'] ?? decoded['parameters'] ?? decoded;

        if (toolName.contains('open') || toolName.contains('navigate')) {
          final url = args is Map<String, dynamic>
              ? (args['url']?.toString() ??
                  args['uri']?.toString() ??
                  args['target']?.toString())
              : null;
          final cleaned = _cleanQuery(url);
          if (cleaned != null) {
            return SearchDecision(
              kind: SearchDecisionKind.open,
              url: cleaned,
              query: cleaned,
              toolName: 'browser_open',
              arguments: args is Map<String, dynamic> ? args : {},
            );
          }
        }

        if (toolName.contains('find')) {
          final query = args is Map<String, dynamic>
              ? (args['query']?.toString() ??
                  args['q']?.toString() ??
                  args['keyword']?.toString())
              : null;
          final cleaned = _cleanQuery(query);
          if (cleaned != null) {
            return SearchDecision(
              kind: SearchDecisionKind.find,
              query: cleaned,
              toolName: 'browser_find',
              arguments: args is Map<String, dynamic> ? args : {},
            );
          }
        }

        // Default to browser_search
        final query = args is Map<String, dynamic>
            ? (args['query']?.toString() ?? args['q']?.toString())
            : null;
        final cleaned = _cleanQuery(query);
        if (cleaned != null) {
          return SearchDecision(
            kind: SearchDecisionKind.search,
            query: cleaned,
            toolName: 'browser_search',
            arguments: args is Map<String, dynamic> ? args : {},
          );
        }
      }
    } catch (_) {
      // Not strict JSON. The old behaviour here read *any* leftover text out
      // of a tool-call tag and issued a search for it, which is how a
      // malformed turn turned into a web request: on the device a question
      // with no browsing need at all spent ~3s in a search before answering
      // from knowledge anyway.
      //
      // An unterminated `<tool_call>` is a truncated generation, not a
      // request. Treating it as no decision lets the turn answer from
      // knowledge instead of guessing a query out of the model's
      // half-finished thought.
      if (RegExp(r'<tool_call>', caseSensitive: false).hasMatch(trimmed)) {
        return null;
      }
      final cleaned = _cleanQuery(trimmed);
      if (cleaned != null &&
          !cleaned.startsWith('{') &&
          !cleaned.toLowerCase().startsWith('answer')) {
        if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
          return SearchDecision(
            kind: SearchDecisionKind.open,
            url: cleaned,
            query: cleaned,
            toolName: 'browser_open',
          );
        }
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
            r'</?(?:search|browser_search|browser_open|open|tool_call)>',
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

/// Coordinates autonomous browser actions and grounded results for Finn AI.
class SearchAgent {
  SearchAgent({
    WebSearchService? searchService,
    TinyBrowser? browser,
    http.Client? client,
  })  : searchService = searchService ?? WebSearchService(client: client),
        browser = browser ?? TinyBrowser(client: client);

  final WebSearchService searchService;
  final TinyBrowser browser;

  WebSearchPolicy get policy => searchService.policy;

  /// Hard cap on each fetched excerpt to keep prompt prefill extremely fast
  /// and KV memory tiny on mobile devices.
  static const int maxExcerptChars = 350;

  /// Rebuilds a bounded, citation-numbered prompt context from persisted sources.
  static String groundedContextForSources(List<WebSource> sources) {
    if (sources.isEmpty) return '';
    // The heading must be the marker [PromptFormatter.groundedContextMarker];
    // the prompt builders key off it to tell retrieved reference material
    // apart from the user's private configuration.
    // This used to ask for "an authoritative article summary" on every grounded
    // turn, and the findings came back as the reply: "What is the capital of
    // France?" produced a headline, a lead paragraph and a [1]/[2]/[3] walk
    // through the reference blocks. Bans alone were not enough either — with
    // nothing positive to imitate the model answered with a bare "[1]". So the
    // block now shows the shape of a correct answer as well as naming it.
    final context = StringBuffer('''
${PromptFormatter.groundedContextMarker}:
Answer the question below in your own words, using these findings as background.

Rules:
- Answer first and keep it as short as the question deserves. A direct question gets one or two sentences: no title, no headings, no bullet points. Add structure only when the user asked for an overview of a broad topic.
- Put a citation like [1] inside the sentence it supports. Never print a citation on a line of its own.
- Never print, quote or summarise these findings. They are background, not the answer.

Example:
Findings: [1] France — Paris is the capital and largest city of France.
Question: What is the capital of France?
Answer: Paris is the capital of France.[1]
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

  /// Executes an autonomous tool call issued by Finn AI and returns the string
  /// response to feed back into the model's context, along with a display-ready
  /// [ToolActivity] describing what was done.
  Future<
      ({
        String toolResponse,
        List<WebSource> discoveredSources,
        ToolActivity activity,
      })> executeToolCall(
    SearchDecision decision,
  ) async {
    switch (decision.kind) {
      case SearchDecisionKind.search:
        final q = decision.query ?? '';
        final results = await browser.search(q);
        if (results.isEmpty) {
          return (
            toolResponse:
                'No web results found for "$q". Try another query or verify with general knowledge.',
            discoveredSources: const <WebSource>[],
            activity: ToolActivity(kind: ToolActivityKind.search, label: q),
          );
        }
        final sources = results.map((r) => r.toWebSource()).toList();
        final buffer = StringBuffer('TinyBrowser Search Results for "$q":\n');
        for (var i = 0; i < results.length; i++) {
          final r = results[i];
          buffer.writeln(
              '\n[${i + 1}] ${r.title}\nURL: ${r.url}\nSnippet: ${r.snippet}');
        }
        return (
          toolResponse: buffer.toString().trim(),
          discoveredSources: sources,
          activity: ToolActivity(kind: ToolActivityKind.search, label: q),
        );

      case SearchDecisionKind.open:
        final u = decision.url ?? decision.query ?? '';
        final page = await browser.open(u);
        if (page == null) {
          return (
            toolResponse:
                'Failed to open page at "$u". (Page may be offline or unreachable).',
            discoveredSources: const <WebSource>[],
            activity: ToolActivity(
              kind: ToolActivityKind.open,
              label: Uri.tryParse(u)?.host ?? u,
              detail: u,
            ),
          );
        }
        final source = page.toWebSource();
        final response =
            StringBuffer('TinyBrowser Opened Page: "${page.title}"\n')
              ..writeln('URL: ${page.url}')
              ..writeln('\nExtracted Content:\n${page.text}');
        if (page.links.isNotEmpty) {
          // Offering the page's own links lets the next round navigate by name
          // instead of inventing a URL.
          response.writeln('\nLinks on this page:');
          for (final link in page.links.take(10)) {
            response.writeln('- ${link.text} -> ${link.url}');
          }
        }
        if (page.imageUrls.isNotEmpty) {
          response.writeln('\nDiscovered Images: ${page.imageUrls.join(', ')}');
        }
        return (
          toolResponse: response.toString().trim(),
          discoveredSources: [source],
          activity: ToolActivity(
            kind: ToolActivityKind.open,
            label: page.title,
            detail: page.url.toString(),
          ),
        );

      case SearchDecisionKind.find:
        final q = decision.query ?? '';
        final matches = browser.find(q);
        return (
          toolResponse:
              matches ?? 'No text matching "$q" found on current page.',
          discoveredSources: const <WebSource>[],
          activity: ToolActivity(
            kind: ToolActivityKind.find,
            label: q,
            detail: matches == null
                ? ''
                : matches.length > 120
                    ? '${matches.substring(0, 120)}…'
                    : matches,
          ),
        );

      case SearchDecisionKind.answerFromKnowledge:
        return (
          toolResponse: '',
          discoveredSources: const <WebSource>[],
          activity: const ToolActivity(
            kind: ToolActivityKind.search,
            label: '',
          ),
        );
    }
  }

  Future<GroundedSearchResult?> searchAndFetch(String query) async {
    final search = await searchService.search(query);
    if (search == null) return null;

    final excerpts = await Future.wait([
      for (final source in search.sources.take(3))
        () async {
          if (source.snippet.length >= 100 &&
              !source.snippet.contains('No excerpt available.')) {
            return source;
          }
          final pageText = await searchService
              .fetchPageText(source.url)
              .timeout(const Duration(milliseconds: 1500),
                  onTimeout: () => null);
          return WebSource(
            title: source.title,
            url: source.url,
            snippet: pageText == null || pageText.isEmpty
                ? source.snippet
                : pageText,
            imageUrl: source.imageUrl,
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

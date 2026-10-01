import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

/// Which browser tool a [ToolActivity] records.
enum ToolActivityKind { search, open, find, you }

/// One step of a turn's search, as the UI shows it.
///
/// Display-ready data so the chat can render "what Finn looked up" without
/// knowing anything about prompts. The app records it; the model never does.
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

/// Fetches and shapes grounded results for one bounded search.
class SearchAgent {
  SearchAgent({
    WebSearchService? searchService,
    http.Client? client,
  }) : searchService = searchService ?? WebSearchService(client: client);

  final WebSearchService searchService;

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

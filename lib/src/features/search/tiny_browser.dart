import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'package:finn_ai/src/features/search/shared_http_client.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart'
    show WebSource;

/// A single search result item returned by [TinyBrowser.search].
@immutable
class BrowserSearchResult {
  const BrowserSearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.iconUrl,
  });

  final String title;
  final Uri url;
  final String snippet;
  final String? iconUrl;

  WebSource toWebSource() => WebSource(
        title: title,
        url: url,
        snippet: snippet,
        imageUrl: iconUrl,
      );

  @override
  String toString() => '[$title]($url)\n$snippet';
}

/// A parsed web page loaded by [TinyBrowser.open].
@immutable
class BrowserPage {
  const BrowserPage({
    required this.url,
    required this.title,
    required this.text,
    this.imageUrls = const [],
    this.links = const [],
    this.openedAt,
  });

  final Uri url;
  final String title;
  final String text;
  final List<String> imageUrls;

  /// Followable links on the page, in document order.
  final List<({String text, Uri url})> links;

  /// When the page was fetched, used to order the browsing history.
  final DateTime? openedAt;

  WebSource toWebSource() => WebSource(
        title: title,
        url: url,
        snippet: text.length > 350 ? '${text.substring(0, 350)}…' : text,
        imageUrl: imageUrls.firstOrNull,
      );

  @override
  String toString() => '''
Page Title: $title
URL: $url
Content:
$text
Images: ${imageUrls.join(', ')}
''';
}

/// A purpose-built headless browser the model drives through tool calls.
///
/// Gives the agent the ability to search the web, open a URL, read clean text,
/// follow links, and search within a page — with a real back/forward history so
/// a multi-step research pass can back out of a dead end. It executes no
/// JavaScript, which is a deliberate constraint: it keeps the browser to a
/// pure-Dart HTTP client that behaves identically everywhere the app runs.
class TinyBrowser {
  TinyBrowser({
    http.Client? client,
    this.onBrowserAction,
  })  : _client = client ?? SharedHttpClient.instance.client,
        _ownsClient = client != null;

  /// The client every search component shares.
  ///
  /// This used to be `http.Client()`, and `WebSearchService` created its own,
  /// so one turn opened two connection pools and neither reused the other's
  /// TLS session. On a phone that is two cold handshakes for what is one
  /// conversation with a website. It is also never closed, which is why a
  /// per-continuation `SearchAgent` in the chat shell was leaking a pool each
  /// time the user hit "continue".
  final http.Client _client;

  /// Whether [close] may close [client]. False for the shared process-wide
  /// pool, which outlives any one browser.
  final bool _ownsClient;

  @visibleForTesting
  http.Client get client => _client;

  /// Called with a short human-readable description of each action, so the UI
  /// can show what the agent is doing while it browses.
  final void Function(String action)? onBrowserAction;

  /// Longest history retained, oldest entries dropped first.
  static const int maxHistory = 20;

  /// Cache bounds.
  ///
  /// Both caches used to be unbounded maps with no expiry, so a long session
  /// that browsed a lot accumulated every page body it had ever fetched. A
  /// page is a truncated excerpt, but a few hundred of them is tens of
  /// megabytes of Dart heap on a device that has 7GiB in total and the model
  /// holding 1.6GB of it.
  static const int maxPageCacheEntries = 24;
  static const int maxSearchCacheEntries = 24;
  static const Duration cacheTtl = Duration(minutes: 15);

  final Map<String, ({BrowserPage page, DateTime at})> _pageCache = {};
  final Map<String, ({List<BrowserSearchResult> results, DateTime at})>
      _searchCache = {};

  final List<BrowserPage> _history = [];
  int _historyIndex = -1;

  /// Evicts the oldest entries once a cache is full.
  ///
  /// Insertion-ordered, so the first key in the map is the least recently
  /// added; re-inserting on read would be true LRU, but these caches are read
  /// a handful of times per turn and a turn is seconds long, so recency within
  /// a turn buys nothing over insertion order.
  static void _evictTo<T>(Map<String, T> cache, int limit) {
    while (cache.length > limit) {
      cache.remove(cache.keys.first);
    }
  }

  BrowserPage? get currentPage =>
      _historyIndex >= 0 && _historyIndex < _history.length
          ? _history[_historyIndex]
          : null;

  /// Pages visited this session, oldest first.
  List<BrowserPage> get history => List.unmodifiable(_history);

  bool get canGoBack => _historyIndex > 0;

  bool get canGoForward =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  /// Releases the client, if this instance owns it.
  ///
  /// The default client is the process-wide pool and is not closed here: the
  /// chat shell disposes a browser per continuation, and closing the shared
  /// pool would break the next search in the session. Only an injected client
  /// belongs to this instance.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Empties the history without touching the caches.
  void reset() {
    _history.clear();
    _historyIndex = -1;
  }

  /// Steps back one page in the session history.
  BrowserPage? back() {
    if (!canGoBack) return null;
    _historyIndex--;
    onBrowserAction?.call('Back to "${_history[_historyIndex].title}"');
    return _history[_historyIndex];
  }

  /// Steps forward one page in the session history.
  BrowserPage? forward() {
    if (!canGoForward) return null;
    _historyIndex++;
    onBrowserAction?.call('Forward to "${_history[_historyIndex].title}"');
    return _history[_historyIndex];
  }

  static String cleanSearchQuery(String query) {
    var q = query.trim();
    q = q.replaceFirst(
      RegExp(
        r'^(?:what is|what are|who is|who are|where is|where are|when was|when were|why is|why are|how does|how do|tell me about|explain|search for|cerca|qué es|que es)\s+',
        caseSensitive: false,
      ),
      '',
    );
    q = q.replaceFirst(RegExp(r'^(?:the|a|an)\s+', caseSensitive: false), '');
    q = q.replaceAll(RegExp(r'[?!.,;]+$'), '').trim();
    return q.isNotEmpty ? q : query.trim();
  }

  /// Searches the web across multiple search endpoints in parallel.
  Future<List<BrowserSearchResult>> search(
    String query, {
    int maxResults = 5,
    Duration timeout = const Duration(milliseconds: 3000),
  }) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return const [];

    final searchParam = cleanSearchQuery(cleanQ);
    final cacheKey = searchParam.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < cacheTtl) {
      return cached.results;
    }
    _searchCache.remove(cacheKey);

    onBrowserAction?.call('Searching the web for "$searchParam"');

    try {
      final results = await Future.wait([
        _searchWikipedia(searchParam, limit: maxResults)
            .timeout(timeout, onTimeout: () => []),
        _searchDuckDuckGo(searchParam).timeout(timeout, onTimeout: () => []),
      ]);

      final allResults = <BrowserSearchResult>[];
      final seenUrls = <String>{};

      for (final list in results) {
        for (final item in list) {
          final u = item.url.toString();
          if (!seenUrls.contains(u)) {
            seenUrls.add(u);
            allResults.add(item);
          }
        }
      }

      final bounded = allResults.take(maxResults).toList();
      _searchCache[cacheKey] = (results: bounded, at: DateTime.now());
      _evictTo(_searchCache, maxSearchCacheEntries);
      return bounded;
    } catch (e) {
      debugPrint('TinyBrowser search error: $e');
      return const [];
    }
  }

  /// Navigates to a URL, parses the HTML, and extracts clean text, images and
  /// followable links.
  Future<BrowserPage?> open(
    String urlString, {
    int maxChars = 2200,
    Duration timeout = const Duration(milliseconds: 3500),
  }) async {
    final uri = Uri.tryParse(urlString.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final cacheKey = uri.toString();
    final cached = _pageCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < cacheTtl) {
      _record(cached.page);
      return cached.page;
    }
    _pageCache.remove(cacheKey);

    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    onBrowserAction?.call('Reading $host');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 FinnAI/1.0',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(timeout);

      if (response.statusCode != 200) return null;

      final page = parsePage(
        uri,
        response.body,
        maxChars: maxChars,
        openedAt: DateTime.now(),
      );
      _pageCache[cacheKey] = (page: page, at: DateTime.now());
      _evictTo(_pageCache, maxPageCacheEntries);
      _record(page);
      return page;
    } catch (e) {
      debugPrint('TinyBrowser open error: $e');
      return null;
    }
  }

  /// Searches within the currently active page (or a specified URL) for matching
  /// text passages.
  String? find(String keyword, {String? url}) {
    final page = url != null ? _pageCache[url]?.page : currentPage;
    if (page == null) return null;

    final q = keyword.toLowerCase().trim();
    if (q.isEmpty) return null;

    final paragraphs = page.text.split('\n');
    final matches =
        paragraphs.where((p) => p.toLowerCase().contains(q)).take(4);
    if (matches.isEmpty) return null;

    return matches.join('\n\n');
  }

  /// Links on the current page matching [keyword], so the agent can navigate by
  /// name instead of guessing a URL.
  List<({String text, Uri url})> findLinks(String keyword) {
    final page = currentPage;
    if (page == null) return const [];
    final q = keyword.toLowerCase().trim();
    if (q.isEmpty) return page.links.take(10).toList(growable: false);
    return page.links
        .where((link) =>
            link.text.toLowerCase().contains(q) ||
            link.url.toString().toLowerCase().contains(q))
        .take(10)
        .toList(growable: false);
  }

  /// Appends [page] to the session history, dropping any forward entries — the
  /// same rule a normal browser follows after a new navigation.
  void _record(BrowserPage page) {
    if (_historyIndex >= 0 &&
        _historyIndex < _history.length &&
        _history[_historyIndex].url == page.url) {
      return;
    }
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(page);
    if (_history.length > maxHistory) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
  }

  /// Parses [html] into a [BrowserPage]. Exposed for tests.
  @visibleForTesting
  static BrowserPage parsePage(
    Uri uri,
    String html, {
    int maxChars = 2200,
    DateTime? openedAt,
  }) {
    final dom.Document document;
    try {
      document = html_parser.parse(html);
    } on Object {
      return BrowserPage(
        url: uri,
        title: uri.host,
        text: 'No readable text extracted from page.',
        openedAt: openedAt,
      );
    }

    // Read metadata before stripping: the shares live in the head.
    final ogTitle = _metaContent(document, 'og:title');
    final images = _images(document, uri);

    for (final selector in const [
      'script',
      'style',
      'noscript',
      'nav',
      'header',
      'footer',
      'aside',
      'form',
      'iframe',
      'svg',
      'template',
    ]) {
      document
          .querySelectorAll(selector)
          .forEach((element) => element.remove());
    }

    final links = _links(document, uri);
    final title = _squash(
      ogTitle ??
          document.querySelector('title')?.text ??
          _metaContent(document, 'twitter:title') ??
          uri.host,
    );
    final text = _readableText(document, maxChars: maxChars);

    return BrowserPage(
      url: uri,
      title: title.isEmpty ? uri.host : title,
      text: text,
      imageUrls: images,
      links: links,
      openedAt: openedAt,
    );
  }

  static String _readableText(dom.Document document, {required int maxChars}) {
    // Prefer prose blocks: a div-soup fallback drags in menus and legal noise.
    final blocks = <String>[];
    for (final element in document.querySelectorAll(
      'p, h1, h2, h3, h4, h5, h6, li, blockquote, pre, td, figcaption',
    )) {
      final text = _squash(element.text);
      if (text.length > 15 && !_isJunkLine(text)) blocks.add(text);
    }

    if (blocks.length < 3) {
      final body = document.body;
      if (body != null) {
        for (final line in body.text.split('\n')) {
          final text = _squash(line);
          if (text.length > 15 && !_isJunkLine(text)) blocks.add(text);
        }
      }
    }

    final deduped = <String>[];
    for (final block in blocks) {
      if (deduped.isEmpty || deduped.last != block) deduped.add(block);
    }

    var body = deduped.join('\n\n').trim();
    if (body.isEmpty) return 'No readable text extracted from page.';
    if (body.length > maxChars) {
      final cutoff = body.lastIndexOf('.', maxChars);
      body = cutoff > maxChars * 0.7
          ? body.substring(0, cutoff + 1)
          : '${body.substring(0, maxChars)}…';
    }
    return body;
  }

  static List<String> _images(dom.Document document, Uri base) {
    final images = <String>[];
    void add(String? candidate) {
      if (candidate == null || images.length >= 4) return;
      final resolved = _absolute(base, candidate);
      if (resolved == null) return;
      final url = resolved.toString();
      if (!images.contains(url) && _isValidImageUrl(url)) {
        images.add(url);
      }
    }

    add(_metaContent(document, 'og:image'));
    add(_metaContent(document, 'twitter:image'));
    for (final element in document.querySelectorAll('img')) {
      if (images.length >= 4) break;
      add(element.attributes['src'] ?? element.attributes['data-src']);
    }
    return images;
  }

  /// Links the agent can follow, capped so a nav-heavy page cannot flood the
  /// prompt with hundreds of entries.
  static List<({String text, Uri url})> _links(
      dom.Document document, Uri base) {
    const limit = 30;
    final links = <({String text, Uri url})>[];
    final seen = <String>{};
    for (final element in document.querySelectorAll('a[href]')) {
      if (links.length >= limit) break;
      final href = element.attributes['href'];
      if (href == null) continue;
      final resolved = _absolute(base, href);
      if (resolved == null) continue;
      final key = resolved.toString();
      if (!seen.add(key)) continue;
      final text = _squash(element.text);
      links.add((text: text.isEmpty ? key : text, url: resolved));
    }
    return links;
  }

  static String? _metaContent(dom.Document document, String property) {
    for (final element in document.querySelectorAll('meta')) {
      final name =
          element.attributes['property'] ?? element.attributes['name'] ?? '';
      if (name.toLowerCase() == property) {
        final content = element.attributes['content']?.trim();
        if (content != null && content.isNotEmpty) return content;
      }
    }
    return null;
  }

  /// Resolves [href] against [base], rejecting non-web and fragment-only links.
  static Uri? _absolute(Uri base, String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:') ||
        lower.startsWith('data:')) {
      return null;
    }
    final resolved = base.resolve(trimmed);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    return resolved;
  }

  static String _squash(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<List<BrowserSearchResult>> _searchWikipedia(String query,
      {int limit = 4}) async {
    try {
      final searchUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'opensearch',
        'search': query,
        'limit': '$limit',
        'namespace': '0',
        'format': 'json',
      });

      final res = await _client.get(
        searchUri,
        headers: {'User-Agent': 'FinnAI/1.0 (Mobile; HeadlessTinyBrowser)'},
      );

      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body);

      // Handle Map-based Wikimedia API responses ({ query: { pages: [...] } })
      if (json is Map<String, dynamic>) {
        final queryObj = json['query'];
        if (queryObj is Map<String, dynamic>) {
          final pagesObj = queryObj['pages'];
          final pages = pagesObj is List
              ? pagesObj
              : pagesObj is Map
                  ? pagesObj.values.toList()
                  : const <dynamic>[];
          final list = <BrowserSearchResult>[];
          for (final item in pages) {
            if (item is Map<String, dynamic>) {
              final title = item['title']?.toString() ?? '';
              final extract = item['extract']?.toString() ?? '';
              final url = item['fullurl']?.toString() ??
                  'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';
              final thumb = item['thumbnail'] is Map
                  ? item['thumbnail']['source']?.toString()
                  : null;
              final parsed = Uri.tryParse(url);
              if (title.isNotEmpty && parsed != null) {
                list.add(
                  BrowserSearchResult(
                    title: title,
                    url: parsed,
                    snippet: extract.isNotEmpty
                        ? extract
                        : 'Wikipedia article on $title.',
                    iconUrl: thumb,
                  ),
                );
              }
            }
          }
          if (list.isNotEmpty) return list;
        }
      }

      // Handle standard OpenSearch format ([query, [titles], [descriptions], [urls]])
      if (json is! List || json.length < 4) return const [];

      final titles = json[1] as List<dynamic>;
      final snippets = json[2] as List<dynamic>;
      final urls = json[3] as List<dynamic>;

      final list = <BrowserSearchResult>[];
      for (var i = 0; i < titles.length; i++) {
        final title = titles[i].toString().trim();
        final snippet =
            snippets.length > i ? snippets[i].toString().trim() : '';
        final urlStr = urls.length > i ? urls[i].toString().trim() : '';
        final parsedUrl = Uri.tryParse(urlStr);

        if (title.isNotEmpty && parsedUrl != null) {
          list.add(
            BrowserSearchResult(
              title: title,
              url: parsedUrl,
              snippet:
                  snippet.isNotEmpty ? snippet : 'Wikipedia article on $title.',
            ),
          );
        }
      }
      if (list.isNotEmpty) return list;

      // 3. Fallback: Full-text Wikipedia Search API (action=query&list=search)
      final fullTextUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'list': 'search',
        'srsearch': query,
        'format': 'json',
        'srlimit': '$limit',
      });
      final fullTextRes = await _client.get(
        fullTextUri,
        headers: {'User-Agent': 'FinnAI/1.0 (Mobile; HeadlessTinyBrowser)'},
      );
      if (fullTextRes.statusCode == 200) {
        final ftJson = jsonDecode(fullTextRes.body);
        if (ftJson is Map<String, dynamic>) {
          final queryMap = ftJson['query'];
          if (queryMap is Map<String, dynamic>) {
            final searchItems = queryMap['search'];
            if (searchItems is List) {
              final ftList = <BrowserSearchResult>[];
              for (final item in searchItems) {
                if (item is Map<String, dynamic>) {
                  final title = item['title']?.toString() ?? '';
                  final snippetHtml = item['snippet']?.toString() ?? '';
                  final cleanSnippet = snippetHtml
                      .replaceAll(RegExp(r'<[^>]+>'), '')
                      .replaceAll('&quot;', '"')
                      .replaceAll('&amp;', '&');
                  final url =
                      'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';
                  final parsed = Uri.tryParse(url);
                  if (title.isNotEmpty && parsed != null) {
                    ftList.add(
                      BrowserSearchResult(
                        title: title,
                        url: parsed,
                        snippet: cleanSnippet.isNotEmpty
                            ? cleanSnippet
                            : 'Wikipedia article on $title.',
                      ),
                    );
                  }
                }
              }
              if (ftList.isNotEmpty) return ftList;
            }
          }
        }
      }

      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<List<BrowserSearchResult>> _searchDuckDuckGo(String query) async {
    try {
      final uri = Uri.https('api.duckduckgo.com', '/', {
        'q': query,
        'format': 'json',
        'no_redirect': '1',
        'no_html': '1',
        'skip_disambig': '1',
      });

      final res = await _client.get(
        uri,
        headers: {'User-Agent': 'FinnAI/1.0 (Mobile; HeadlessTinyBrowser)'},
      );

      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final list = <BrowserSearchResult>[];
      final heading = (data['Heading'] ?? '').toString().trim();
      final abstractText = (data['AbstractText'] ?? '').toString().trim();
      final abstractUrl = (data['AbstractURL'] ?? '').toString().trim();
      final imgUrl = data['Image']?.toString().trim();

      if (heading.isNotEmpty && abstractUrl.isNotEmpty) {
        final parsed = Uri.tryParse(abstractUrl);
        if (parsed != null) {
          list.add(
            BrowserSearchResult(
              title: heading,
              url: parsed,
              snippet: abstractText,
              iconUrl: imgUrl != null && imgUrl.isNotEmpty
                  ? _resolveFullUrl(imgUrl)
                  : null,
            ),
          );
        }
      }

      final related = data['RelatedTopics'];
      if (related is List) {
        for (final item in related) {
          if (list.length >= 4) break;
          if (item is Map<String, dynamic>) {
            final text = (item['Text'] ?? '').toString().trim();
            final firstUrl = item['FirstURL']?.toString().trim();
            final icon = item['Icon']?['URL']?.toString().trim();
            final parsed = firstUrl != null ? Uri.tryParse(firstUrl) : null;

            if (text.isNotEmpty && parsed != null) {
              list.add(
                BrowserSearchResult(
                  title: text.split(' - ').first,
                  url: parsed,
                  snippet: text,
                  iconUrl: icon != null && icon.isNotEmpty
                      ? _resolveFullUrl(icon)
                      : null,
                ),
              );
            }
          }
        }
      }

      return list;
    } catch (_) {
      return const [];
    }
  }

  static String _resolveFullUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://duckduckgo.com$url';
  }

  static bool _isValidImageUrl(String url) {
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    if (lower.endsWith('.svg') ||
        lower.contains('tracking') ||
        lower.contains('pixel')) {
      return false;
    }
    return true;
  }

  static bool _isJunkLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('cookie') ||
        lower.contains('privacy policy') ||
        lower.contains('terms of service') ||
        lower.contains('all rights reserved') ||
        lower.contains('subscribe') ||
        lower.contains('sign in') ||
        lower.contains('log in');
  }
}

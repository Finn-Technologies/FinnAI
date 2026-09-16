import 'dart:convert';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/tiny_browser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TinyBrowser engine', () {
    test('search combines and parses Wikipedia API responses', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'en.wikipedia.org') {
          return http.Response(
            jsonEncode({
              'query': {
                'pages': [
                  {
                    'pageid': 12345,
                    'title': 'Bosque de Chapultepec',
                    'extract':
                        'Bosque de Chapultepec is a large city park in Mexico City.',
                    'thumbnail': {
                      'source':
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/chapultepec.jpg/640px-chapultepec.jpg',
                    },
                    'fullurl':
                        'https://en.wikipedia.org/wiki/Bosque_de_Chapultepec',
                  }
                ]
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final browser = TinyBrowser(client: client);
      final results = await browser.search('Bosque de Chapultepec');

      expect(results, isNotEmpty);
      final first = results.first;
      expect(first.title, 'Bosque de Chapultepec');
      expect(first.snippet, contains('large city park'));
      expect(first.iconUrl, contains('chapultepec.jpg'));
      expect(first.url.toString(), contains('Bosque_de_Chapultepec'));
    });

    test('open parses HTML, extracts clean text, images, and title', () async {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Chapultepec Park - Guide</title>
  <meta property="og:image" content="https://example.com/hero.jpg">
</head>
<body>
  <nav><a href="/">Home</a></nav>
  <script>console.log("secret");</script>
  <style>body { color: red; }</style>
  <main>
    <h1>Welcome to Chapultepec</h1>
    <p>Chapultepec is divided into four sections, housing museums and lakes.</p>
    <img src="https://example.com/castle.jpg" alt="Chapultepec Castle">
  </main>
  <footer>Copyright 2026</footer>
</body>
</html>
''';

      final client = MockClient((request) async {
        return http.Response(html, 200, headers: {'content-type': 'text/html'});
      });

      final browser = TinyBrowser(client: client);
      final page = await browser.open('https://example.com/chapultepec');

      expect(page, isNotNull);
      expect(page!.title, 'Chapultepec Park - Guide');
      expect(page.text, contains('Welcome to Chapultepec'));
      expect(page.text, contains('Chapultepec is divided into four sections'));
      expect(page.text, isNot(contains('console.log')));
      expect(page.text, isNot(contains('body { color: red; }')));
      expect(page.imageUrls, contains('https://example.com/hero.jpg'));
      expect(page.imageUrls, contains('https://example.com/castle.jpg'));

      // Test find on the opened page
      final match = browser.find('sections');
      expect(match, isNotNull);
      expect(match, contains('Chapultepec is divided into four sections'));
    });
  });

  group('TinyBrowser link extraction', () {
    const richHtml = '''
<html><head><title>Park Guide</title></head><body>
  <nav><a href="/nav-only">Nav link</a></nav>
  <main>
    <p>Chapultepec is divided into four sections with museums and lakes.</p>
    <p>Each section has its own character and attractions for visitors.</p>
    <p>Boats can be rented on the lake in the middle section.</p>
    <a href="/castle">Chapultepec Castle</a>
    <a href="https://other.example.org/zoo">Zoo</a>
    <a href="#fragment">Jump link</a>
    <a href="javascript:void(0)">Script link</a>
    <a href="mailto:hi@example.com">Mail link</a>
    <a href="/castle">Chapultepec Castle</a>
  </main>
</body></html>
''';

    test('resolves, dedupes, and filters links to followable web URLs',
        () async {
      final browser = TinyBrowser(
        client: MockClient((_) async => http.Response(richHtml, 200)),
      );

      final page = await browser.open('https://example.com/park');

      expect(page, isNotNull);
      final urls = page!.links.map((link) => link.url.toString()).toList();
      expect(urls, contains('https://example.com/castle'));
      expect(urls, contains('https://other.example.org/zoo'));
      // Fragments, script URLs and mail links are not navigable pages.
      expect(urls.any((url) => url.contains('#fragment')), isFalse);
      expect(urls.any((url) => url.startsWith('javascript:')), isFalse);
      expect(urls.any((url) => url.startsWith('mailto:')), isFalse);
      // A repeated href is only reported once.
      expect(urls.where((url) => url == 'https://example.com/castle'),
          hasLength(1));
      // Navigation chrome is stripped before links are read.
      expect(urls, isNot(contains('https://example.com/nav-only')));
    });

    test('findLinks matches by link text or URL', () async {
      final browser = TinyBrowser(
        client: MockClient((_) async => http.Response(richHtml, 200)),
      );
      await browser.open('https://example.com/park');

      final castle = browser.findLinks('castle');
      expect(castle, hasLength(1));
      expect(castle.single.url.toString(), 'https://example.com/castle');

      expect(browser.findLinks('zoo').single.text, 'Zoo');
      expect(browser.findLinks('nothing-matches-this'), isEmpty);
    });

    test('strips navigation and footer text but keeps article prose', () async {
      final browser = TinyBrowser(
        client: MockClient((_) async => http.Response(richHtml, 200)),
      );
      final page = await browser.open('https://example.com/park');

      expect(page!.text, contains('Chapultepec is divided into four sections'));
      expect(page.text, contains('Boats can be rented'));
      expect(page.text, isNot(contains('Nav link')));
      expect(page.text, isNot(contains('Privacy policy')));
    });
  });

  group('TinyBrowser history', () {
    TinyBrowser browserWithPages() {
      final pages = {
        'https://example.com/a':
            '<html><head><title>A</title></head><body><p>First page content here for the test.</p></body></html>',
        'https://example.com/b':
            '<html><head><title>B</title></head><body><p>Second page content here for the test.</p></body></html>',
        'https://example.com/c':
            '<html><head><title>C</title></head><body><p>Third page content here for the test.</p></body></html>',
      };
      return TinyBrowser(
        client: MockClient((request) async {
          return http.Response(
            pages[request.url.toString()] ??
                '<html><body>missing</body></html>',
            200,
          );
        }),
      );
    }

    test('tracks visited pages and walks back and forward', () async {
      final browser = browserWithPages();

      expect(browser.canGoBack, isFalse);
      expect(browser.canGoForward, isFalse);

      await browser.open('https://example.com/a');
      await browser.open('https://example.com/b');
      await browser.open('https://example.com/c');

      expect(browser.history, hasLength(3));
      expect(browser.currentPage!.title, 'C');
      expect(browser.canGoBack, isTrue);
      expect(browser.canGoForward, isFalse);

      expect(browser.back()!.title, 'B');
      expect(browser.currentPage!.title, 'B');
      expect(browser.canGoForward, isTrue);

      expect(browser.back()!.title, 'A');
      expect(browser.canGoBack, isFalse);
      expect(browser.back(), isNull);

      expect(browser.forward()!.title, 'B');
      expect(browser.forward()!.title, 'C');
      expect(browser.forward(), isNull);
    });

    test('a new navigation after going back drops the forward entries',
        () async {
      final browser = browserWithPages();
      await browser.open('https://example.com/a');
      await browser.open('https://example.com/b');
      browser.back();

      await browser.open('https://example.com/c');

      expect(browser.canGoForward, isFalse);
      expect(browser.history.map((page) => page.title), ['A', 'C']);
    });

    test('revisiting the current page does not duplicate history', () async {
      final browser = browserWithPages();
      await browser.open('https://example.com/a');
      await browser.open('https://example.com/a');

      expect(browser.history, hasLength(1));
    });

    test('reset clears the session history', () async {
      final browser = browserWithPages();
      await browser.open('https://example.com/a');
      browser.reset();

      expect(browser.history, isEmpty);
      expect(browser.currentPage, isNull);
      expect(browser.canGoBack, isFalse);
    });

    test('history is bounded so a long research pass cannot grow forever',
        () async {
      final browser = TinyBrowser(
        client: MockClient((request) async {
          return http.Response(
            '<html><head><title>${request.url.path}</title></head>'
            '<body><p>Page content for ${request.url.path} in the session.</p></body></html>',
            200,
          );
        }),
      );

      for (var index = 0; index < TinyBrowser.maxHistory + 6; index++) {
        await browser.open('https://example.com/page$index');
      }

      expect(browser.history, hasLength(TinyBrowser.maxHistory));
      expect(browser.currentPage!.title, '/page${TinyBrowser.maxHistory + 5}');
    });
  });

  group('SearchAgent tool calling', () {
    test('executes browser_search tool call autonomously', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'en.wikipedia.org') {
          return http.Response(
            jsonEncode({
              'query': {
                'pages': [
                  {
                    'pageid': 100,
                    'title': 'Bosque de Chapultepec',
                    'extract':
                        'Bosque de Chapultepec is one of the largest city parks in the Western Hemisphere.',
                    'thumbnail': {
                      'source':
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/test.jpg/640px-test.jpg',
                    },
                    'fullurl':
                        'https://en.wikipedia.org/wiki/Bosque_de_Chapultepec',
                  }
                ]
              }
            }),
            200,
          );
        }
        return http.Response('', 404);
      });

      final browser = TinyBrowser(client: client);
      final agent = SearchAgent(browser: browser);

      // Model outputs XML tool call:
      final decision = const SearchDecisionParser().parse(
        '<tool_call>\n{"name": "browser_search", "arguments": {"query": "Bosque de Chapultepec"}}\n</tool_call>',
      );

      expect(decision.kind, SearchDecisionKind.search);
      expect(decision.query, 'Bosque de Chapultepec');

      final result = await agent.executeToolCall(decision);
      expect(result.discoveredSources, isNotEmpty);
      expect(result.discoveredSources.first.imageUrl, contains('test.jpg'));
      expect(result.toolResponse, contains('TinyBrowser Search Results'));
      expect(result.toolResponse, contains('Bosque de Chapultepec'));
    });

    test('executes browser_open tool call autonomously', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head><title>Art Gallery</title><meta property="og:image" content="https://img.com/pic.jpg"></head><body><p>Exhibit details here.</p></body></html>',
          200,
        );
      });

      final browser = TinyBrowser(client: client);
      final agent = SearchAgent(browser: browser);

      final decision = const SearchDecisionParser().parse(
        'browser_open(url="https://museum.org/gallery")',
      );

      expect(decision.kind, SearchDecisionKind.open);
      expect(decision.url, 'https://museum.org/gallery');

      final result = await agent.executeToolCall(decision);
      expect(result.discoveredSources, isNotEmpty);
      expect(result.discoveredSources.first.title, 'Art Gallery');
      expect(
          result.discoveredSources.first.imageUrl, 'https://img.com/pic.jpg');
      expect(result.toolResponse,
          contains('TinyBrowser Opened Page: "Art Gallery"'));
    });
  });

  group('multi-step browsing', () {
    const searchJson = {
      'query': {
        'pages': [
          {
            'pageid': 1,
            'title': 'Gravity',
            'extract':
                'Gravity is the force that attracts masses toward one another.',
            'fullurl': 'https://en.wikipedia.org/wiki/Gravity',
          }
        ]
      }
    };

    const articleHtml = '''
<html><head><title>Gravity</title></head><body>
  <p>Gravity is the force by which a planet draws objects toward its centre.</p>
  <p>The acceleration due to gravity on Earth is about nine point eight.</p>
  <p>Newton described gravity as a universal attraction between masses.</p>
  <a href="/wiki/Orbit">Orbit</a>
</body></html>
''';

    TinyBrowser buildBrowser() => TinyBrowser(
          client: MockClient((request) async {
            if (request.url.host == 'en.wikipedia.org' &&
                request.url.path.contains('api.php')) {
              return http.Response(jsonEncode(searchJson), 200);
            }
            return http.Response(articleHtml, 200);
          }),
        );

    test('search then open then find walks the browser in one pass', () async {
      final browser = buildBrowser();
      final agent = SearchAgent(browser: browser);

      final searched = await agent.executeToolCall(
        const SearchDecision(
          kind: SearchDecisionKind.search,
          query: 'gravity',
        ),
      );
      expect(searched.activity.kind, ToolActivityKind.search);
      expect(searched.activity.label, 'gravity');
      expect(searched.discoveredSources, isNotEmpty);

      final opened = await agent.executeToolCall(
        const SearchDecision(
          kind: SearchDecisionKind.open,
          url: 'https://en.wikipedia.org/wiki/Gravity',
          query: 'https://en.wikipedia.org/wiki/Gravity',
        ),
      );
      expect(opened.activity.kind, ToolActivityKind.open);
      expect(opened.activity.label, 'Gravity');
      expect(opened.activity.detail, contains('wikipedia.org'));
      // The page's own links are offered so the next round need not guess.
      expect(opened.toolResponse, contains('Links on this page:'));
      expect(opened.toolResponse, contains('/wiki/Orbit'));

      final found = await agent.executeToolCall(
        const SearchDecision(
          kind: SearchDecisionKind.find,
          query: 'nine point eight',
        ),
      );
      expect(found.activity.kind, ToolActivityKind.find);
      expect(found.activity.label, 'nine point eight');
      expect(found.toolResponse, contains('nine point eight'));

      expect(browser.history, hasLength(1));
      expect(browser.currentPage!.title, 'Gravity');
    });

    test('a failed open reports an activity instead of throwing', () async {
      final browser = TinyBrowser(
        client: MockClient((_) async => http.Response('nope', 404)),
      );
      final agent = SearchAgent(browser: browser);

      final result = await agent.executeToolCall(
        const SearchDecision(
          kind: SearchDecisionKind.open,
          url: 'https://unreachable.example.org/page',
          query: 'https://unreachable.example.org/page',
        ),
      );

      expect(result.discoveredSources, isEmpty);
      expect(result.activity.kind, ToolActivityKind.open);
      expect(result.toolResponse, contains('Failed to open page'));
    });

    test('a search with no results still reports the query it tried', () async {
      final browser = TinyBrowser(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final agent = SearchAgent(browser: browser);

      final result = await agent.executeToolCall(
        const SearchDecision(
          kind: SearchDecisionKind.search,
          query: 'nothing matches this',
        ),
      );

      expect(result.discoveredSources, isEmpty);
      expect(result.activity.kind, ToolActivityKind.search);
      expect(result.activity.label, 'nothing matches this');
      expect(result.toolResponse, contains('No web results found'));
    });

    test('find on a page with no match says so', () async {
      final browser = buildBrowser();
      final agent = SearchAgent(browser: browser);
      await agent.executeToolCall(
        const SearchDecision(
          kind: SearchDecisionKind.open,
          url: 'https://en.wikipedia.org/wiki/Gravity',
          query: 'https://en.wikipedia.org/wiki/Gravity',
        ),
      );

      final result = await agent.executeToolCall(
        const SearchDecision(
          kind: SearchDecisionKind.find,
          query: 'photosynthesis',
        ),
      );

      expect(result.toolResponse, contains('No text matching'));
      expect(result.activity.detail, isEmpty);
    });
  });
}

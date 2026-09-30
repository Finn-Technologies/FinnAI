import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finn_ai/src/features/chat/flow_wiring.dart';
import 'package:finn_ai/src/features/search/providers/news_provider.dart';
import 'package:finn_ai/src/features/search/providers/source_provider.dart';
import 'package:finn_ai/src/features/search/providers/weather_provider.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/search_turn.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';

const _rss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Top stories</title>
<item><title>Council approves new tram line - City Times</title>
<link>https://news.example.com/a</link><pubDate>Wed, 30 Sep 2026 06:00:00 GMT</pubDate>
<source url="https://citytimes.example">City Times</source></item>
<item><title>Council approves new tram line - Daily Post</title>
<link>https://news.example.com/b</link><pubDate>Wed, 30 Sep 2026 06:10:00 GMT</pubDate>
<source url="https://dailypost.example">Daily Post</source></item>
<item><title>Storm warning issued for coast - Wire</title>
<link>javascript:alert(1)</link><pubDate>Wed, 30 Sep 2026 05:00:00 GMT</pubDate></item>
<item><title>Museum extends opening hours - Arts Desk</title>
<link>https://news.example.com/c</link><pubDate>Tue, 29 Sep 2026 07:00:00 GMT</pubDate>
<source url="https://arts.example">Arts Desk</source></item>
</channel></rss>''';

class _FixedProvider implements SourceProvider {
  _FixedProvider(this.name, this.sources);
  @override
  final String name;
  final List<WebSource> sources;
  final queries = <String>[];
  @override
  Future<List<WebSource>> fetch(String query) async {
    queries.add(query);
    return sources;
  }
}

class _CountingAgent extends SearchAgent {
  final queries = <String>[];
  @override
  Future<GroundedSearchResult?> searchAndFetch(String query) async {
    queries.add(query);
    return null;
  }
}

void main() {
  group('NewsProvider', () {
    final now = DateTime.utc(2026, 9, 30, 8);

    test('parses headlines with outlet and age, dedupes and drops bad links',
        () {
      final sources = NewsProvider.parse(_rss, now: now);
      expect(sources.map((s) => s.title), [
        'Council approves new tram line (City Times)',
        'Museum extends opening hours (Arts Desk)',
      ]);
      expect(sources.first.snippet,
          'City Times, 2 hours ago: Council approves new tram line');
      expect(sources.last.snippet, contains('1 days ago'));
      expect(sources.every((s) => s.url.scheme == 'https'), isTrue,
          reason: 'a javascript: link is never a source');
    });

    test('garbage is an empty list, not an exception', () {
      expect(NewsProvider.parse('<<not xml', now: now), isEmpty);
      expect(NewsProvider.parse('', now: now), isEmpty);
    });

    test('the region comes from the device locale', () {
      final it = NewsProvider.regionFor('it_IT');
      expect((it.hl, it.gl, it.ceid), ('it-IT', 'IT', 'IT:it'));
      final odd = NewsProvider.regionFor('');
      expect(odd.gl, 'US');
      expect(NewsProvider.regionFor('pt-BR').ceid, 'BR:pt');
    });

    test('asks for the last day and the device language', () async {
      late Uri seen;
      final provider = NewsProvider(
        localeName: 'de_DE',
        clock: () => now,
        client: MockClient((request) async {
          seen = request.url;
          return http.Response(_rss, 200);
        }),
      );
      final sources = await provider.fetch('Fußball');
      expect(sources, isNotEmpty);
      expect(seen.host, 'news.google.com');
      expect(seen.queryParameters['q'], 'Fußball when:1d');
      expect(seen.queryParameters['hl'], 'de-DE');
    });

    test('an error or a non-200 is empty', () async {
      expect(
        await NewsProvider(
          client: MockClient((_) async => http.Response('no', 503)),
        ).fetch('x'),
        isEmpty,
      );
      expect(
        await NewsProvider(
          client: MockClient((_) async => throw http.ClientException('down')),
        ).fetch('x'),
        isEmpty,
      );
    });
  });

  group('WeatherProvider', () {
    test('turns a place into a forecast sentence with attribution', () async {
      final provider = WeatherProvider(
        client: MockClient((request) async {
          if (request.url.host == 'geocoding-api.open-meteo.com') {
            return http.Response(
              '{"results":[{"name":"Rome","country":"Italy",'
              '"latitude":41.89,"longitude":12.48}]}',
              200,
            );
          }
          return http.Response(
            '{"daily":{"weather_code":[2],"temperature_2m_max":[26.4],'
            '"temperature_2m_min":[18.2],"precipitation_probability_max":[20]}}',
            200,
          );
        }),
      );
      final sources = await provider.fetch('Rome');
      expect(sources.single.snippet,
          'Rome, Italy today: partly cloudy, 18 to 26 °C, 20% chance of rain.');
      expect(sources.single.title, contains('Open-Meteo.com'));
    });

    test('an unknown place, a bad reply or an outage is empty', () async {
      expect(
        await WeatherProvider(
          client: MockClient((_) async => http.Response('{}', 200)),
        ).fetch('Nowhereville'),
        isEmpty,
      );
      expect(
        await WeatherProvider(
          client: MockClient((_) async => http.Response('nope', 500)),
        ).fetch('Rome'),
        isEmpty,
      );
      expect(
        await WeatherProvider(
          client: MockClient((_) async => throw http.ClientException('x')),
        ).fetch('Rome'),
        isEmpty,
      );
      expect(await WeatherProvider().fetch('   '), isEmpty);
    });
  });

  group('routing', () {
    test('a news question in chat is planned for the news source', () {
      final plan = const SearchPlanner()
          .plan('What are the latest news headlines today?');
      expect(plan.search, isTrue);
      expect(plan.provider, 'news');
    });

    test('an ordinary fresh question stays on general search', () {
      final plan =
          const SearchPlanner().plan('What is the price of gold today?');
      expect(plan.search, isTrue);
      expect(plan.provider, isNull);
    });

    test('a provider answers without touching general search', () async {
      final agent = _CountingAgent();
      final provider = _FixedProvider('news', [
        WebSource(title: 'A', url: Uri.parse('https://e.com/a'), snippet: 'a'),
      ]);
      final result = await SearchTurn(agent: agent, providers: [provider]).run(
        SearchPlan.search('football', SearchPlanReason.explicit,
            provider: 'news'),
      );
      expect(result.failed, isFalse);
      expect(result.sources, hasLength(1));
      expect(result.groundedContext, contains('[1] A'));
      expect(provider.queries, ['football']);
      expect(agent.queries, isEmpty);
    });

    test('an empty provider falls back to general search exactly once',
        () async {
      final agent = _CountingAgent();
      final result = await SearchTurn(
        agent: agent,
        providers: [_FixedProvider('news', const [])],
      ).run(
        SearchPlan.search('football', SearchPlanReason.explicit,
            provider: 'news'),
      );
      expect(agent.queries, ['football']);
      expect(result.failed, isTrue);
    });

    test('a flow gets a compact, numbered source list', () {
      final sources =
          NewsProvider.parse(_rss, now: DateTime.utc(2026, 9, 30, 8));
      final context = SearchTurnFlowSearch.compactContext(sources);
      expect(context, startsWith('RETRIEVED WEB RESULTS:'));
      expect(
          context, contains('[1] City Times, 2 hours ago: Council approves'));
      expect(context, isNot(contains('Rules:')), reason: 'chat-only rules');
      expect(context.length, lessThan(600));
      expect(SearchTurnFlowSearch.compactContext(const []), isEmpty);
    });

    test('a flow step routes by its prefix', () {
      expect(SearchTurnFlowSearch.route('news: local football'),
          (provider: 'news', query: 'local football'));
      expect(SearchTurnFlowSearch.route('weather:Rome'),
          (provider: 'weather', query: 'Rome'));
      expect(SearchTurnFlowSearch.route('best pasta recipe'),
          (provider: null, query: 'best pasta recipe'));
      expect(SearchTurnFlowSearch.route('newsletter ideas').provider, isNull);
    });
  });
}

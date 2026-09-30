import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/search/providers/source_provider.dart';
import 'package:finn_ai/src/features/search/shared_http_client.dart';

/// Current headlines from a public news RSS feed.
///
/// Headlines are what a morning brief needs, and an RSS item carries exactly
/// that: title, outlet, link, date. The snippet handed to the model is the
/// outlet, the date and the headline: real, dated, attributable, and short.
class NewsProvider implements SourceProvider {
  NewsProvider({
    http.Client? client,
    String? localeName,
    DateTime Function()? clock,
    this.timeout = defaultTimeout,
  })  : _client = client ?? SharedHttpClient.instance.client,
        _locale = localeName ?? _platformLocale(),
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final String _locale;
  final DateTime Function() _clock;

  static const Duration defaultTimeout = Duration(seconds: 4);

  /// Per-request limit. A chat turn keeps the short default; a flow, which is
  /// not waiting on a keyboard, is given longer.
  final Duration timeout;
  static const int maxItems = 5;

  @override
  String get name => 'news';

  static String _platformLocale() {
    try {
      return Platform.localeName;
    } on Object {
      return 'en_US';
    }
  }

  /// `hl`, `gl` and `ceid` for the feed, from a locale like `it_IT`.
  @visibleForTesting
  static ({String hl, String gl, String ceid}) regionFor(String localeName) {
    final parts = localeName.replaceAll('-', '_').split('_');
    final language =
        parts.first.toLowerCase().isEmpty ? 'en' : parts.first.toLowerCase();
    final country = parts.length > 1 && parts[1].length == 2
        ? parts[1].toUpperCase()
        : 'US';
    return (hl: '$language-$country', gl: country, ceid: '$country:$language');
  }

  @override
  Future<List<WebSource>> fetch(String query) async {
    final region = regionFor(_locale);
    final topic = query.trim();
    final uri = Uri.https('news.google.com', '/rss/search', {
      // `when:1d` keeps it to the last day: a brief of last year's news is
      // worse than none.
      'q': '${topic.isEmpty ? 'top stories' : topic} when:1d',
      'hl': region.hl,
      'gl': region.gl,
      'ceid': region.ceid,
    });
    try {
      final response = await _client.get(
        uri,
        headers: const {'User-Agent': 'FinnAI/1.0 (on-device assistant)'},
      ).timeout(timeout);
      if (response.statusCode != 200) return const [];
      return parse(response.body, now: _clock());
    } on Object catch (error) {
      debugPrint('FINN_NEWS failed: ${error.runtimeType}');
      return const [];
    }
  }

  /// Parses an RSS document into sources. Public for tests.
  @visibleForTesting
  static List<WebSource> parse(String body, {required DateTime now}) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on Object {
      return const [];
    }
    final sources = <WebSource>[];
    final seen = <String>{};
    for (final item in document.findAllElements('item')) {
      final rawTitle = item.getElement('title')?.innerText.trim() ?? '';
      final link = item.getElement('link')?.innerText.trim() ?? '';
      final uri = Uri.tryParse(link);
      if (rawTitle.isEmpty ||
          uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http')) {
        continue;
      }
      // Google News titles end " - Outlet"; the outlet is also in <source>.
      final outlet = item.getElement('source')?.innerText.trim() ?? '';
      var title = rawTitle;
      final dash = rawTitle.lastIndexOf(' - ');
      if (dash > 0) {
        title = rawTitle.substring(0, dash).trim();
      }
      if (!seen.add(title.toLowerCase())) continue;
      final published = _parseDate(item.getElement('pubDate')?.innerText);
      final when = published == null ? '' : _ago(now, published);
      final prefix = [
        if (outlet.isNotEmpty) outlet,
        if (when.isNotEmpty) when,
      ].join(', ');
      sources.add(
        WebSource(
          title: outlet.isEmpty ? title : '$title ($outlet)',
          url: uri,
          snippet: prefix.isEmpty ? title : '$prefix: $title',
        ),
      );
      if (sources.length == maxItems) break;
    }
    return sources;
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    try {
      return HttpDate.parse(raw.trim());
    } on Object {
      return DateTime.tryParse(raw.trim());
    }
  }

  static String _ago(DateTime now, DateTime then) {
    final delta = now.toUtc().difference(then.toUtc());
    if (delta.isNegative || delta.inMinutes < 2) return 'just now';
    if (delta.inHours < 1) return '${delta.inMinutes} minutes ago';
    if (delta.inHours < 24) return '${delta.inHours} hours ago';
    return '${delta.inDays} days ago';
  }
}

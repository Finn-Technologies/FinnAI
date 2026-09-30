import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/search/providers/source_provider.dart';
import 'package:finn_ai/src/features/search/shared_http_client.dart';

/// Today's forecast for a named place, from Open-Meteo (no key).
///
/// Two calls: the place name to coordinates, then the forecast. The result is
/// one source with a sentence the model can quote, never a table to interpret.
/// Open-Meteo asks for attribution; the source title carries it.
class WeatherProvider implements SourceProvider {
  WeatherProvider({http.Client? client, this.timeout = defaultTimeout})
      : _client = client ?? SharedHttpClient.instance.client;

  final http.Client _client;

  static const Duration defaultTimeout = Duration(seconds: 4);
  final Duration timeout;

  @override
  String get name => 'weather';

  @override
  Future<List<WebSource>> fetch(String query) async {
    final place = query.trim();
    if (place.isEmpty) return const [];
    try {
      final geocode = await _client
          .get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
            'name': place,
            'count': '1',
          }))
          .timeout(timeout);
      if (geocode.statusCode != 200) return const [];
      final results = (jsonDecode(geocode.body) as Map)['results'];
      if (results is! List || results.isEmpty) return const [];
      final found = results.first as Map;
      final lat = (found['latitude'] as num).toDouble();
      final lon = (found['longitude'] as num).toDouble();
      final label = [found['name'], found['country']]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(', ');

      final forecast = await _client
          .get(Uri.https('api.open-meteo.com', '/v1/forecast', {
            'latitude': '$lat',
            'longitude': '$lon',
            'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
                'precipitation_probability_max',
            'timezone': 'auto',
            'forecast_days': '1',
          }))
          .timeout(timeout);
      if (forecast.statusCode != 200) return const [];
      final sentence = describe(label, jsonDecode(forecast.body) as Map);
      if (sentence == null) return const [];
      return [
        WebSource(
          title: 'Weather for $label (Open-Meteo.com)',
          url: Uri.parse('https://open-meteo.com/'),
          snippet: sentence,
        ),
      ];
    } on Object catch (error) {
      debugPrint('FINN_WEATHER failed: ${error.runtimeType}');
      return const [];
    }
  }

  /// "Rome today: partly cloudy, 18 to 26 °C, 20% chance of rain."
  @visibleForTesting
  static String? describe(String label, Map<dynamic, dynamic> forecast) {
    final daily = forecast['daily'];
    if (daily is! Map) return null;
    num? first(String key) {
      final list = daily[key];
      return list is List && list.isNotEmpty && list.first is num
          ? list.first as num
          : null;
    }

    final high = first('temperature_2m_max');
    final low = first('temperature_2m_min');
    final code = first('weather_code');
    final rain = first('precipitation_probability_max');
    if (high == null && low == null && code == null) return null;
    final parts = <String>[
      if (code != null) _conditions(code.toInt()),
      if (low != null && high != null)
        '${low.round()} to ${high.round()} °C'
      else if (high != null)
        'high ${high.round()} °C',
      if (rain != null) '${rain.round()}% chance of rain',
    ];
    return '$label today: ${parts.join(', ')}.';
  }

  /// WMO weather interpretation codes, as words.
  static String _conditions(int code) => switch (code) {
        0 => 'clear sky',
        1 => 'mostly clear',
        2 => 'partly cloudy',
        3 => 'overcast',
        45 || 48 => 'fog',
        >= 51 && <= 57 => 'drizzle',
        >= 61 && <= 67 => 'rain',
        >= 71 && <= 77 => 'snow',
        >= 80 && <= 82 => 'rain showers',
        85 || 86 => 'snow showers',
        95 || 96 || 99 => 'thunderstorms',
        _ => 'mixed conditions',
      };
}

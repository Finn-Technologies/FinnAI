import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';

/// Reads the parts of a stored message that are lists of records. Lenient on
/// purpose: a damaged entry is skipped, never allowed to cost the whole chat.
List<ToolActivity> toolActivitiesFromJson(Object? raw) {
  if (raw is! List) return const [];
  final activities = <ToolActivity>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final label = item['label'];
    if (label is! String || label.isEmpty) continue;
    final kind = ToolActivityKind.values
        .where((value) => value.name == item['kind'])
        .firstOrNull;
    if (kind == null) continue;
    final detail = item['detail'];
    activities.add(
      ToolActivity(
        kind: kind,
        label: label,
        detail: detail is String ? detail : '',
      ),
    );
  }
  return activities;
}

List<WebSource> sourcesFromJson(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map &&
          item['title'] is String &&
          item['url'] is String &&
          item['snippet'] is String)
        if (Uri.tryParse(item['url'] as String) case final uri?
            when uri.scheme == 'https' && uri.host.isNotEmpty)
          WebSource(
            title: item['title'] as String,
            url: uri,
            snippet: item['snippet'] as String,
            imageUrl:
                item['imageUrl'] is String ? item['imageUrl'] as String : null,
          ),
  ];
}

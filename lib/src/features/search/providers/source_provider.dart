import 'package:finn_ai/src/engine/api/web_source.dart';

/// A keyless, on-device source of [WebSource]s for one kind of question.
///
/// General web search is poor at two things a small assistant is constantly
/// asked: what is in the news, and what the weather is. A Wikipedia search for
/// "top news today" returns articles about news, not news. These providers ask
/// a source built for the job instead (ADR 0002: no key, no server of ours).
abstract interface class SourceProvider {
  /// The routing name: `news`, `weather`.
  String get name;

  /// Up to a handful of sources for [query], or empty when there is nothing.
  /// Never throws for a network problem; an unreachable source is empty.
  Future<List<WebSource>> fetch(String query);
}

import 'package:flutter/foundation.dart';

/// One retrieved web page, as data.
///
/// Lives in the engine because a turn's sources travel with the reply the
/// engine produces; the search feature builds them, the engine only carries
/// them. Keeping the type here is what lets `engine/` avoid importing
/// `features/`.
@immutable
class WebSource {
  const WebSource({
    required this.title,
    required this.url,
    required this.snippet,
    this.imageUrl,
  });

  final String title;
  final Uri url;
  final String snippet;
  final String? imageUrl;
}

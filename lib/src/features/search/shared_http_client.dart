import 'package:http/http.dart' as http;

/// The one HTTP client the search stack uses.
///
/// The browser and the search service each used to construct their own
/// `http.Client`, and the chat shell constructed a third `WebSearchService` and
/// a throwaway `SearchAgent` per "continue" tap. Every one of those is a
/// separate connection pool with its own TLS sessions and its own idle
/// sockets, and none of them was ever closed.
///
/// On a phone this is the expensive part of a search: a cold TCP handshake plus
/// a TLS handshake per host, on a radio that is already the slowest part of the
/// turn. Sharing one keep-alive client means the second request of a turn — and
/// the first request of the next turn — reuses a connection that is already
/// warm.
///
/// Deliberately process-wide and deliberately never closed. A browser's
/// connection pool is meant to outlive any one request; closing it between
/// turns would throw away exactly the warmth this exists to keep.
class SharedHttpClient {
  SharedHttpClient._();

  static final SharedHttpClient instance = SharedHttpClient._();

  /// The shared pool. Exposed so a test can inject a fake rather than opening
  /// a real socket.
  http.Client get client => _client;

  static final http.Client _client = http.Client();
}

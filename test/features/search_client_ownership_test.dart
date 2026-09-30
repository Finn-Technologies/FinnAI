import 'package:finn_ai/src/features/search/shared_http_client.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// The search stack used to build its own HTTP client per component: the
/// browser had one, the search service had another, and the chat shell
/// constructed a throwaway `SearchAgent` for every "continue" tap. Each of
/// those is a connection pool that is never closed, and none of them reuses
/// another's warm TLS session.
///
/// The fix is one process-wide keep-alive client — with one sharp edge that
/// these tests exist to pin down: `close()` must not close a client this
/// instance does not own. The chat shell disposes its search service on
/// widget teardown, and closing the shared pool there would break the next
/// search of the session.
void main() {
  group('one client is shared by default', () {
    test('the search service defaults to the shared client', () {
      final service = WebSearchService();
      addTearDown(service.close);
      expect(service.client, same(SharedHttpClient.instance.client));
    });

    test('two search services share one client', () {
      final first = WebSearchService();
      final second = WebSearchService();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(first.client, same(second.client));
    });
  });

  group('close only closes what the instance owns', () {
    test('closing a default service leaves the shared client open', () async {
      // The regression this guards: teardown of the chat shell closing the
      // process-wide pool, after which every later search throws.
      WebSearchService().close();

      // A live client attempts the request and fails on the network; a closed
      // one refuses before it opens a socket.
      expect(await _probe(SharedHttpClient.instance.client), isTrue);
    });

    test('closing a service with an injected client does close it', () {
      var closed = false;
      final injected = _CloseTrackingClient(() => closed = true);
      WebSearchService(client: injected).close();
      expect(closed, isTrue,
          reason: 'an injected client is the caller\'s to '
              'release, so release it');
    });
  });
}

/// Whether a client still accepts work, which is what a closed one refuses.
///
/// A live client attempts the request and fails on the network; a closed one
/// throws [StateError] before it opens a socket. Both are caught, and only the
/// second counts as closed.
Future<bool> _probe(http.Client client) async {
  try {
    await client
        .get(Uri.parse('http://127.0.0.1:1/'))
        .timeout(const Duration(milliseconds: 200));
    return true;
  } on StateError {
    return false;
  } on Object {
    return true;
  }
}

class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream<List<int>>.empty(), 200);

  @override
  void close() => onClose();
}

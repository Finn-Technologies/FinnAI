import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/code_wires.dart';
import 'package:finn_ai/src/features/code/providers/provider_client.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';

Stream<List<int>> sse(List<String> lines) =>
    Stream.value(utf8.encode('${lines.join('\n')}\n\n'));

const completion = CodeCompletion(
  system: 'You are a coder.',
  turns: [
    CodeTurn.user('hi'),
    CodeTurn.assistant('hello'),
    CodeTurn.user('go')
  ],
  conversationId: 't',
  maxTokens: 100,
);

void main() {
  group('model parsers (shapes recorded from the live /models endpoints)', () {
    test('OpenRouter: names, context, prices per million, free', () {
      final models = CodeModelParsers.openRouter({
        'data': [
          {
            'id': 'inclusionai/ling-3.1-flash',
            'name': 'inclusionAI: Ling 3.1 Flash',
            'context_length': 262144,
            'pricing': {'prompt': '0', 'completion': '0'},
          },
          {
            'id': 'anthropic/claude-sonnet-5',
            'name': 'Anthropic: Claude Sonnet 5',
            'context_length': 1000000,
            'pricing': {'prompt': '0.000003', 'completion': '0.000015'},
          },
          {
            'id': 'openrouter/auto',
            'name': 'Auto Router',
            'pricing': {'prompt': '-1', 'completion': '-1'},
          },
          {'name': 'no id'},
        ],
      });

      expect(models.map((m) => m.id), [
        'inclusionai/ling-3.1-flash',
        'anthropic/claude-sonnet-5',
        'openrouter/auto',
      ]);
      expect(models[0].free, isTrue);
      expect(models[0].contextLength, 262144);
      expect(models[1].free, isFalse);
      expect(models[1].promptPricePerMillion, closeTo(3, 1e-9));
      expect(models[1].completionPricePerMillion, closeTo(15, 1e-9));
      // A variable price (-1) is not a price.
      expect(models[2].promptPricePerMillion, isNull);
      expect(models[2].free, isFalse);
      expect(models.every((m) => m.wires.length == 1), isTrue);
    });

    test('Command Code: supported_endpoints decide the wire', () {
      final models = CodeModelParsers.commandCode({
        'object': 'list',
        'data': [
          {
            'id': 'claude-sonnet-5-5',
            'name': 'Claude Sonnet 5.5',
            'context_length': 1000000,
            'supported_endpoints': ['/messages'],
          },
          {
            'id': 'gpt-5.5',
            'name': 'GPT 5.5',
            'supported_endpoints': ['/chat/completions', '/responses'],
          },
          {
            'id': 'deepseek/deepseek-v4-pro',
            'supported_endpoints': ['/responses', '/chat/completions'],
          },
          {'id': 'unknown-shape', 'supported_endpoints': <String>[]},
        ],
      });

      expect(models[0].wires, [CodeWire.anthropicMessages]);
      expect(models[1].wires, [
        CodeWire.chatCompletions,
        CodeWire.responses,
      ]);
      // Chat completions is always tried first when offered.
      expect(models[2].wires.first, CodeWire.chatCompletions);
      // Nothing declared: fall back to a guess instead of an empty list.
      expect(models[3].wires, isNotEmpty);
      expect(models[0].name, 'Claude Sonnet 5.5');
    });

    test('OpenCode: ids only, wire guessed and free flagged', () {
      final zen = CodeModelParsers.openCode(CodeProvider.openCodeZen, {
        'data': [
          {'id': 'claude-opus-5-5'},
          {'id': 'gpt-5.6-luna'},
          {'id': 'glm-5.3'},
          {'id': 'qwen3.8-max'},
          {'id': 'qwen3.8-flash'},
          {'id': 'deepseek-v4-flash-free'},
          {'id': 'minimax-m3'},
        ],
      });
      CodeWire first(String id) =>
          zen.firstWhere((m) => m.id == id).wires.first;

      expect(first('claude-opus-5-5'), CodeWire.anthropicMessages);
      expect(first('gpt-5.6-luna'), CodeWire.responses);
      expect(first('glm-5.3'), CodeWire.chatCompletions);
      expect(first('qwen3.8-max'), CodeWire.chatCompletions);
      expect(first('qwen3.8-flash'), CodeWire.anthropicMessages);
      expect(first('minimax-m3'), CodeWire.chatCompletions);
      expect(zen.firstWhere((m) => m.id.endsWith('-free')).free, isTrue);

      // On Go, MiniMax speaks the Anthropic shape.
      final go = CodeModelParsers.openCode(CodeProvider.openCodeGo, {
        'data': [
          {'id': 'minimax-m3'},
        ],
      });
      expect(go.single.wires.first, CodeWire.anthropicMessages);
      // ...and every guess still lists a fallback.
      expect(go.single.wires.length, greaterThan(1));
    });

    test('a custom server lists ids over chat completions', () {
      final models = CodeModelParsers.openAiCompatible({
        'data': [
          {'id': 'llama3'},
          {'id': 'qwen2.5-coder'},
        ],
      });
      expect(models.map((m) => m.id), ['llama3', 'qwen2.5-coder']);
      expect(models.first.provider, CodeProvider.custom);
      expect(models.first.wires, [CodeWire.chatCompletions]);
    });

    test('junk bodies give no models instead of throwing', () {
      expect(CodeModelParsers.openRouter('nope'), isEmpty);
      expect(CodeModelParsers.openAiCompatible({'data': 3}), isEmpty);
      expect(CodeModelParsers.commandCode(null), isEmpty);
    });

    test('a model round-trips through JSON', () {
      const model = CodeModel(
        provider: CodeProvider.openRouter,
        id: 'a/b',
        name: 'A B',
        wires: [CodeWire.anthropicMessages, CodeWire.chatCompletions],
        contextLength: 8000,
        free: true,
        promptPricePerMillion: 1.5,
        completionPricePerMillion: 2,
      );
      final back = CodeModel.fromJson(
        CodeProvider.openRouter,
        jsonDecode(jsonEncode(model.toJson())),
      )!;
      expect(back.id, 'a/b');
      expect(back.wires, model.wires);
      expect(back.contextLength, 8000);
      expect(back.free, isTrue);
      expect(back.promptPricePerMillion, 1.5);
      expect(CodeModel.fromJson(CodeProvider.custom, {'no': 'id'}), isNull);
    });
  });

  group('CodeModelRef', () {
    test('encodes and decodes, including ids that contain colons', () {
      const ref = CodeModelRef(CodeProvider.openRouter, 'meta/llama:free');
      expect(ref.encode(), 'openRouter:meta/llama:free');
      expect(CodeModelRef.decode(ref.encode()), ref);
      expect(
          CodeModelRef.decode(CodeModelRef.local.encode()), CodeModelRef.local);
      expect(CodeModelRef.decode('bogus:x'), isNull);
      expect(CodeModelRef.decode('openRouter:'), isNull);
      expect(CodeModelRef.decode(null), isNull);
    });
  });

  group('requests', () {
    test('chat completions: bearer key, system first, OpenRouter title', () {
      final request = CodeWires.buildRequest(
        CodeWire.chatCompletions,
        provider: CodeProvider.openRouter,
        baseUrl: 'https://openrouter.ai/api/v1/',
        modelId: 'm/x',
        completion: completion,
        apiKey: ' sk-test ',
      );
      final body = jsonDecode(request.body) as Map;

      expect(request.url.toString(),
          'https://openrouter.ai/api/v1/chat/completions');
      expect(request.headers['authorization'], 'Bearer sk-test');
      expect(request.headers['x-title'], 'FinnAI Code');
      expect(request.headers.containsKey('x-api-key'), isFalse);
      expect(body['stream'], isTrue);
      expect(body['max_tokens'], 100);
      final messages = body['messages'] as List;
      expect(messages.first, {'role': 'system', 'content': 'You are a coder.'});
      expect(messages.length, 4);
    });

    test('anthropic messages: both key headers, system separate', () {
      final request = CodeWires.buildRequest(
        CodeWire.anthropicMessages,
        provider: CodeProvider.commandCode,
        baseUrl: 'https://api.commandcode.ai/provider/v1',
        modelId: 'claude-sonnet-5-5',
        completion: completion,
        apiKey: 'k',
      );
      final body = jsonDecode(request.body) as Map;

      expect(request.url.path, '/provider/v1/messages');
      expect(request.headers['authorization'], 'Bearer k');
      expect(request.headers['x-api-key'], 'k');
      expect(request.headers['anthropic-version'], CodeWires.anthropicVersion);
      expect(body['system'], 'You are a coder.');
      expect((body['messages'] as List).first['role'], 'user');
      expect(request.headers.containsKey('x-title'), isFalse);
    });

    test('responses: instructions and input', () {
      final request = CodeWires.buildRequest(
        CodeWire.responses,
        provider: CodeProvider.openCodeZen,
        baseUrl: 'https://opencode.ai/zen/v1',
        modelId: 'gpt-5.5',
        completion: completion,
        apiKey: 'k',
      );
      final body = jsonDecode(request.body) as Map;

      expect(request.url.path, '/zen/v1/responses');
      expect(body['instructions'], 'You are a coder.');
      expect(body['max_output_tokens'], 100);
      expect((body['input'] as List).length, 3);
    });

    test('no key means no auth header (a local server)', () {
      final request = CodeWires.buildRequest(
        CodeWire.chatCompletions,
        provider: CodeProvider.custom,
        baseUrl: 'http://192.168.1.5:11434/v1',
        modelId: 'llama3',
        completion: completion,
        apiKey: '',
      );
      expect(request.headers.containsKey('authorization'), isFalse);
    });

    test('turns are merged and always open with the user', () {
      final turns = CodeWires.alternating(const [
        CodeTurn.assistant('stray'),
        CodeTurn.user('a'),
        CodeTurn.user('b'),
        CodeTurn.assistant('c'),
        CodeTurn.user('   '),
      ]);
      expect(turns, const [
        CodeTurn.user('a\n\nb'),
        CodeTurn.assistant('c'),
      ]);
    });
  });

  group('streams', () {
    test('chat completions: deltas, skips reasoning, stops at DONE', () async {
      final text = await CodeWires.text(
        CodeWire.chatCompletions,
        sse([
          ': keep-alive',
          'data: {"choices":[{"delta":{"role":"assistant","content":""}}]}',
          '',
          'data: {"choices":[{"delta":{"reasoning":"thinking"}}]}',
          '',
          'data: {"choices":[{"delta":{"content":"Hel"}}]}',
          '',
          'data: {"choices":[{"delta":{"content":"lo"}}]}',
          '',
          'data: {"usage":{"total_tokens":3},"choices":[]}',
          '',
          'data: [DONE]',
          '',
          'data: {"choices":[{"delta":{"content":"NEVER"}}]}',
        ]),
      ).join();
      expect(text, 'Hello');
    });

    test('chat completions: an in-band error is thrown', () async {
      final stream = CodeWires.text(
        CodeWire.chatCompletions,
        sse(['data: {"error":{"message":"upstream exploded"}}']),
      );
      await expectLater(
        stream.toList(),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.detail, 'detail', 'upstream exploded'),
        ),
      );
    });

    test('anthropic: only text deltas, ends at message_stop', () async {
      final text = await CodeWires.text(
        CodeWire.anthropicMessages,
        sse([
          'event: message_start',
          'data: {"type":"message_start","message":{"id":"m"}}',
          '',
          'event: content_block_delta',
          'data: {"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hmm"}}',
          '',
          'event: content_block_delta',
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hi "}}',
          '',
          'event: content_block_delta',
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"there"}}',
          '',
          'event: message_stop',
          'data: {"type":"message_stop"}',
          '',
          'event: content_block_delta',
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"NEVER"}}',
        ]),
      ).join();
      expect(text, 'Hi there');
    });

    test('anthropic: an error event is thrown', () async {
      await expectLater(
        CodeWires.text(
          CodeWire.anthropicMessages,
          sse([
            'event: error',
            'data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}',
          ]),
        ).toList(),
        throwsA(isA<ProviderException>()),
      );
    });

    test('responses: output_text deltas, failed is thrown', () async {
      final text = await CodeWires.text(
        CodeWire.responses,
        sse([
          'event: response.created',
          'data: {"type":"response.created"}',
          '',
          'event: response.output_text.delta',
          'data: {"type":"response.output_text.delta","delta":"a"}',
          '',
          'event: response.output_text.delta',
          'data: {"type":"response.output_text.delta","delta":"b"}',
          '',
          'event: response.completed',
          'data: {"type":"response.completed"}',
        ]),
      ).join();
      expect(text, 'ab');

      await expectLater(
        CodeWires.text(
          CodeWire.responses,
          sse([
            'data: {"type":"response.failed","response":{"error":{"message":"nope"}}}',
          ]),
        ).toList(),
        throwsA(
          isA<ProviderException>().having((e) => e.detail, 'detail', 'nope'),
        ),
      );
    });

    test('events split across arbitrary chunk boundaries still parse',
        () async {
      final payload = utf8.encode(
        'data: {"choices":[{"delta":{"content":"héllo"}}]}\n\n'
        'data: [DONE]\n\n',
      );
      final chunks = [
        for (var i = 0; i < payload.length; i += 5)
          payload.sublist(i, (i + 5).clamp(0, payload.length)),
      ];
      final text = await CodeWires.text(
        CodeWire.chatCompletions,
        Stream.fromIterable(chunks),
      ).join();
      expect(text, 'héllo');
    });
  });

  group('errors', () {
    ProviderException from(CodeProvider p, int status, String body) =>
        ProviderException.fromResponse(p, status, body);

    test('Command Code Go plan is recognised from its own message', () {
      final error = from(
        CodeProvider.commandCode,
        403,
        jsonEncode({
          'success': false,
          'error': {
            'code': 'FORBIDDEN',
            'message':
                "You're on the Go plan, the only plan without API access. "
                    'Upgrade to GOAT or higher.',
          },
        }),
      );
      expect(error.failure, ProviderFailure.planNoApi);
      expect(error.statusCode, 403);
    });

    test('the same words from another provider are just an auth error', () {
      expect(
        from(CodeProvider.openRouter, 403, 'Go plan, no API access').failure,
        ProviderFailure.auth,
      );
    });

    test('status codes map to failures', () {
      expect(from(CodeProvider.custom, 401, '').failure, ProviderFailure.auth);
      expect(from(CodeProvider.custom, 402, '').failure,
          ProviderFailure.paymentRequired);
      expect(from(CodeProvider.custom, 429, '').failure,
          ProviderFailure.rateLimited);
      expect(from(CodeProvider.custom, 404, '').failure,
          ProviderFailure.wrongEndpoint);
      expect(
          from(CodeProvider.custom, 503, '').failure, ProviderFailure.server);
      expect(
          from(CodeProvider.custom, 400, '{"error":{"message":"bad json"}}')
              .failure,
          ProviderFailure.badRequest);
      expect(
        from(CodeProvider.custom, 400,
                '{"error":{"message":"Model not supported on this endpoint"}}')
            .failure,
        ProviderFailure.wrongEndpoint,
      );
    });

    test('the message is read from each provider error shape', () {
      expect(from(CodeProvider.custom, 500, '{"error":{"message":"a"}}').detail,
          'a');
      expect(from(CodeProvider.custom, 500, '{"error":"b"}').detail, 'b');
      expect(from(CodeProvider.custom, 500, '{"message":"c"}').detail, 'c');
      expect(from(CodeProvider.custom, 500, 'plain text').detail, 'plain text');
      expect(from(CodeProvider.custom, 500, 'x' * 1000).detail.length, 301);
    });
  });

  group('CodeProviderClient', () {
    CodeModel model(List<CodeWire> wires) => CodeModel(
          provider: CodeProvider.openCodeZen,
          id: 'm',
          name: 'm',
          wires: wires,
        );

    http.StreamedResponse sseResponse(String body, [int status = 200]) =>
        http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          status,
          headers: {'content-type': 'text/event-stream'},
        );

    test('falls through wrong-endpoint answers and remembers the wire',
        () async {
      final seen = <String>[];
      final client = CodeProviderClient(
        client: MockClient.streaming((request, body) async {
          seen.add(request.url.path);
          if (request.url.path.endsWith('/chat/completions')) {
            return sseResponse('{"error":{"message":"use /messages"}}', 404);
          }
          return sseResponse(
            'event: content_block_delta\n'
            'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"ok"}}\n\n'
            'event: message_stop\ndata: {"type":"message_stop"}\n\n',
          );
        }),
      );
      CodeWire? worked;

      final text = await client
          .stream(
            model(const [CodeWire.chatCompletions, CodeWire.anthropicMessages]),
            baseUrl: 'https://opencode.ai/zen/v1',
            completion: completion,
            apiKey: 'k',
            onWire: (wire) => worked = wire,
          )
          .join();

      expect(text, 'ok');
      expect(worked, CodeWire.anthropicMessages);
      expect(seen, [
        '/zen/v1/chat/completions',
        '/zen/v1/messages',
      ]);
    });

    test('a bad key stops at once instead of trying other shapes', () async {
      var calls = 0;
      final client = CodeProviderClient(
        client: MockClient.streaming((request, body) async {
          calls++;
          return sseResponse('{"error":{"message":"bad key"}}', 401);
        }),
      );

      await expectLater(
        client
            .stream(
              model(const [CodeWire.chatCompletions, CodeWire.responses]),
              baseUrl: 'https://x/v1',
              completion: completion,
            )
            .toList(),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.failure, 'failure', ProviderFailure.auth),
        ),
      );
      expect(calls, 1);
    });

    test('every shape wrong: the last answer is thrown', () async {
      final client = CodeProviderClient(
        client: MockClient.streaming(
          (request, body) async => sseResponse('{}', 404),
        ),
      );
      await expectLater(
        client
            .stream(
              model(const [CodeWire.chatCompletions, CodeWire.responses]),
              baseUrl: 'https://x/v1',
              completion: completion,
            )
            .toList(),
        throwsA(
          isA<ProviderException>().having(
              (e) => e.failure, 'failure', ProviderFailure.wrongEndpoint),
        ),
      );
    });

    test('a network failure is reported as such', () async {
      final client = CodeProviderClient(
        client: MockClient.streaming(
          (request, body) async => throw http.ClientException('down'),
        ),
      );
      await expectLater(
        client
            .stream(
              model(const [CodeWire.chatCompletions]),
              baseUrl: 'https://x/v1',
              completion: completion,
            )
            .toList(),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.failure, 'failure', ProviderFailure.network),
        ),
      );
    });

    test('listModels sends the key and parses by provider', () async {
      String? auth;
      final client = CodeProviderClient(
        client: MockClient((request) async {
          auth = request.headers['authorization'];
          expect(request.url.toString(),
              'https://api.commandcode.ai/provider/v1/models');
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'gpt-5.5',
                  'supported_endpoints': ['/chat/completions'],
                },
              ],
            }),
            200,
          );
        }),
      );

      final models = await client.listModels(
        CodeProvider.commandCode,
        baseUrl: 'https://api.commandcode.ai/provider/v1',
        apiKey: 'secret',
      );

      expect(auth, 'Bearer secret');
      expect(models.single.id, 'gpt-5.5');
    });

    test('listModels: errors and empty lists are exceptions', () async {
      Future<Object?> run(http.Response response) async {
        final client = CodeProviderClient(
          client: MockClient((_) async => response),
        );
        try {
          await client.listModels(CodeProvider.openCodeGo,
              baseUrl: 'https://opencode.ai/zen/go/v1');
          return null;
        } on ProviderException catch (error) {
          return error.failure;
        }
      }

      expect(await run(http.Response('', 401)), ProviderFailure.auth);
      expect(
          await run(http.Response('not json', 200)), ProviderFailure.malformed);
      expect(await run(http.Response('{"data":[]}', 200)),
          ProviderFailure.malformed);
    });

    test('OpenRouter allowance reads the key report and the balance', () async {
      final client = CodeProviderClient(
        clock: () => DateTime.utc(2026, 10, 3),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/key')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'label': 'finn',
                  'limit': 20,
                  'limit_remaining': 12.5,
                  'usage': 7.5,
                  'usage_daily': 0.5,
                  'usage_monthly': 3,
                  'is_free_tier': false,
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {'total_credits': 50, 'total_usage': 12.25},
            }),
            200,
          );
        }),
      );

      final allowance = await client.openRouterAllowance(
        baseUrl: 'https://openrouter.ai/api/v1',
        apiKey: 'k',
      );

      expect(allowance.limit, 20);
      expect(allowance.remaining, 12.5);
      expect(allowance.used, 7.5);
      expect(allowance.usedToday, 0.5);
      expect(allowance.usedThisMonth, 3);
      expect(allowance.balance, closeTo(37.75, 1e-9));
      expect(allowance.freeTier, isFalse);
      expect(allowance.label, 'finn');
      expect(allowance.capped, isTrue);
      expect(allowance.fetchedAt, DateTime.utc(2026, 10, 3));
      expect(
        ProviderAllowance.fromJson(allowance.toJson())!.remaining,
        12.5,
      );
    });

    test('an ordinary key still gets an allowance without the balance',
        () async {
      final client = CodeProviderClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/key')) {
            return http.Response(
              jsonEncode({
                'data': {'limit': null, 'usage': 1.0, 'is_free_tier': true},
              }),
              200,
            );
          }
          return http.Response('{"error":{"message":"management key"}}', 403);
        }),
      );

      final allowance = await client.openRouterAllowance(
        baseUrl: 'https://openrouter.ai/api/v1',
        apiKey: 'k',
      );

      expect(allowance.capped, isFalse);
      expect(allowance.balance, isNull);
      expect(allowance.used, 1.0);
      expect(allowance.freeTier, isTrue);
    });

    test('a rejected key surfaces from the key report', () async {
      final client = CodeProviderClient(
        client: MockClient(
          (_) async => http.Response('{"error":{"message":"No auth"}}', 401),
        ),
      );
      await expectLater(
        client.openRouterAllowance(
            baseUrl: 'https://openrouter.ai/api/v1', apiKey: 'bad'),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.failure, 'failure', ProviderFailure.auth),
        ),
      );
    });

    test('testKey succeeds on the first fragment', () async {
      final client = CodeProviderClient(
        client: MockClient.streaming((request, body) async => sseResponse(
              'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n',
            )),
      );
      await client.testKey(
        model(const [CodeWire.chatCompletions]),
        baseUrl: 'https://x/v1',
        apiKey: 'k',
      );
    });
  });
}

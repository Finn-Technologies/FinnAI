import 'package:finn_ai/src/engine/prompt/bare_tool_call_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds [input] to a fresh filter one character at a time, mimicking the
/// token stream, and returns everything the user would have seen.
String runCharByChar(String input) {
  final filter = BareToolCallFilter();
  final out = StringBuffer();
  for (final unit in input.split('')) {
    out.write(filter.add(unit));
  }
  out.write(filter.flush());
  return out.toString();
}

void main() {
  group('BareToolCallFilter', () {
    test('passes ordinary prose through unchanged', () {
      const prose = 'Paris is the capital of France. It sits on the Seine.';
      expect(runCharByChar(prose), prose);
    });

    test('drops a bare tool call but keeps the surrounding answer', () {
      const input = 'Let me check. '
          '{"name": "browser_search", "arguments": {"query": "capital of France"}}'
          ' Paris is the capital.';
      final output = runCharByChar(input);
      expect(output, contains('Let me check.'));
      expect(output, contains('Paris is the capital.'));
      expect(output, isNot(contains('browser_search')));
      expect(output, isNot(contains('"arguments"')));
    });

    test('drops repeated calls without emitting blank noise', () {
      const call =
          '{"name": "browser_find", "arguments": {"query": "[topic] simplification"}}';
      final output = runCharByChar('$call\n$call\n$call');
      expect(output.trim(), isEmpty);
      expect(output, isNot(contains('browser_find')));
    });

    test('drops a tool call body left behind after tag stripping', () {
      // FinnAccelerator removes <tool_call> wrappers before this filter runs,
      // so the JSON body alone still has to be suppressed.
      const input =
          '{"name": "browser_open", "arguments": {"url": "https://example.com"}}';
      expect(runCharByChar(input).trim(), isEmpty);
    });

    test('keeps JSON that is not a tool call', () {
      const payload = '{"name": "Alice", "age": 30}';
      expect(runCharByChar('She sent $payload today.'), contains(payload));
    });

    test('drops a tool call that never grows an argument bag', () {
      const payload = '{"name": "browser_search"}';
      expect(runCharByChar(payload).trim(), isEmpty);
    });

    test('reports that it dropped something', () {
      final filter = BareToolCallFilter();
      filter.add('{"name": "browser_search", "arguments": {"query": "x"}}');
      expect(filter.droppedToolCall, isTrue);
    });

    test('drops a call truncated by the end of the stream', () {
      final filter = BareToolCallFilter();
      final visible = filter.add('Answer: '
          '{"name": "browser_search", "arguments": {"query": "unterminated');
      expect(visible, contains('Answer:'));
      expect(filter.flush(), isEmpty);
    });

    test('emits text held back at end of stream when it is not a call', () {
      final filter = BareToolCallFilter();
      expect(filter.add('{'), isEmpty);
      expect(filter.flush(), '{');
    });

    test('handles escapes and braces inside call arguments', () {
      const call = '{"name": "browser_search", "arguments": '
          '{"query": "a \\"quoted\\" } brace"}}';
      final output = runCharByChar('See: $call done');
      expect(output, contains('See:'));
      expect(output, contains('done'));
      expect(output, isNot(contains('quoted')));
    });

    test('streams large plain answers without unbounded buffering', () {
      final filter = BareToolCallFilter();
      final chunk = 'word ' * 2000;
      final visible = filter.add(chunk);
      expect(visible, chunk);
      expect(filter.flush(), isEmpty);
    });
  });
}

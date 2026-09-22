import 'package:finn_ai/src/engine/prompt/tool_tag_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stripping only whole tags let a tag that the model streamed in pieces reach
/// the user: the reply for a turn that ran out of budget mid-call was a single
/// stray `<`.
void main() {
  test('drops a complete call block and keeps the surrounding prose', () {
    final filter = ToolTagFilter();
    final text = filter.add(
      'Sure.<tool_call>{"name":"browser_search"}</tool_call>Done.',
    );
    expect(text, 'Sure.Done.');
    expect(filter.flush(), isEmpty);
  });

  test('drops a call block that arrives one piece at a time', () {
    final filter = ToolTagFilter();
    final buffer = StringBuffer()
      ..write(filter.add('Here you go.\n'))
      ..write(filter.add('<'))
      ..write(filter.add('tool_call'))
      ..write(filter.add('>{"name":'))
      ..write(filter.add('"browser_search"}'))
      ..write(filter.add('</tool_call'))
      ..write(filter.add('>'));
    expect(buffer.toString(), 'Here you go.\n');
  });

  test('does not leak the opening fragment when the stream ends mid-call', () {
    final filter = ToolTagFilter();
    expect(filter.add('The answer is'), 'The answer is');
    expect(filter.add('<'), isEmpty);
    expect(filter.add('tool_call>'), isEmpty);
    expect(filter.add('{"name":"browser_open"'), isEmpty);
    expect(filter.flush(), isEmpty);
  });

  test('keeps prose that merely contains a less-than sign', () {
    final filter = ToolTagFilter();
    final buffer = StringBuffer()
      ..write(filter.add('A check is true when '))
      ..write(filter.add('a < '))
      ..write(filter.add('b.'))
      ..write(filter.flush());
    expect(buffer.toString(), 'A check is true when a < b.');
  });

  test('releases a held fragment once it cannot be a tag', () {
    final filter = ToolTagFilter();
    expect(filter.add('count <'), 'count ');
    expect(filter.add(' 3'), '< 3');
  });

  test('matches tags case-insensitively', () {
    final filter = ToolTagFilter();
    expect(filter.add('<TOOL_CALL>{"a":1}</Tool_Call>ok'), 'ok');
  });

  test('drops a response block too', () {
    final filter = ToolTagFilter();
    expect(filter.add('a<tool_response>stuff</tool_response>b'), 'ab');
  });

  test('drops an unclosed block for the rest of the stream', () {
    final filter = ToolTagFilter();
    expect(filter.add('lead '), 'lead ');
    expect(filter.add('<tool_call>{"name":'), isEmpty);
    expect(filter.add('"browser_search"}'), isEmpty);
    expect(filter.flush(), isEmpty);
  });

  test('leaves ordinary text untouched', () {
    final filter = ToolTagFilter();
    expect(filter.add('The circle is blue.'), 'The circle is blue.');
    expect(filter.flush(), isEmpty);
  });
}

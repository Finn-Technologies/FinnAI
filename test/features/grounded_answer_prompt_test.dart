import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grounding used to instruct the model to "craft an authoritative article
/// summary" on every grounded turn. On device, "What is the capital of France?"
/// came back as a headline, a lead paragraph and a [1]/[2]/[3] walk through the
/// reference blocks instead of "Paris." These tests keep the instruction
/// answer-shaped and keep the findings out of the reply.
void main() {
  final sources = [
    WebSource(
      title: 'France',
      url: Uri.parse('https://en.wikipedia.org/wiki/France'),
      snippet: 'Paris is the capital and largest city of France.',
    ),
    WebSource(
      title: 'Paris',
      url: Uri.parse('https://en.wikipedia.org/wiki/Paris'),
      snippet: 'Paris is on the Seine river.',
    ),
  ];

  test('the grounded block still opens with the shared marker', () {
    final context = SearchAgent.groundedContextForSources(sources);

    // The prompt formatter keys off this exact heading to tell retrieved
    // reference material apart from the user's private configuration.
    expect(
      context.split('\n').first,
      '${PromptFormatter.groundedContextMarker}:',
    );
  });

  test('it never asks for an article summary', () {
    final context = SearchAgent.groundedContextForSources(sources);

    expect(context, isNot(contains('article summary')));
    expect(context, isNot(contains('authoritative')));
    expect(
      context,
      contains('keep it as short as the question deserves'),
      reason: 'a direct question must not be answered with an article',
    );
    expect(
      context,
      contains('Never print, quote or summarise these findings'),
      reason: 'the reference blocks are background, not the reply',
    );
  });

  // A ban on its own was not enough: with nothing positive to imitate, the
  // model answered a factual question with a bare "[1]". The worked contrast is
  // what shows it the shape of a correct reply.
  test('it shows the shape of a correct answer', () {
    final context = SearchAgent.groundedContextForSources(sources);

    expect(context, contains('Answer the question below in your own words'));
    expect(context, contains('Example:'));
    expect(
      context,
      contains('Answer: Paris is the capital of France.[1]'),
      reason: 'the citation belongs inside the sentence it supports',
    );
  });

  test('the numbered references survive for citation', () {
    final context = SearchAgent.groundedContextForSources(sources);

    expect(context, contains('[1] France'));
    expect(context, contains('URL: https://en.wikipedia.org/wiki/France'));
    expect(context, contains('Excerpt: Paris is the capital'));
    expect(context, contains('[2] Paris'));
  });

  test('an excerpt is capped so prefill stays cheap', () {
    final long = 'x' * (SearchAgent.maxExcerptChars + 50);
    final context = SearchAgent.groundedContextForSources([
      WebSource(
        title: 'Long',
        url: Uri.parse('https://example.com/long'),
        snippet: long,
      ),
    ]);

    expect(context, contains('…'));
    expect(context, isNot(contains('x' * (SearchAgent.maxExcerptChars + 1))));
  });

  test('the formatter tail agrees: answer, do not echo', () {
    final buffer = StringBuffer();
    PromptFormatter.writeGroundedContext(
      buffer,
      SearchAgent.groundedContextForSources(sources),
    );
    final written = buffer.toString();

    expect(written, contains('Answer the user\'s question from these notes'));
    expect(written, contains('Never reply with the notes themselves'));
    expect(written, isNot(contains('editorial article')));
  });

  test('nothing is written when there is no grounded context', () {
    final buffer = StringBuffer();
    PromptFormatter.writeGroundedContext(buffer, '   ');

    expect(buffer.toString(), isEmpty);
  });
}

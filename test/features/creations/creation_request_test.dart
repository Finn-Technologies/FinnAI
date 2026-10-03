import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_request.dart';

void main() {
  CreationRequest? parse(String text) => CreationRequest.parse(text);

  test('apps', () {
    for (final text in [
      'make me a water counter app',
      'Can you build a habit tracker?',
      'create a mini app that splits the bill',
      'I want you to make me a shopping list app',
      'please design a scoreboard for ping pong',
    ]) {
      expect(parse(text)?.kind, CreationKind.app, reason: text);
    }
  });

  test('widgets, and a widget noun beats an app noun', () {
    expect(parse('make me a widget that counts my pushups')?.kind,
        CreationKind.widget);
    expect(parse('create a home screen widget for my water intake')?.kind,
        CreationKind.widget);
    expect(parse('build a counter widget')?.kind, CreationKind.widget);
  });

  test('presentations', () {
    for (final text in [
      'make a presentation about volcanoes',
      'create slides for my team meeting',
      'build me a slide deck on budgeting',
      'make a powerpoint about cats',
    ]) {
      expect(parse(text)?.kind, CreationKind.presentation, reason: text);
    }
  });

  test('the brief has the request words taken off', () {
    expect(parse('make me a water counter app')!.brief, 'water counter app');
    expect(parse('Can you build a habit tracker?')!.brief, 'habit tracker');
    expect(parse('create a presentation about volcanoes.')!.brief,
        'presentation about volcanoes');
  });

  test('questions about making things stay chat answers', () {
    for (final text in [
      'how do I make an app in flutter',
      'what is a widget',
      'explain how to build a tracker',
      'can I make a presentation in google slides',
      'why is my app crashing',
    ]) {
      expect(parse(text), isNull, reason: text);
    }
  });

  test('code requests stay chat answers', () {
    for (final text in [
      'make an app in python that sorts files',
      'build a website for my dog',
      'create an ios app with swift',
      'write a function that reverses a string',
    ]) {
      expect(parse(text), isNull, reason: text);
    }
  });

  test('words without a make-verb or without a noun are not requests', () {
    for (final text in [
      'give me a shopping list for pasta night',
      'a timer for 10 minutes',
      'my app is slow',
      'make me a sandwich',
      '',
    ]) {
      expect(parse(text), isNull, reason: text);
    }
  });

  test('a very long message is not a request', () {
    expect(parse('make me an app ${'x ' * 300}'), isNull);
  });
}

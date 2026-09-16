import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/creations/spec/safe_expression.dart';

void main() {
  group('SafeExpression arithmetic', () {
    int evaluate(String source, [Map<String, Object?> state = const {}]) =>
        SafeExpression.parse(source).evaluate(state);

    test('applies operator precedence and parentheses', () {
      expect(evaluate('1 + 2 * 3'), 7);
      expect(evaluate('(1 + 2) * 3'), 9);
      expect(evaluate('10 - 2 - 3'), 5);
      expect(evaluate('2 * 3 + 4 * 5'), 26);
    });

    test('supports unary signs', () {
      expect(evaluate('-5 + 2'), -3);
      expect(evaluate('+5'), 5);
      expect(evaluate('-(3 + 4)'), -7);
      expect(evaluate('--5'), 5);
    });

    test('truncates integer division toward zero', () {
      expect(evaluate('7 / 2'), 3);
      expect(evaluate('-7 / 2'), -3);
      expect(evaluate('6 / 3'), 2);
    });

    test('applies modulo', () {
      expect(evaluate('7 % 3'), 1);
      expect(evaluate('10 % 5'), 0);
    });

    test('reads state keys and coerces value types', () {
      expect(evaluate('count + 1', {'count': 4}), 5);
      expect(evaluate('count + 1', {'count': '4'}), 5);
      expect(evaluate('count + 1', {'count': 4.9}), 5);
      expect(evaluate('count', {'count': true}), 1);
      expect(evaluate('count', {'count': false}), 0);
      expect(
          evaluate('items', {
            'items': ['a', 'b', 'c']
          }),
          3);
      expect(evaluate('count', {'count': 'not a number'}), 0);
    });

    test('treats unknown keys as zero so evaluation is total', () {
      expect(evaluate('missing + 5'), 5);
      expect(evaluate('missing'), 0);
    });

    test('returns zero for division and modulo by zero instead of throwing',
        () {
      expect(evaluate('5 / zero', {'zero': 0}), 0);
      expect(evaluate('5 % zero', {'zero': 0}), 0);
    });

    test('clamps instead of overflowing on runaway multiplication', () {
      final limit = 1 << 53;
      expect(evaluate('big * 2', {'big': limit}), limit);
      expect(evaluate('big * big', {'big': limit}), limit);
      expect(evaluate('big * big * big * big', {'big': limit}), limit);
    });
  });

  group('SafeExpression rejections', () {
    test('rejects empty input', () {
      expect(
        () => SafeExpression.parse('   '),
        throwsA(isA<ExpressionException>()),
      );
    });

    test('rejects incomplete expressions', () {
      for (final source in ['1 +', '(1', '1 2', '* 3', '(', ')']) {
        expect(
          () => SafeExpression.parse(source),
          throwsA(isA<ExpressionException>()),
          reason: '"$source" should not parse',
        );
      }
    });

    test('rejects characters outside the grammar', () {
      expect(
        () => SafeExpression.parse(r'a && b'),
        throwsA(isA<ExpressionException>()),
      );
      expect(
        () => SafeExpression.parse('a; b'),
        throwsA(isA<ExpressionException>()),
      );
      expect(
        () => SafeExpression.parse(r'__import("dart:io")'),
        throwsA(isA<ExpressionException>()),
      );
    });

    test('rejects sources longer than the cap', () {
      expect(
        () => SafeExpression.parse('1' * (SafeExpression.maxSourceLength + 1)),
        throwsA(isA<ExpressionException>()),
      );
    });

    test('rejects token-heavy sources', () {
      final long = List.filled(SafeExpression.maxTokens, '1').join('+');
      expect(
        () => SafeExpression.parse(long),
        throwsA(isA<ExpressionException>()),
      );
    });

    test('rejects deeply nested expressions', () {
      final bomb = '${'(' * 40}1${')' * 40}';
      expect(
        () => SafeExpression.parse(bomb),
        throwsA(isA<ExpressionException>()),
      );
    });

    test('tryParse reports failure without throwing', () {
      expect(SafeExpression.tryParse('1 + 1'), isNotNull);
      expect(SafeExpression.tryParse('1 +'), isNull);
    });
  });

  group('SafeExpression metadata', () {
    test('records every referenced key once', () {
      final expression = SafeExpression.parse('a + b * a + (c - 1)');
      expect(expression.referencedKeys, {'a', 'b', 'c'});
    });
  });

  group('SafeExpression.interpolate', () {
    test('substitutes placeholders from state', () {
      expect(
        SafeExpression.interpolate('Taps: {count}', {'count': 7}),
        'Taps: 7',
      );
      expect(
        SafeExpression.interpolate('{first} and {second}', {
          'first': 'Peas',
          'second': 'Carrots',
        }),
        'Peas and Carrots',
      );
    });

    test('renders a missing key as zero rather than leaving the braces', () {
      expect(SafeExpression.interpolate('Taps: {count}', {}), 'Taps: 0');
    });

    test('leaves non-placeholder text and braces untouched', () {
      expect(
          SafeExpression.interpolate('no braces here', {}), 'no braces here');
      expect(SafeExpression.interpolate('{}', {}), '{}');
      expect(SafeExpression.interpolate('{2bad}', {}), '{2bad}');
    });

    test('formats lists and floats readably', () {
      expect(
        SafeExpression.describeValue(['milk', 'eggs']),
        'milk, eggs',
      );
      expect(SafeExpression.describeValue(2.0), '2');
      expect(SafeExpression.describeValue(2.5), '2.5');
      expect(SafeExpression.describeValue(null), '0');
    });
  });
}

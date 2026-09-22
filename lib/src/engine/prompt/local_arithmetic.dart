import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A question the app could answer itself, with the value it computed.
@immutable
class LocalArithmeticResult {
  const LocalArithmeticResult({
    required this.expression,
    required this.value,
    required this.formatted,
  });

  /// The expression as it will be shown to the model, e.g. `15% of 240`.
  final String expression;

  final double value;

  /// [value] as text: integers without a decimal point, fractions trimmed.
  final String formatted;
}

/// Deterministic arithmetic for the questions a 1.6B model gets wrong.
///
/// A quantised small model does not reliably do arithmetic: it answers
/// "15% of 240" with a plausible number rather than the right one, and no
/// amount of prompting fixes that (see the model-limits note in the repo docs —
/// the app's job is to route capability gaps to code). This solves the narrow,
/// unambiguous slice — a pure expression, or "N% of M" — exactly, and refuses
/// everything else so the model still handles word problems, unit conversion,
/// dates and anything phrased as prose.
///
/// Refusal is the default: every rejection path returns null and the turn
/// proceeds unmodified.
abstract final class LocalArithmetic {
  /// Longest input worth looking at, and the longest expression the parser
  /// accepts once the question wrapper is stripped.
  static const int _maxMessageLength = 160;
  static const int _maxExpressionLength = 120;

  /// Keep results printable: beyond this they are not answers to a chat
  /// question but evidence of a runaway expression.
  static const double _maxMagnitude = 1e15;
  static const int _maxPowerExponent = 64;

  /// Leading words that frame an arithmetic question rather than changing it.
  /// Longest first, so `what is` wins over `what`.
  static const List<String> _questionWrappers = [
    'quanto fa',
    'quanto è',
    'quanto e',
    'wie viel ist',
    'wieviel ist',
    'combien font',
    'combien fait',
    'combien vaut',
    'cuánto es',
    'cuanto es',
    'cuánto son',
    'how much is',
    'what is',
    "what's",
    'whats',
    'calcola',
    'calcolare',
    'calcula',
    'calcular',
    'calcule',
    'calculer',
    'berechne',
    'berechnen',
    'calculate',
    'compute',
    'evaluate',
    'was ist',
    'solve',
  ];

  /// `15% of 240`, `15%di240`, ... — the percentage reading of `%`.
  static final RegExp _percentOf = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?)%(?:of|di|del|della|de|du|von)(.+)$',
  );

  /// Solves [message] when it is a pure arithmetic request, else null.
  static LocalArithmeticResult? solve(String message) {
    final trimmed = message.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed.length > _maxMessageLength) return null;

    var text = trimmed.replaceAll(RegExp(r'[?!.。]+$'), '').trim();
    for (final wrapper in _questionWrappers) {
      if (text.startsWith(wrapper)) {
        final rest = text.substring(wrapper.length).trim();
        if (rest.isNotEmpty) {
          text = rest;
          break;
        }
      }
    }
    // Whitespace carries no meaning in an expression, and the model's answer is
    // the only place it needs to read naturally.
    text = text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(RegExp(r'[−–—]'), '-');
    if (text.isEmpty || text.length > _maxExpressionLength) return null;

    final double value;
    final String expression;
    final percent = _percentOf.firstMatch(text);
    if (percent != null) {
      final rate = double.tryParse(percent.group(1)!);
      final base = _tryParseExpression(percent.group(2)!);
      if (rate == null || base == null) return null;
      value = rate / 100 * base;
      expression = '${percent.group(1)}% of ${percent.group(2)}';
    } else {
      // A bare number is not a question about arithmetic.
      if (!text.contains(RegExp(r'[+\-*/^%]'))) return null;
      final parsed = _tryParseExpression(text);
      if (parsed == null) return null;
      value = parsed;
      expression = text;
    }

    if (!value.isFinite || value.abs() > _maxMagnitude) return null;
    return LocalArithmeticResult(
      expression: expression,
      value: value,
      formatted: _format(value),
    );
  }

  /// The prompt block for [message], or '' when there is nothing to say.
  static String systemBlockFor(String message) {
    final result = solve(message);
    if (result == null) return '';
    return '<|im_start|>system\n'
        'Computed by the app for this question: ${result.expression} = '
        '${result.formatted}. State that result; do not recompute it yourself.'
        '\n<|im_end|>\n';
  }

  static double? _tryParseExpression(String source) {
    if (source.isEmpty) return null;
    try {
      return _ExpressionParser(source).parseAll();
    } on _InvalidExpression {
      return null;
    }
  }

  static String _format(double value) {
    if (value == value.roundToDouble() && value.abs() < _maxMagnitude) {
      return value.toInt().toString();
    }
    final text = value.toStringAsPrecision(10);
    if (!text.contains('.') || text.contains('e')) return value.toString();
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _InvalidExpression implements Exception {
  const _InvalidExpression();
}

/// Recursive-descent evaluator for `+ - * / % ^`, parentheses and decimals.
///
/// No `eval`, no expressions from anywhere but the user's own message, and
/// every malformed form throws instead of guessing.
class _ExpressionParser {
  _ExpressionParser(this._source);

  final String _source;
  int _index = 0;

  double parseAll() {
    final value = _expression();
    if (_index != _source.length) throw const _InvalidExpression();
    return value;
  }

  double _expression() {
    var value = _term();
    while (true) {
      if (_match('+')) {
        value += _term();
      } else if (_match('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _power();
    while (true) {
      if (_match('*')) {
        value *= _power();
      } else if (_match('/')) {
        final divisor = _power();
        if (divisor == 0) throw const _InvalidExpression();
        value /= divisor;
      } else if (_match('%')) {
        final divisor = _power();
        if (divisor == 0) throw const _InvalidExpression();
        value %= divisor;
      } else {
        return value;
      }
    }
  }

  double _power() {
    final base = _unary();
    if (!_match('^')) return base;
    final exponent = _power();
    if (exponent != exponent.roundToDouble() ||
        exponent.abs() > LocalArithmetic._maxPowerExponent) {
      throw const _InvalidExpression();
    }
    final value = math.pow(base, exponent.toInt()).toDouble();
    if (!value.isFinite) throw const _InvalidExpression();
    return value;
  }

  double _unary() {
    if (_match('-')) return -_unary();
    if (_match('+')) return _unary();
    return _primary();
  }

  double _primary() {
    if (_match('(')) {
      final value = _expression();
      if (!_match(')')) throw const _InvalidExpression();
      return value;
    }
    return _number();
  }

  double _number() {
    final start = _index;
    while (_index < _source.length &&
        (RegExp(r'[0-9]').hasMatch(_source[_index]) ||
            _source[_index] == '.')) {
      _index++;
    }
    if (_index == start) throw const _InvalidExpression();
    final text = _source.substring(start, _index);
    final value = double.tryParse(text);
    if (value == null) throw const _InvalidExpression();
    return value;
  }

  bool _match(String token) {
    if (!_source.startsWith(token, _index)) return false;
    _index += token.length;
    return true;
  }
}

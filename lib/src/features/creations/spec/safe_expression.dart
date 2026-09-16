/// A tiny, total, integer-only expression language for mini-app actions.
///
/// This is the sandbox boundary for generated creations. The only way an
/// action can compute a new value is through [SafeExpression], which
/// understands nothing but arithmetic: there is no `eval`, no `dart:mirrors`,
/// no `dart_eval` and no JavaScript anywhere in the generation pipeline. A spec
/// containing arbitrary-looking text therefore cannot execute it — an
/// unparseable expression is a validation error, never a runtime risk.
library;

/// Raised when an expression cannot be parsed.
///
/// The message is written to be short and actionable because the creation
/// pipeline pastes it verbatim into the model's repair prompt.
class ExpressionException implements Exception {
  const ExpressionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A parsed, reusable integer expression bound to mini-app state.
///
/// Parsing once and evaluating many times keeps the render path cheap: a
/// button press re-evaluates an already-validated tree instead of re-parsing.
class SafeExpression {
  SafeExpression._(this._root, this.referencedKeys);

  final _ExpressionNode _root;

  /// Every state key the expression reads, in first-seen order.
  final Set<String> referencedKeys;

  /// Longest accepted source text.
  static const int maxSourceLength = 120;

  /// Largest accepted token count.
  static const int maxTokens = 64;

  /// Deepest accepted parenthesis/operator nesting.
  static const int maxDepth = 16;

  /// Results are clamped to this magnitude on both sides of zero.
  ///
  /// Arithmetic is performed in [BigInt] and clamped after every operation, so
  /// a generated `x * x * x * ...` chain can neither overflow int64 (which
  /// would wrap into a surprising negative value) nor grow without bound.
  static final BigInt _magnitudeLimit = BigInt.from(1 << 53);

  /// Parses [source] or throws [ExpressionException] with a repair-friendly
  /// message.
  static SafeExpression parse(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw const ExpressionException('expression is empty');
    }
    if (trimmed.length > maxSourceLength) {
      throw ExpressionException(
        'expression is longer than $maxSourceLength characters',
      );
    }
    final tokens = _tokenize(trimmed);
    final parser = _Parser(tokens);
    final root = parser.parseExpression(depth: 0);
    if (!parser.isAtEnd) {
      throw ExpressionException(
        'unexpected "${parser.peek.label}" after the expression',
      );
    }
    return SafeExpression._(root, parser.referencedKeys);
  }

  /// Parses [source], returning `null` instead of throwing.
  static SafeExpression? tryParse(String source) {
    try {
      return parse(source);
    } on ExpressionException {
      return null;
    }
  }

  /// Evaluates the expression against [state].
  ///
  /// Evaluation is total: unknown keys read as `0`, division and modulo by zero
  /// yield `0`, and oversized results clamp rather than wrap.
  int evaluate(Map<String, Object?> state) =>
      _clamp(_root.evaluate(state)).toInt();

  /// Replaces `{key}` placeholders in [template] with the matching state value.
  ///
  /// Used by text nodes, which need to show values without needing a string
  /// type in the expression language.
  static String interpolate(String template, Map<String, Object?> state) {
    if (!template.contains('{')) return template;
    return template.replaceAllMapped(_placeholder, (match) {
      final key = match.group(1)!;
      if (!state.containsKey(key)) return '0';
      return describeValue(state[key]);
    });
  }

  /// Renders a state value as user-visible text.
  static String describeValue(Object? value) => switch (value) {
        null => '0',
        final bool flag => flag ? 'true' : 'false',
        final List<Object?> items => items.join(', '),
        final double number =>
          number == number.truncateToDouble() ? '${number.toInt()}' : '$number',
        _ => '$value',
      };

  static final RegExp _placeholder = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');

  static BigInt _clamp(BigInt value) {
    if (value > _magnitudeLimit) return _magnitudeLimit;
    if (value < -_magnitudeLimit) return -_magnitudeLimit;
    return value;
  }

  static List<_Token> _tokenize(String source) {
    final tokens = <_Token>[];
    var index = 0;
    while (index < source.length) {
      final char = source[index];
      if (_isSpace(char)) {
        index++;
        continue;
      }
      if (_isDigit(char)) {
        var end = index;
        while (end < source.length && _isDigit(source[end])) {
          end++;
        }
        final text = source.substring(index, end);
        final parsed = int.tryParse(text);
        if (parsed == null) {
          throw ExpressionException('"$text" is not a whole number');
        }
        tokens.add(_Token(_TokenKind.number, text, parsed));
        index = end;
        continue;
      }
      if (_isIdentifierStart(char)) {
        var end = index;
        while (end < source.length && _isIdentifierPart(source[end])) {
          end++;
        }
        final text = source.substring(index, end);
        tokens.add(_Token(_TokenKind.identifier, text, null));
        index = end;
        continue;
      }
      final kind = switch (char) {
        '+' => _TokenKind.plus,
        '-' => _TokenKind.minus,
        '*' => _TokenKind.star,
        '/' => _TokenKind.slash,
        '%' => _TokenKind.percent,
        '(' => _TokenKind.leftParen,
        ')' => _TokenKind.rightParen,
        _ => null,
      };
      if (kind == null) {
        throw ExpressionException('"$char" is not allowed in an expression');
      }
      tokens.add(_Token(kind, char, null));
      index++;
      if (tokens.length > maxTokens) {
        throw ExpressionException('expression is too long to evaluate');
      }
    }
    tokens.add(const _Token(_TokenKind.end, 'end', null));
    return tokens;
  }

  static bool _isSpace(String char) => char == ' ' || char == '\t';

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isIdentifierStart(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        char == '_';
  }

  static bool _isIdentifierPart(String char) =>
      _isIdentifierStart(char) || _isDigit(char);
}

enum _TokenKind {
  number,
  identifier,
  plus,
  minus,
  star,
  slash,
  percent,
  leftParen,
  rightParen,
  end,
}

class _Token {
  const _Token(this.kind, this.label, this.number);

  final _TokenKind kind;
  final String label;
  final int? number;
}

class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  final Set<String> referencedKeys = {};
  int _index = 0;

  bool get isAtEnd => peek.kind == _TokenKind.end;

  _Token get peek => _tokens[_index];

  _Token _advance() => _tokens[_index++];

  _ExpressionNode parseExpression({required int depth}) {
    _checkDepth(depth);
    var node = _parseTerm(depth: depth);
    while (peek.kind == _TokenKind.plus || peek.kind == _TokenKind.minus) {
      final operator = _advance().kind;
      final right = _parseTerm(depth: depth);
      node = _BinaryNode(operator, node, right);
    }
    return node;
  }

  _ExpressionNode _parseTerm({required int depth}) {
    _checkDepth(depth);
    var node = _parseUnary(depth: depth);
    while (peek.kind == _TokenKind.star ||
        peek.kind == _TokenKind.slash ||
        peek.kind == _TokenKind.percent) {
      final operator = _advance().kind;
      final right = _parseUnary(depth: depth);
      node = _BinaryNode(operator, node, right);
    }
    return node;
  }

  _ExpressionNode _parseUnary({required int depth}) {
    _checkDepth(depth);
    if (peek.kind == _TokenKind.minus || peek.kind == _TokenKind.plus) {
      final negate = _advance().kind == _TokenKind.minus;
      final operand = _parseUnary(depth: depth + 1);
      return negate ? _NegateNode(operand) : operand;
    }
    return _parsePrimary(depth: depth);
  }

  _ExpressionNode _parsePrimary({required int depth}) {
    _checkDepth(depth);
    final token = _advance();
    switch (token.kind) {
      case _TokenKind.number:
        return _NumberNode(token.number!);
      case _TokenKind.identifier:
        referencedKeys.add(token.label);
        return _VariableNode(token.label);
      case _TokenKind.leftParen:
        final inner = parseExpression(depth: depth + 1);
        if (peek.kind != _TokenKind.rightParen) {
          throw const ExpressionException('missing a closing ")"');
        }
        _advance();
        return inner;
      case _TokenKind.end:
        throw const ExpressionException('the expression ended early');
      default:
        throw ExpressionException(
          '"${token.label}" cannot start an expression',
        );
    }
  }

  void _checkDepth(int depth) {
    if (depth > SafeExpression.maxDepth) {
      throw ExpressionException(
        'expression nests deeper than ${SafeExpression.maxDepth} levels',
      );
    }
  }
}

sealed class _ExpressionNode {
  BigInt evaluate(Map<String, Object?> state);
}

class _NumberNode implements _ExpressionNode {
  const _NumberNode(this.value);

  final int value;

  @override
  BigInt evaluate(Map<String, Object?> state) => BigInt.from(value);
}

class _VariableNode implements _ExpressionNode {
  const _VariableNode(this.key);

  final String key;

  @override
  BigInt evaluate(Map<String, Object?> state) =>
      BigInt.from(_asInt(state[key]));
}

class _NegateNode implements _ExpressionNode {
  const _NegateNode(this.operand);

  final _ExpressionNode operand;

  @override
  BigInt evaluate(Map<String, Object?> state) => -operand.evaluate(state);
}

class _BinaryNode implements _ExpressionNode {
  const _BinaryNode(this.operator, this.left, this.right);

  final _TokenKind operator;
  final _ExpressionNode left;
  final _ExpressionNode right;

  @override
  BigInt evaluate(Map<String, Object?> state) {
    final a = left.evaluate(state);
    final b = right.evaluate(state);
    final result = switch (operator) {
      _TokenKind.plus => a + b,
      _TokenKind.minus => a - b,
      _TokenKind.star => a * b,
      _TokenKind.slash => b == BigInt.zero ? BigInt.zero : a ~/ b,
      _TokenKind.percent => b == BigInt.zero ? BigInt.zero : a % b,
      _ => BigInt.zero,
    };
    return SafeExpression._clamp(result);
  }
}

int _asInt(Object? value) => switch (value) {
      null => 0,
      final int number => number,
      final double number => number.isFinite ? number.toInt() : 0,
      final bool flag => flag ? 1 : 0,
      final List<Object?> items => items.length,
      final String text => int.tryParse(text.trim()) ?? 0,
      _ => 0,
    };

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/safe_expression.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';

/// One reason a generated spec was rejected.
///
/// [describe] is written for two audiences at once: the user-facing note when a
/// repair fails, and — more importantly — the model, because the creation
/// pipeline pastes these lines straight into the repair prompt. Keep messages
/// short, concrete, and phrased as a fixable instruction.
@immutable
class SpecIssue {
  const SpecIssue(this.path, this.message);

  /// JSON pointer-ish location, e.g. `nodes[2].children[0]`.
  final String path;

  final String message;

  String get describe => path.isEmpty ? message : '$path: $message';

  @override
  String toString() => describe;
}

/// Structural validation for every generated spec type.
///
/// Runs on **decoded JSON, before any spec object is constructed**. Nothing
/// here throws: the whole point is to hand the caller a complete list of
/// problems so it can decide between a repair round and a fallback.
abstract final class SpecValidator {
  /// Most issues quoted back to the model in a repair prompt.
  static const int maxRepairIssues = 8;

  static final RegExp _identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  static List<SpecIssue> validateMiniApp(Object? raw) {
    final issues = <SpecIssue>[];
    final root = _asMap(raw);
    if (root == null) {
      return const [SpecIssue('', 'the mini app must be a JSON object')];
    }
    _checkTitle(root, issues, 'title');
    _checkAccent(root, issues);

    final nodes = root['nodes'];
    if (nodes is! List || nodes.isEmpty) {
      issues.add(const SpecIssue('nodes', 'must be a non-empty list of nodes'));
      return issues;
    }

    final written = <String>{};
    final referenced = <String>{};
    final counter = _NodeCounter();
    _visitNodes(nodes, 'nodes', 1, issues, counter, written, referenced);

    if (counter.count > SpecLimits.maxNodes) {
      issues.add(
        SpecIssue(
          'nodes',
          'has ${counter.count} nodes but at most ${SpecLimits.maxNodes} '
              'are allowed',
        ),
      );
    }

    for (final key in referenced.difference(written)) {
      issues.add(
        SpecIssue(
          '',
          '"$key" is displayed but never changed; add a button, field, toggle, '
              'slider or choice that sets "$key"',
        ),
      );
    }
    return issues;
  }

  static List<SpecIssue> validateHomeWidget(Object? raw) {
    final issues = <SpecIssue>[];
    final root = _asMap(raw);
    if (root == null) {
      return const [SpecIssue('', 'the widget must be a JSON object')];
    }
    _checkTitle(root, issues, 'title');
    _checkAccent(root, issues);

    final rows = root['rows'];
    if (rows is! List || rows.isEmpty) {
      issues.add(const SpecIssue('rows', 'must be a non-empty list of rows'));
    } else if (rows.length > SpecLimits.maxWidgetRows) {
      issues.add(
        SpecIssue(
          'rows',
          'has ${rows.length} rows but a home-screen widget fits at most '
              '${SpecLimits.maxWidgetRows}',
        ),
      );
    } else {
      for (var index = 0; index < rows.length; index++) {
        final path = 'rows[$index]';
        final row = _asMap(rows[index]);
        if (row == null) {
          issues.add(SpecIssue(path, 'must be an object with label and value'));
          continue;
        }
        _checkString(
          row,
          'label',
          path,
          issues,
          maxChars: SpecLimits.maxLabelChars,
          required: true,
        );
        _checkString(
          row,
          'value',
          path,
          issues,
          maxChars: SpecLimits.maxWidgetValueChars,
          required: false,
        );
      }
    }

    _checkString(
      root,
      'footer',
      '',
      issues,
      maxChars: SpecLimits.maxLabelChars,
      required: false,
    );
    return issues;
  }

  static List<SpecIssue> validateDeck(Object? raw) {
    final issues = <SpecIssue>[];
    final root = _asMap(raw);
    if (root == null) {
      return const [SpecIssue('', 'the presentation must be a JSON object')];
    }
    _checkTitle(root, issues, 'title');

    final slides = root['slides'];
    if (slides is! List || slides.isEmpty) {
      issues
          .add(const SpecIssue('slides', 'must be a non-empty list of slides'));
      return issues;
    }
    if (slides.length > SpecLimits.maxSlides) {
      issues.add(
        SpecIssue(
          'slides',
          'has ${slides.length} slides but at most ${SpecLimits.maxSlides} '
              'are allowed',
        ),
      );
    }

    for (var index = 0; index < slides.length; index++) {
      final path = 'slides[$index]';
      final slide = _asMap(slides[index]);
      if (slide == null) {
        issues.add(SpecIssue(path, 'must be an object with a title'));
        continue;
      }
      _checkTitle(slide, issues, 'title', path: path);
      _checkString(
        slide,
        'notes',
        path,
        issues,
        maxChars: 500,
        required: false,
      );
      final bullets = slide['bullets'];
      if (bullets == null) continue;
      if (bullets is! List) {
        issues.add(SpecIssue('$path.bullets', 'must be a list of text'));
        continue;
      }
      if (bullets.length > SpecLimits.maxBulletsPerSlide) {
        issues.add(
          SpecIssue(
            '$path.bullets',
            'has ${bullets.length} bullets but at most '
                '${SpecLimits.maxBulletsPerSlide} are allowed',
          ),
        );
      }
      for (var bullet = 0; bullet < bullets.length; bullet++) {
        final value = bullets[bullet];
        if (value is! String || value.trim().isEmpty) {
          issues.add(
            SpecIssue('$path.bullets[$bullet]', 'must be non-empty text'),
          );
        } else if (value.trim().length > SpecLimits.maxBulletChars) {
          issues.add(
            SpecIssue(
              '$path.bullets[$bullet]',
              'is longer than ${SpecLimits.maxBulletChars} characters',
            ),
          );
        }
      }
    }
    return issues;
  }

  /// Renders issues as the bullet list appended to a repair prompt.
  static String describeIssues(List<SpecIssue> issues) {
    final shown = issues.take(maxRepairIssues);
    final buffer = StringBuffer();
    for (final issue in shown) {
      buffer.writeln('- ${issue.describe}');
    }
    if (issues.length > maxRepairIssues) {
      buffer.writeln('- and ${issues.length - maxRepairIssues} more');
    }
    return buffer.toString().trim();
  }

  static void _visitNodes(
    List<Object?> nodes,
    String path,
    int depth,
    List<SpecIssue> issues,
    _NodeCounter counter,
    Set<String> written,
    Set<String> referenced,
  ) {
    if (depth > SpecLimits.maxNodeDepth) {
      issues.add(
        SpecIssue(
          path,
          'nests deeper than ${SpecLimits.maxNodeDepth} levels',
        ),
      );
      return;
    }
    for (var index = 0; index < nodes.length; index++) {
      final nodePath = '$path[$index]';
      counter.count++;
      final node = _asMap(nodes[index]);
      if (node == null) {
        issues.add(SpecIssue(nodePath, 'must be an object with a "type"'));
        continue;
      }
      final rawType = node['type'];
      if (rawType is! String) {
        issues.add(SpecIssue(nodePath, 'is missing a "type"'));
        continue;
      }
      final MiniAppNodeType type;
      try {
        type = MiniAppNodeType.parse(rawType);
      } on FormatException catch (error) {
        issues.add(SpecIssue(nodePath, error.message));
        continue;
      }
      _visitNode(
        type,
        node,
        nodePath,
        depth,
        issues,
        counter,
        written,
        referenced,
      );
    }
  }

  static void _visitNode(
    MiniAppNodeType type,
    Map<String, Object?> node,
    String path,
    int depth,
    List<SpecIssue> issues,
    _NodeCounter counter,
    Set<String> written,
    Set<String> referenced,
  ) {
    switch (type) {
      case MiniAppNodeType.text:
        _checkString(
          node,
          'value',
          path,
          issues,
          maxChars: SpecLimits.maxTextChars,
          required: true,
        );
        final value = node['value'];
        if (value is String) {
          for (final match
              in RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}').allMatches(value)) {
            referenced.add(match.group(1)!);
          }
        }
      case MiniAppNodeType.button:
        _checkString(
          node,
          'label',
          path,
          issues,
          maxChars: SpecLimits.maxLabelChars,
          required: true,
        );
        _checkAction(
            node['action'], '$path.action', issues, written, referenced);
      case MiniAppNodeType.field:
        _checkKey(node, 'key', path, issues, written);
        _checkString(
          node,
          'hint',
          path,
          issues,
          maxChars: SpecLimits.maxLabelChars,
          required: false,
        );
      case MiniAppNodeType.toggle:
        _checkKey(node, 'key', path, issues, written);
        _checkString(
          node,
          'label',
          path,
          issues,
          maxChars: SpecLimits.maxLabelChars,
          required: false,
        );
      case MiniAppNodeType.slider:
        _checkKey(node, 'key', path, issues, written);
        final min = _asInt(node['min']);
        final max = _asInt(node['max']);
        if (min != null && max != null && max <= min) {
          issues.add(
            SpecIssue(path, '"max" must be greater than "min"'),
          );
        }
      case MiniAppNodeType.list:
        _checkKey(node, 'bind', path, issues, referenced);
        _checkString(
          node,
          'empty',
          path,
          issues,
          maxChars: SpecLimits.maxLabelChars,
          required: false,
        );
      case MiniAppNodeType.progress:
        _checkKey(node, 'bind', path, issues, referenced);
        final max = _asInt(node['max']);
        if (max != null && max <= 0) {
          issues.add(SpecIssue(path, '"max" must be greater than zero'));
        }
      case MiniAppNodeType.choice:
        _checkKey(node, 'key', path, issues, written);
        final options = node['options'];
        if (options is! List || options.isEmpty) {
          issues.add(
            SpecIssue('$path.options', 'must be a non-empty list of labels'),
          );
        } else if (options.length > SpecLimits.maxChoices) {
          issues.add(
            SpecIssue(
              '$path.options',
              'has ${options.length} options but at most '
                  '${SpecLimits.maxChoices} are allowed',
            ),
          );
        } else {
          for (var index = 0; index < options.length; index++) {
            final option = options[index];
            if (option is! String || option.trim().isEmpty) {
              issues.add(
                SpecIssue('$path.options[$index]', 'must be non-empty text'),
              );
            }
          }
        }
      case MiniAppNodeType.image:
        final emoji = node['emoji'];
        final url = node['url'];
        final hasEmoji = emoji is String && emoji.trim().isNotEmpty;
        final hasUrl = url is String && url.trim().isNotEmpty;
        if (!hasEmoji && !hasUrl) {
          issues.add(
            SpecIssue(path, 'needs either an "emoji" or an https "url"'),
          );
        }
        if (hasUrl && !url.trim().toLowerCase().startsWith('https://')) {
          issues.add(SpecIssue('$path.url', 'must start with https://'));
        }
      case MiniAppNodeType.row:
      case MiniAppNodeType.column:
        final children = node['children'];
        if (children is! List || children.isEmpty) {
          issues.add(
            SpecIssue('$path.children', 'must be a non-empty list of nodes'),
          );
        } else {
          _visitNodes(
            children,
            '$path.children',
            depth + 1,
            issues,
            counter,
            written,
            referenced,
          );
        }
      case MiniAppNodeType.spacer:
        final size = _asInt(node['size']);
        if (size != null && (size < 0 || size > 200)) {
          issues.add(SpecIssue(path, '"size" must be between 0 and 200'));
        }
    }
  }

  static void _checkAction(
    Object? raw,
    String path,
    List<SpecIssue> issues,
    Set<String> written,
    Set<String> referenced,
  ) {
    final action = _asMap(raw);
    if (action == null) {
      issues.add(SpecIssue(path, 'is missing a "kind"'));
      return;
    }
    final kind = action['kind'];
    if (kind is! String) {
      issues.add(SpecIssue(path, 'is missing a "kind"'));
      return;
    }
    switch (kind.trim().toLowerCase()) {
      case 'set':
        _checkKey(action, 'key', path, issues, written);
        final expr = action['expr'];
        if (expr is! String || expr.trim().isEmpty) {
          issues.add(SpecIssue('$path.expr', 'is required and must be text'));
          return;
        }
        try {
          final parsed = SafeExpression.parse(expr);
          referenced.addAll(parsed.referencedKeys);
        } on ExpressionException catch (error) {
          issues.add(SpecIssue('$path.expr', error.message));
        }
      case 'toggle':
      case 'increment':
        _checkKey(action, 'key', path, issues, written);
      case 'append':
        _checkKey(action, 'key', path, issues, written);
        _checkString(
          action,
          'value',
          path,
          issues,
          maxChars: SpecLimits.maxTextChars,
          required: true,
        );
        // `{key}` placeholders in the value read state, and `clear` writes it.
        final appended = action['value'];
        if (appended is String) {
          referenced.addAll(
            RegExp(r'\{([a-z][a-z0-9_]*)\}')
                .allMatches(appended)
                .map((match) => match.group(1)!),
          );
        }
        if (action['clear'] != null) {
          _checkKey(action, 'clear', path, issues, written);
        }
      case 'reset':
        break;
      default:
        issues.add(
          SpecIssue('$path.kind', '"$kind" is not a supported action'),
        );
    }
  }

  static void _checkKey(
    Map<String, Object?> json,
    String field,
    String path,
    List<SpecIssue> issues,
    Set<String> collectors,
  ) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      issues.add(SpecIssue('$path.$field', 'is required and must be a name'));
      return;
    }
    final key = value.trim();
    if (!_identifier.hasMatch(key)) {
      issues.add(
        SpecIssue(
          '$path.$field',
          '"$key" must start with a letter and use only letters, digits or _',
        ),
      );
      return;
    }
    collectors.add(key);
  }

  static void _checkTitle(
    Map<String, Object?> json,
    List<SpecIssue> issues,
    String field, {
    String path = '',
  }) {
    _checkString(
      json,
      field,
      path,
      issues,
      maxChars: SpecLimits.maxTitleChars,
      required: true,
    );
  }

  static void _checkAccent(Map<String, Object?> json, List<SpecIssue> issues) {
    final raw = json['accent'];
    if (raw == null) return;
    if (raw is! String) {
      issues.add(const SpecIssue('accent', 'must be text'));
      return;
    }
    final allowed =
        MiniAppAccent.values.map((accent) => accent.name).join(', ');
    try {
      MiniAppAccent.parse(raw);
    } on FormatException {
      issues.add(SpecIssue('accent', '"$raw" must be one of: $allowed'));
    }
  }

  static void _checkString(
    Map<String, Object?> json,
    String field,
    String path,
    List<SpecIssue> issues, {
    required int maxChars,
    required bool required,
  }) {
    final target = path.isEmpty ? field : '$path.$field';
    final value = json[field];
    if (value == null) {
      if (required) {
        issues.add(SpecIssue(target, 'is required and must be text'));
      }
      return;
    }
    if (value is! String) {
      issues.add(SpecIssue(target, 'must be text'));
      return;
    }
    if (value.trim().isEmpty) {
      if (required) {
        issues.add(SpecIssue(target, 'must not be empty'));
      }
      return;
    }
    if (value.trim().length > maxChars) {
      issues.add(
        SpecIssue(target, 'is longer than $maxChars characters'),
      );
    }
  }

  static Map<String, Object?>? _asMap(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) return Map<String, Object?>.from(raw);
    return null;
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }
}

class _NodeCounter {
  int count = 0;
}

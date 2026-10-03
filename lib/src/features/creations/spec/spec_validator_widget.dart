part of 'spec_validator.dart';

List<SpecIssue> _validateHomeWidget(Object? raw) {
  final issues = <SpecIssue>[];
  final root = SpecValidator._asMap(raw);
  if (root == null) {
    return const [SpecIssue('', 'the widget must be a JSON object')];
  }
  SpecValidator._checkTitle(root, issues, 'title');
  SpecValidator._checkAccent(root, issues);

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
      final row = SpecValidator._asMap(rows[index]);
      if (row == null) {
        issues.add(SpecIssue(path, 'must be an object with label and value'));
        continue;
      }
      SpecValidator._checkString(
        row,
        'label',
        path,
        issues,
        maxChars: SpecLimits.maxLabelChars,
        required: true,
      );
      SpecValidator._checkString(
        row,
        'value',
        path,
        issues,
        maxChars: SpecLimits.maxWidgetValueChars,
        required: false,
      );
    }
  }

  SpecValidator._checkString(
    root,
    'footer',
    '',
    issues,
    maxChars: SpecLimits.maxLabelChars,
    required: false,
  );
  _checkWidgetKind(root, rows, issues);
  return issues;
}

/// A widget kind must be one the launcher bridge knows, and its rows must
/// have the shape that kind acts on: a counter has one number, a tracker has
/// numbers on every row.
void _checkWidgetKind(
  Map<String, Object?> root,
  Object? rows,
  List<SpecIssue> issues,
) {
  final raw = root['kind'];
  if (raw == null) return;
  final kind = HomeWidgetKind.values.where((k) => k.name == raw).firstOrNull;
  if (kind == null) {
    issues.add(
      SpecIssue(
        'kind',
        'must be one of ${HomeWidgetKind.values.map((k) => k.name).join(', ')}',
      ),
    );
    return;
  }
  if (rows is! List) return;
  bool numeric(Object? row) =>
      row is Map && int.tryParse('${row['value']}'.trim()) != null;
  if (kind == HomeWidgetKind.counter) {
    if (rows.length != 1 || !numeric(rows.first)) {
      issues.add(
        const SpecIssue(
          'rows',
          'a counter widget has exactly one row whose value is a whole '
              'number',
        ),
      );
    }
  }
  if (kind == HomeWidgetKind.tracker && !rows.every(numeric)) {
    issues.add(
      const SpecIssue(
        'rows',
        'every row of a tracker widget has a whole number as its value',
      ),
    );
  }
}

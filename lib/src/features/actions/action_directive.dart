import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';

/// Renders the catalog into the tool contract the model is shown.
///
/// The catalog is closed and small, so the contract stays inside a few hundred
/// tokens; that is what makes intent resolution tractable on a 1.6B model.
abstract final class DeviceActionDirective {
  static String promptFor(String request) =>
      '${build()}\n\nUser request: ${request.trim()}\n';

  static String build() {
    final buffer = StringBuffer('# Device Actions\n\n')
      ..writeln('You can act on the phone. Available actions:\n');
    for (final action in DeviceActionCatalog.all) {
      buffer.writeln(
        '- ${action.name}${_signature(action)}: ${action.summary}',
      );
    }
    buffer
      ..writeln()
      ..writeln('To act, output exactly one tool call:')
      ..writeln('<tool_call>')
      ..writeln('{"name": "<action>", "arguments": {<arguments>}}')
      ..writeln('</tool_call>')
      ..writeln()
      ..writeln(
        'If the request is not a device action, or you are unsure which action '
        'fits, reply exactly: NONE.',
      );
    return buffer.toString().trim();
  }

  static String _signature(DeviceAction action) {
    final required = action.params.where((p) => p.required).map((p) => p.name);
    final optional =
        action.params.where((p) => !p.required).map((p) => '${p.name}?');
    final all = [...required, ...optional];
    return all.isEmpty ? '' : '(${all.join(', ')})';
  }
}

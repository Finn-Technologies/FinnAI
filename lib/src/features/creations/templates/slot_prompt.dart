import 'dart:convert';

import 'package:finn_ai/src/features/creations/templates/creation_template.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

/// The prompt that asks the model to fill a template's slots.
///
/// Far smaller than the old free-form spec prompt: the model is shown a flat
/// JSON object of a few short values, never a component vocabulary. The Brief
/// comes last so a 1.6B model continues from the request, not from the example.
abstract final class SlotPrompt {
  static String build({
    required CreationTemplate template,
    required String brief,
    String? repairNote,
  }) {
    final shape = <String, Object?>{
      for (final slot in template.slots) slot.key: slot.example,
    };
    final buffer = StringBuffer()
      ..writeln(
        'You fill in the details for a small ${template.kind.label.toLowerCase()} '
        'called a ${template.englishName}: ${template.purpose}.',
      )
      ..writeln(
        'Reply with one JSON object using exactly these keys and nothing '
        'else.',
      )
      ..writeln()
      ..writeln(const JsonEncoder().convert(shape))
      ..writeln()
      ..writeln('What each key is:');
    for (final slot in template.slots) {
      buffer.writeln('- ${slot.key}: ${_describe(slot)}');
    }
    buffer
      ..writeln()
      ..writeln(
        'The values above only show the shape. Replace every one of them with '
        'values that fit the Brief.',
      );
    if (repairNote != null && repairNote.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Your last reply could not be used: ${repairNote.trim()}');
    }
    buffer
      ..writeln()
      ..writeln('Brief: "$brief"')
      ..writeln()
      ..writeln(
          'Return the JSON object for this Brief only, and nothing else.');
    return buffer.toString();
  }

  static String _describe(TemplateSlot slot) {
    final limit = switch (slot.kind) {
      SlotKind.text => ' (at most ${slot.maxChars} characters)',
      SlotKind.list =>
        ' (${slot.minItems} to ${slot.maxItems} items, each at most '
            '${slot.maxChars} characters)',
      SlotKind.integer => ' (a whole number from ${slot.minValue} to '
          '${slot.maxValue})',
      SlotKind.choice => ' (exactly one of: ${slot.options.join(', ')})',
      _ => '',
    };
    return '${slot.description}$limit';
  }
}

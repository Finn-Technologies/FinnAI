import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_author.dart';
import 'package:finn_ai/src/features/flows/flow_editor_page.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Builds a flow from a sentence.
///
/// The app's own phrase rules read the sentence first (no model, instant). Only
/// when they find nothing runnable is the on-device model asked to write the
/// flow as a few lines, and those lines are read by the same rules, so the
/// result is always a flow the editor can show and the runner can run. It is
/// saved turned off and opened in the editor, so the user checks it first.
class FlowDescribePage extends StatefulWidget {
  const FlowDescribePage({super.key, required this.actions, this.initialText});

  final FlowsActions actions;
  final String? initialText;

  @override
  State<FlowDescribePage> createState() => _FlowDescribePageState();
}

class _FlowDescribePageState extends State<FlowDescribePage> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initialText);
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    final request = _text.text.trim();
    if (request.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final l10n = L10n.of(context);
    final id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    var draft = FlowAuthor.fromSentence(request, id: id);
    final model = widget.actions.runner?.model;
    if (draft == null && model != null) {
      try {
        final script = await model.answer(
          FlowAuthor.modelPrompt(request),
          maxTokens: 200,
        );
        draft = FlowAuthor.fromScript(
          script,
          id: id,
          fallbackName: request.length <= 40 ? request : '',
        );
      } on Object catch (error) {
        debugPrint('FINN_FLOW author failed: ${error.runtimeType}');
      }
    }
    if (!mounted) return;
    if (draft == null) {
      setState(() {
        _busy = false;
        _message = l10n.flowsDescribeFailed;
      });
      return;
    }
    final saved = await widget.actions.add(context, draft.flow);
    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _busy = false;
        _message = l10n.flowsSaveFailed;
      });
      return;
    }
    await Navigator.of(context).pushReplacement(
      FinnPageRoute<void>(
        child: FlowEditorPage(flowId: saved.id, actions: widget.actions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final examples = [
      l10n.flowsExampleCharger,
      l10n.flowsExampleBattery,
      l10n.flowsExampleNews,
      l10n.flowsExampleHeadset,
    ];
    return FinnPage(
      title: l10n.flowsDescribeTitle,
      footer: FinnButton(
        key: const Key('flow-describe-build'),
        label: _busy ? l10n.flowsDescribeThinking : l10n.flowsDescribeBuild,
        icon: FluxIcons.magic,
        onTap: _busy ? null : () => unawaited(_build()),
      ),
      children: [
        TextField(
          key: const Key('flow-describe-field'),
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 300,
          textInputAction: TextInputAction.newline,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: l10n.flowsDescribeHint,
            counterText: '',
            filled: true,
            fillColor: FluxColors.cardOf(context),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FluxRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_message != null) FinnCaption(_message!),
        const SizedBox(height: 6),
        Text(
          l10n.flowsDescribeExamples,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        for (final example in examples)
          FinnTile(
            key: Key('flow-example-${examples.indexOf(example)}'),
            icon: FluxIcons.magic,
            title: example,
            chevron: false,
            onTap: () => setState(() => _text.text = example),
          ),
      ],
    );
  }
}

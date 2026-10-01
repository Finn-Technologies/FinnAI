import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/you/you_labels.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Write something for FinnAI to remember, or edit something it already has.
class YouAddPage extends StatefulWidget {
  const YouAddPage({
    super.key,
    this.category,
    this.editing,
    this.initialText,
  });

  final YouCategory? category;
  final YouMemory? editing;
  final String? initialText;

  @override
  State<YouAddPage> createState() => _YouAddPageState();
}

class _YouAddPageState extends State<YouAddPage> {
  late final TextEditingController _text = TextEditingController(
    text: widget.editing?.text ?? widget.initialText ?? '',
  );
  late YouCategory _category =
      widget.editing?.category ?? widget.category ?? YouCategory.preferences;
  late bool _useEverywhere = widget.editing?.useInChats ?? true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = YouMemoryStore.instance;
    final editing = widget.editing;
    if (editing != null) {
      await store.update(
        editing.id,
        text: _text.text,
        category: _category,
        useInChats: _useEverywhere,
      );
    } else {
      await store.add(_text.text, _category, useInChats: _useEverywhere);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: _text,
      builder: (context, _) => FinnPage(
        title: l10n.youTellFinn,
        footer: FinnButton(
          label: l10n.youSaveToYou,
          icon: FluxIcons.check,
          onTap: _text.text.trim().isEmpty ? null : () => unawaited(_save()),
        ),
        children: [
          FinnCaption(l10n.youAddLabel),
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: 6,
            maxLength: 280,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: l10n.youAddHint,
              hintStyle: TextStyle(color: FluxColors.mutedOf(context)),
              filled: true,
              fillColor: FluxColors.controlOf(context),
              counterText: '',
              contentPadding: const EdgeInsets.all(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FluxRadius.card),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          Text(
            l10n.youWhereBelongs,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in YouCategory.values)
                FluxChip(
                  label: youCategoryLabel(l10n, category),
                  selected: _category == category,
                  dense: true,
                  onTap: () => setState(() => _category = category),
                ),
            ],
          ),
          FinnTile(
            title: l10n.youUseEveryChat,
            subtitle: l10n.youUseEveryChatSub,
            trailing: FinnSwitch(
              value: _useEverywhere,
              label: l10n.youUseEveryChat,
              onChanged: (value) => setState(() => _useEverywhere = value),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/settings/code_providers_page.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// Picks the model FinnAI Code answers with: the one on the phone, or any
/// model of a provider that has a key, listed live and searchable.
class CodeModelsPage extends StatefulWidget {
  const CodeModelsPage({
    super.key,
    required this.services,
    this.onBack,
    this.onlyProvider,
  });

  final CodeServices services;
  final VoidCallback? onBack;

  /// Shows one provider's models only (from its settings page).
  final CodeProvider? onlyProvider;

  /// Models listed per provider before the search is asked to narrow it: a
  /// provider can offer hundreds.
  static const int shownPerProvider = 80;

  @override
  State<CodeModelsPage> createState() => _CodeModelsPageState();
}

class _CodeModelsPageState extends State<CodeModelsPage> {
  final _search = TextEditingController();
  String _query = '';

  late final _providers = widget.services.providers;

  Iterable<CodeProvider> get _shown => widget.onlyProvider != null
      ? [widget.onlyProvider!]
      : CodeProvider.remote.where(_providers.isConfigured);

  @override
  void initState() {
    super.initState();
    for (final provider in _shown) {
      unawaited(_providers.ensureModels(provider));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(CodeModelRef ref) async {
    final l10n = L10n.of(context);
    if (!ref.isLocal &&
        !_providers.settingsOf(ref.provider).acknowledgedCloud) {
      final name = CodeText.providerName(l10n, ref.provider);
      // A server the user typed in is not "the cloud": say where the words go.
      final custom = ref.provider == CodeProvider.custom;
      final address =
          Uri.tryParse(_providers.baseUrlOf(ref.provider) ?? '')?.authority ??
              '';
      final agreed = await showFinnConfirm(
        context,
        title: custom ? l10n.codeCloudTitleCustom : l10n.codeCloudTitle(name),
        body: custom
            ? l10n.codeCloudBodyCustom(address)
            : l10n.codeCloudBody(name),
        confirmLabel:
            custom ? l10n.codeCloudConfirmCustom : l10n.codeCloudConfirm(name),
      );
      if (agreed != true) return;
      await _providers.acknowledgeCloud(ref.provider);
    }
    await _providers.select(ref);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FinnPage(
      title: widget.onlyProvider == null
          ? l10n.codeModelsTitle
          : CodeText.providerName(l10n, widget.onlyProvider!),
      onBack: widget.onBack,
      children: [
        FluxPillField(
          fieldKey: const ValueKey('code-models-search'),
          controller: _search,
          hint: l10n.codeModelsSearchHint,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value.trim()),
          leading: FluxIcon(
            icon: FluxIcons.search,
            size: 20,
            color: FluxColors.mutedOf(context),
          ),
        ),
        ListenableBuilder(
          listenable: _providers,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _sections(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _sections(BuildContext context) {
    final l10n = L10n.of(context);
    final active = _providers.active;
    final providers = _shown.toList();
    final sections = <Widget>[];
    var index = 0;
    Widget gap() => const SizedBox(height: 10);

    if (widget.onlyProvider == null && _query.isEmpty) {
      sections.addAll([
        FinnReveal(
          index: index++,
          child: FinnTile(
            icon: FluxIcons.chip,
            title: 'FinnAI',
            subtitle: l10n.codeModelsOnDeviceSub,
            chevron: false,
            trailing: active.isLocal ? _Check() : null,
            onTap: () => _choose(CodeModelRef.local),
          ),
        ),
        gap(),
      ]);
    }

    for (final provider in providers) {
      final name = CodeText.providerName(l10n, provider);
      final settings = _providers.settingsOf(provider);
      final loading = _providers.isLoadingModels(provider);
      final error = _providers.errorOf(provider);
      final matches = _filter(settings.models).toList();

      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 6, 5, 10),
          child: FluxSectionLabel(name),
        ),
      );
      if (settings.models.isEmpty) {
        sections.add(
          FinnTile(
            icon: loading ? FluxIcons.loading : FluxIcons.refresh,
            title: loading ? l10n.codeModelsLoading : l10n.codeModelsLoad,
            subtitle: error == null
                ? null
                : l10n.codeModelsFetchFailed(
                    CodeText.failureText(l10n, error.failure)),
            chevron: false,
            onTap: loading ? null : () => _refresh(provider),
          ),
        );
      } else if (matches.isEmpty) {
        sections.add(FinnCaption(l10n.codeModelsNone));
      } else {
        for (final model in matches.take(CodeModelsPage.shownPerProvider)) {
          sections
            ..add(_ModelTile(
              model: model,
              selected: active == model.ref,
              onTap: () => _choose(model.ref),
            ))
            ..add(gap());
        }
        if (matches.length > CodeModelsPage.shownPerProvider) {
          sections.add(
            FinnCaption(
              l10n.codeProviderModelsCount('${matches.length}'),
            ),
          );
        }
      }
      sections.add(const SizedBox(height: 18));
    }

    if (widget.onlyProvider == null && providers.isEmpty) {
      sections.add(
        FinnTile(
          icon: CodeIcons.key,
          title: l10n.codeModelsAddProvider,
          onTap: () => Navigator.of(context).push(
            FinnPageRoute<void>(
              child: CodeProvidersPage(services: widget.services),
            ),
          ),
        ),
      );
    }
    return sections;
  }

  Iterable<CodeModel> _filter(List<CodeModel> models) {
    if (_query.isEmpty) return models;
    final needle = _query.toLowerCase();
    return models.where(
      (m) =>
          m.id.toLowerCase().contains(needle) ||
          m.name.toLowerCase().contains(needle),
    );
  }

  Future<void> _refresh(CodeProvider provider) async {
    try {
      await _providers.refreshModels(provider);
    } on ProviderException {
      // Recorded on the store and shown under the Load button.
    }
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final CodeModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final details = <String>[
      if (model.name != model.id) model.id,
      if (model.contextLength != null)
        l10n.codeModelsContext(CodeText.tokens(model.contextLength!)),
      if (!model.free &&
          model.promptPricePerMillion != null &&
          model.completionPricePerMillion != null)
        l10n.codeModelsPrice(
          CodeText.dollars(model.promptPricePerMillion!),
          CodeText.dollars(model.completionPricePerMillion!),
        ),
    ];
    return FinnTile(
      key: ValueKey('code-model-${model.provider.id}-${model.id}'),
      title: model.name,
      subtitle: details.isEmpty ? null : details.join(' · '),
      chevron: false,
      trailing: selected
          ? _Check()
          : (model.free ? _Badge(label: l10n.codeModelsFree) : null),
      onTap: onTap,
    );
  }
}

class _Check extends StatelessWidget {
  @override
  Widget build(BuildContext context) => FluxIcon(
        icon: FluxIcons.check,
        size: 22,
        color: FluxColors.actionOf(context),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FluxColors.tileOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.pill),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: FluxColors.successOf(context),
                fontSize: 12,
              ),
        ),
      );
}

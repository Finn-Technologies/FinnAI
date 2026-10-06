import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/providers/provider_store.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_models_page.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// One provider: its key, its live model list, what is left to spend, and a
/// test that the key works.
class CodeProviderPage extends StatefulWidget {
  const CodeProviderPage({
    super.key,
    required this.services,
    required this.provider,
  });

  final CodeServices services;
  final CodeProvider provider;

  @override
  State<CodeProviderPage> createState() => _CodeProviderPageState();
}

class _CodeProviderPageState extends State<CodeProviderPage> {
  final _key = TextEditingController();
  final _address = TextEditingController();
  late final CodeProviderStore _store = widget.services.providers;
  CodeProvider get _provider => widget.provider;

  bool _replacing = false;
  bool _addressInvalid = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _address.text = _store.settingsOf(_provider).baseUrl ?? '';
    if (_store.isConfigured(_provider)) {
      unawaited(_store.ensureModels(_provider));
      unawaited(_loadAllowance());
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadAllowance() async {
    try {
      await _store.refreshAllowance(_provider);
    } on ProviderException {
      // Shown from the store's recorded error.
    }
  }

  Future<void> _saveKey() async {
    final value = _key.text.trim();
    if (value.isEmpty) return;
    await _store.saveKey(_provider, value);
    _key.clear();
    setState(() {
      _replacing = false;
      _testResult = null;
    });
    if (_store.isConfigured(_provider)) {
      unawaited(_refreshModels());
      unawaited(_loadAllowance());
    }
  }

  Future<void> _refreshModels() async {
    try {
      await _store.refreshModels(_provider);
    } on ProviderException {
      // Shown from the store's recorded error.
    }
  }

  Future<void> _saveAddress() async {
    final ok = await _store.setCustomBaseUrl(_address.text);
    setState(() => _addressInvalid = !ok);
    if (ok) {
      _address.text = _store.settingsOf(_provider).baseUrl ?? _address.text;
      unawaited(_refreshModels());
    }
  }

  Future<void> _removeKey() async {
    final l10n = L10n.of(context);
    final confirmed = await showFinnConfirm(
      context,
      title: l10n.codeProviderKeyRemoveTitle,
      body: l10n.codeProviderKeyRemoveBody(
        CodeText.providerName(l10n, _provider),
      ),
      confirmLabel: l10n.codeProviderKeyRemove,
      destructive: true,
    );
    if (confirmed != true) return;
    await _store.removeKey(_provider);
    setState(() => _testResult = null);
  }

  /// A model to test with: a free one when there is one, so a test costs
  /// nothing; otherwise the selected one, otherwise the first listed.
  CodeModel? _testModel() {
    final models = _store.settingsOf(_provider).models;
    if (models.isEmpty) return null;
    return models.where((m) => m.free).firstOrNull ??
        models.where((m) => m.ref == _store.active).firstOrNull ??
        models.first;
  }

  Future<void> _test() async {
    final l10n = L10n.of(context);
    final model = _testModel();
    final baseUrl = _store.baseUrlOf(_provider);
    if (model == null || baseUrl == null) {
      setState(() => _testResult = l10n.codeProviderTestNeedsModel);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await _store.client.testKey(
        model,
        baseUrl: baseUrl,
        apiKey: await _store.keyFor(_provider),
      );
      if (!mounted) return;
      setState(() {
        _testResult = l10n.codeProviderTestOk;
      });
    } on ProviderException catch (error) {
      if (!mounted) return;
      setState(() {
        _testResult = l10n.codeProviderTestFail(
          CodeText.failureText(l10n, error.failure),
        );
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _open(Uri? uri) async {
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser: nothing to do.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final name = CodeText.providerName(l10n, _provider);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final settings = _store.settingsOf(_provider);
        final configured = _store.isConfigured(_provider);
        final keyed = settings.hasKey && !_replacing;
        return FinnPage(
          title: name,
          children: [
            FinnCaption(CodeText.providerDescription(l10n, _provider)),
            if (_provider == CodeProvider.commandCode)
              _Note(
                icon: CodeIcons.warning,
                text: l10n.codeProviderPlanNote,
                color: FluxColors.warningOf(context),
              ),
            if (_provider.baseUrlEditable) ..._addressSection(l10n),
            ..._keySection(l10n, settings, keyed),
            if (_provider.keyPage != null)
              FinnTile(
                icon: CodeIcons.openLink,
                title: l10n.codeProviderGetKey,
                chevron: false,
                onTap: () => _open(_provider.keyPage),
              ),
            if (configured) ...[
              ..._allowanceSection(l10n, settings, name),
              ..._modelsSection(l10n, settings, name),
              FinnTile(
                key: const ValueKey('code-test-key'),
                icon: _testing ? FluxIcons.loading : FluxIcons.check,
                title:
                    _testing ? l10n.codeProviderTesting : l10n.codeProviderTest,
                subtitle: _testResult,
                chevron: false,
                onTap: _testing ? null : _test,
              ),
              FinnCaption(l10n.codeProviderPrivacy(name)),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _addressSection(AppLocalizations l10n) => [
        FluxPillField(
          fieldKey: const ValueKey('code-address-field'),
          controller: _address,
          label: l10n.codeProviderAddressLabel,
          hint: l10n.codeProviderAddressHint,
          keyboardType: TextInputType.url,
          enableSuggestions: false,
        ),
        if (_addressInvalid) FinnCaption(l10n.codeProviderAddressInvalid),
        FinnButton(
          key: const ValueKey('code-address-save'),
          label: l10n.codeProviderAddressSave,
          onTap: _saveAddress,
          secondary: true,
        ),
      ];

  List<Widget> _keySection(
      AppLocalizations l10n, ProviderSettings settings, bool keyed) {
    if (keyed) {
      return [
        FinnTile(
          icon: CodeIcons.key,
          title: l10n.codeProviderKeyLabel,
          subtitle: '••••${settings.keyHint}  ·  '
              '${l10n.codeProviderKeyStored}',
          chevron: false,
        ),
        Row(
          children: [
            Expanded(
              child: FinnButton(
                label: l10n.codeProviderKeyReplace,
                onTap: () => setState(() => _replacing = true),
                secondary: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FinnButton(
                key: const ValueKey('code-key-remove'),
                label: l10n.codeProviderKeyRemove,
                onTap: _removeKey,
                secondary: true,
              ),
            ),
          ],
        ),
      ];
    }
    return [
      FluxPillField(
        fieldKey: const ValueKey('code-key-field'),
        controller: _key,
        label: l10n.codeProviderKeyLabel,
        hint: (_provider.keyRequired
            ? l10n.codeProviderKeyHint
            : l10n.codeProviderKeyOptionalHint),
        obscure: true,
        monospace: true,
      ),
      FinnButton(
        key: const ValueKey('code-key-save'),
        label: l10n.codeProviderKeySave,
        onTap: _saveKey,
      ),
    ];
  }

  List<Widget> _allowanceSection(
      AppLocalizations l10n, ProviderSettings settings, String name) {
    if (_provider == CodeProvider.custom) return const [];
    if (!_provider.hasAllowanceApi) {
      return [
        FluxSectionLabel(l10n.codeProviderAllowance),
        FinnCaption(l10n.codeProviderAllowanceNoApi(name)),
        FinnButton(
          label: l10n.codeProviderOpenDashboard,
          onTap: () => _open(_provider.billingPage),
          secondary: true,
          icon: CodeIcons.openLink,
        ),
      ];
    }
    final allowance = settings.allowance;
    final loading = _store.isLoadingAllowance(_provider);
    final error = _store.errorOf(_provider);
    final lines = <String>[
      if (allowance != null) ...[
        if (allowance.capped &&
            allowance.remaining != null &&
            allowance.limit != null)
          l10n.codeProviderAllowanceRemaining(
            CodeText.dollars(allowance.remaining!),
            CodeText.dollars(allowance.limit!),
          )
        else
          l10n.codeProviderAllowanceUnlimited,
        if (allowance.used != null)
          l10n.codeProviderAllowanceUsed(CodeText.dollars(allowance.used!)),
        if (allowance.usedToday != null && allowance.usedToday! > 0)
          l10n.codeProviderAllowanceToday(
              CodeText.dollars(allowance.usedToday!)),
        if (allowance.usedThisMonth != null && allowance.usedThisMonth! > 0)
          l10n.codeProviderAllowanceMonth(
              CodeText.dollars(allowance.usedThisMonth!)),
        if (allowance.balance != null)
          l10n.codeProviderAllowanceBalance(
              CodeText.dollars(allowance.balance!)),
        if (allowance.freeTier == true) l10n.codeProviderAllowanceFree,
      ],
    ];
    return [
      FluxSectionLabel(l10n.codeProviderAllowance),
      FinnTile(
        key: const ValueKey('code-allowance'),
        icon: CodeIcons.wallet,
        title: lines.isEmpty
            ? (loading ? l10n.codeModelsLoading : l10n.codeProviderAllowance)
            : lines.first,
        subtitle: lines.length > 1 ? lines.skip(1).join('\n') : null,
        chevron: false,
        trailing: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: loading ? null : _loadAllowance,
      ),
      if (error != null && !loading && allowance == null)
        FinnCaption(CodeText.failureText(L10n.of(context), error.failure)),
    ];
  }

  List<Widget> _modelsSection(
      AppLocalizations l10n, ProviderSettings settings, String name) {
    final loading = _store.isLoadingModels(_provider);
    final count = settings.models.length;
    final error = _store.errorOf(_provider);
    return [
      FluxSectionLabel(l10n.codeProviderChooseModel),
      FinnTile(
        key: const ValueKey('code-models-count'),
        icon: FluxIcons.chip,
        title: loading
            ? l10n.codeModelsLoading
            : l10n.codeProviderModelsCount('$count'),
        subtitle: count > 0
            ? l10n.codeProviderModelsLive(name)
            : (error == null
                ? null
                : l10n.codeModelsFetchFailed(
                    CodeText.failureText(L10n.of(context), error.failure),
                  )),
        onTap: count == 0
            ? null
            : () => Navigator.of(context).push(
                  FinnPageRoute<void>(
                    child: CodeModelsPage(
                      services: widget.services,
                      onlyProvider: _provider,
                    ),
                  ),
                ),
      ),
      FinnButton(
        key: const ValueKey('code-models-refresh'),
        label: l10n.codeProviderModelsRefresh,
        onTap: loading ? null : _refreshModels,
        secondary: true,
        icon: FluxIcons.refresh,
      ),
    ];
  }
}

/// A short callout: a glyph and a line of copy on a card, with the same
/// hairline-edged treatment as the notices in chat and the error card in the
/// transcript.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: FluxSurfaces.flatCard(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FluxIcon(icon: icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}

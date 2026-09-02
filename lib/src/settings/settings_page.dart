import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state_store.dart';
import '../config/legal_config.dart';
import '../conversations/conversation_store.dart';
import '../flux_app.dart';
import '../inference/finn_inference.dart';
import '../theme/flux_theme.dart';
import '../../l10n/l10n_helper.dart';
import '../widgets/ambient_background.dart';
import '../widgets/finn_page_header.dart';
import '../widgets/flux_controls.dart';

/// Full-screen Settings page for FinnAI.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  bool _clearingMemory = false;
  bool _deletingAllData = false;
  String _appVersion = '1.0.0 (1)';

  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _entranceController,
    curve: Curves.easeInOutCubicEmphasized,
  );

  List<ModelStorageState>? _storageStates;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSettingsData();
    if (WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _entranceController.value = 1;
    } else {
      _entranceController.forward();
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  Future<void> _loadSettingsData() async {
    final statesFuture = FinnInference.instance.inspectModels();
    final packageFuture = PackageInfo.fromPlatform()
        .then<PackageInfo?>((value) => value)
        .catchError((_) => null);
    final states = await statesFuture;
    final info = await packageFuture;
    if (!mounted) return;
    setState(() {
      _storageStates = states;
      if (info != null) _appVersion = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _clearMemory() async {
    setState(() => _clearingMemory = true);
    await FinnInference.instance.releaseMemory();
    if (mounted) {
      setState(() => _clearingMemory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).settingsPurgeMemoryReleased),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadius.sm),
          ),
        ),
      );
    }
  }

  void _confirmPurgeMemory() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadius.sheet)),
        title: Text(L10n.of(context).settingsPurgeMemoryTitle),
        content: Text(
          L10n.of(context).settingsPurgeMemoryBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              L10n.of(context).commonCancel,
              style: TextStyle(color: FluxColors.mutedOf(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _clearMemory();
            },
            child: Text(
              L10n.of(context).commonPurge,
              style: TextStyle(
                color: FluxColors.isDark(context)
                    ? FluxColors.destructiveDark
                    : FluxColors.destructive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllChats() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadius.sheet)),
        title: Text(L10n.of(context).settingsClearHistoryTitle),
        content: Text(
          L10n.of(context).settingsClearHistoryBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              L10n.of(context).commonCancel,
              style: TextStyle(color: FluxColors.mutedOf(context)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ConversationStore.instance.clearAllAndFlush();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        L10n.of(context).settingsClearHistoryFailure,
                      ),
                    ),
                  );
                }
                return;
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(L10n.of(context).settingsClearHistorySuccess),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FluxRadius.sm),
                    ),
                  ),
                );
              }
            },
            child: Text(
              L10n.of(context).commonClearAll,
              style: TextStyle(
                color: FluxColors.isDark(context)
                    ? FluxColors.destructiveDark
                    : FluxColors.destructive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllData() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadius.sheet)),
        title: Text(L10n.of(context).settingsDeleteAllDataTitle),
        content: Text(
          L10n.of(context).settingsDeleteAllDataBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              L10n.of(context).commonCancel,
              style: TextStyle(color: FluxColors.mutedOf(context)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              setState(() => _deletingAllData = true);
              DeletionResult result;
              try {
                result = await AppStateStore.instance.deleteAllData();
              } catch (e) {
                result = DeletionResult(
                  deletedItems: const [],
                  nonExistentItems: const [],
                  failedItems: ['All local data ($e)'],
                );
              }
              try {
                await _loadSettingsData();
              } catch (_) {}
              if (mounted) {
                setState(() => _deletingAllData = false);
                if (result.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        L10n.of(context).settingsDeleteAllDataSuccess,
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FluxRadius.sm),
                      ),
                    ),
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const FinnBootstrap(),
                    ),
                    (route) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        L10n.of(context).settingsDeleteAllDataPartialFailure(
                            result.failedItems.join(', ')),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FluxRadius.sm),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              L10n.of(context).commonDeleteEverything,
              style: TextStyle(
                color: FluxColors.isDark(context)
                    ? FluxColors.destructiveDark
                    : FluxColors.destructive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _pullUp(double offset) {
    if (!_scrollController.hasClients) return 0;
    if (!_scrollController.position.hasContentDimensions) return 0;
    return math.max(0.0, offset - _scrollController.position.maxScrollExtent);
  }

  double _shiftFor(
    double offset, {
    required double downMultiplier,
    required double upMultiplier,
  }) {
    if (offset < 0) return (-offset) * downMultiplier;
    final up = _pullUp(offset);
    if (up > 0) return -up * upMultiplier;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AmbientBackground(
        intensity: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double sy = (constraints.maxHeight / 844).clamp(0.7, 1.3);
            final double safeBottom = MediaQuery.paddingOf(context).bottom;

            const double pageHorizontalInset = 20;
            final metrics =
                FinnPageHeaderMetrics.forHeight(constraints.maxHeight);
            const double headerHeight = 34;
            final double headerTop = metrics.headerTop;
            final double initialTitleTop = metrics.initialTitleTop;
            final double pinnedTitleTop = metrics.pinnedTitleTop;
            const double titleHeight = 30;
            final double titleTravelDistance = initialTitleTop - pinnedTitleTop;
            final double contentTop = initialTitleTop + titleHeight + 10;

            return Stack(
              children: [
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      ConversationStore.instance,
                      FinnInference.instance,
                    ]),
                    builder: (context, _) {
                      final totalChats =
                          ConversationStore.instance.conversations.length;
                      final states = _storageStates;
                      final selectedTier = FinnInference.instance.selected.tier;

                      final scrollView = CustomScrollView(
                        controller: _scrollController,
                        physics: const FluxBouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(height: contentTop),
                          ),

                          // ── AI MODELS section ──
                          SliverToBoxAdapter(
                            child: _SpringSection(
                              scrollOffset: _scrollOffset,
                              shiftFn: (offset) => _shiftFor(
                                offset,
                                downMultiplier: 0.10,
                                upMultiplier: 0.30,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: pageHorizontalInset,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                        label:
                                            L10n.of(context).settingsAiModel),
                                    const SizedBox(height: 8),
                                    FluxGlass(
                                      radius: 20,
                                      child: states == null
                                          ? const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 28,
                                              ),
                                              child: Center(
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                for (int i = 0;
                                                    i < states.length;
                                                    i++) ...[
                                                  if (i > 0)
                                                    Divider(
                                                      height: 1,
                                                      color: FluxColors.lineOf(
                                                        context,
                                                      ).withValues(alpha: 0.5),
                                                    ),
                                                  _ModelRow(
                                                    state: states[i],
                                                    isActive:
                                                        states[i].model.tier ==
                                                            selectedTier,
                                                  ),
                                                ],
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SliverToBoxAdapter(child: const SizedBox(height: 24)),

                          // ── STORAGE & DATA section ──
                          SliverToBoxAdapter(
                            child: _SpringSection(
                              scrollOffset: _scrollOffset,
                              shiftFn: (offset) => _shiftFor(
                                offset,
                                downMultiplier: 0.20,
                                upMultiplier: 0.20,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: pageHorizontalInset,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                      label:
                                          L10n.of(context).settingsStorageData,
                                    ),
                                    const SizedBox(height: 8),
                                    FluxGlass(
                                      radius: 20,
                                      child: Column(
                                        children: [
                                          _InfoRow(
                                            icon: FluxIcons.settings,
                                            label: L10n.of(context)
                                                .settingsSavedConversationsLabel,
                                            value: totalChats == 1
                                                ? L10n.of(context)
                                                    .settingsSavedConversations(
                                                        1)
                                                : L10n.of(context)
                                                    .settingsSavedConversations(
                                                        totalChats),
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _DestructiveRow(
                                            icon: FluxIcons.chip,
                                            label: _clearingMemory
                                                ? L10n.of(context)
                                                    .settingsReleasingMemory
                                                : L10n.of(context)
                                                    .settingsPurgeMemory,
                                            enabled: !_clearingMemory,
                                            loading: _clearingMemory,
                                            onTap: _confirmPurgeMemory,
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _DestructiveRow(
                                            icon: FluxIcons.refresh,
                                            label: L10n.of(context)
                                                .settingsClearHistory,
                                            enabled: totalChats > 0,
                                            onTap: _confirmClearAllChats,
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _DestructiveRow(
                                            icon: FluxIcons.security,
                                            label: _deletingAllData
                                                ? L10n.of(context)
                                                    .settingsDeleteAllDataDeleting
                                                : L10n.of(context)
                                                    .settingsDeleteAllData,
                                            enabled: !_deletingAllData,
                                            loading: _deletingAllData,
                                            onTap: _confirmDeleteAllData,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SliverToBoxAdapter(child: const SizedBox(height: 24)),

                          // ── PRIVACY & LEGAL section ──
                          SliverToBoxAdapter(
                            child: _SpringSection(
                              scrollOffset: _scrollOffset,
                              shiftFn: (offset) => _shiftFor(
                                offset,
                                downMultiplier: 0.25,
                                upMultiplier: 0.15,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: pageHorizontalInset,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                      label:
                                          L10n.of(context).settingsPrivacyLegal,
                                    ),
                                    const SizedBox(height: 8),
                                    FluxGlass(
                                      radius: 20,
                                      child: Column(
                                        children: [
                                          _ActionRow(
                                            icon: FluxIcons.lock,
                                            label: L10n.of(context)
                                                .settingsPrivacyPolicy,
                                            onTap: () async {
                                              if (LegalConfig
                                                  .hasPrivacyPolicyUrl) {
                                                final uri = Uri.parse(
                                                  LegalConfig.privacyPolicyUrl,
                                                );
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(
                                                    uri,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          L10n.of(context)
                                                              .settingsPrivacyPolicyLaunchFailed(
                                                                  LegalConfig
                                                                      .privacyPolicyUrl),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      L10n.of(context)
                                                          .settingsPrivacyPolicyUnconfigured,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _ActionRow(
                                            icon: FluxIcons.security,
                                            label: L10n.of(context)
                                                .settingsTermsOfUse,
                                            onTap: () async {
                                              if (LegalConfig.hasTermsUrl) {
                                                final uri = Uri.parse(
                                                  LegalConfig.termsUrl,
                                                );
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(
                                                    uri,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          L10n.of(context)
                                                              .settingsTermsLaunchFailed(
                                                                  LegalConfig
                                                                      .termsUrl),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      L10n.of(context)
                                                          .settingsTermsUnconfigured,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _ActionRow(
                                            icon: FluxIcons.security,
                                            label: L10n.of(context)
                                                .settingsSupportContact,
                                            onTap: () async {
                                              if (LegalConfig.hasSupportEmail) {
                                                final uri = Uri.parse(
                                                  'mailto:${LegalConfig.supportEmail}',
                                                );
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri);
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          L10n.of(context)
                                                              .settingsSupportEmailLabel(
                                                                  LegalConfig
                                                                      .supportEmail),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              } else if (LegalConfig
                                                  .hasSupportUrl) {
                                                final uri = Uri.parse(
                                                  LegalConfig.supportUrl,
                                                );
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(
                                                    uri,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } else if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        L10n.of(context)
                                                            .settingsSupportLaunchFailed(
                                                                LegalConfig
                                                                    .supportUrl),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      L10n.of(context)
                                                          .settingsSupportUnavailable,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _ActionRow(
                                            icon: FluxIcons.leaf,
                                            label: L10n.of(context)
                                                .settingsOpenSourceLicenses,
                                            onTap: () {
                                              showLicensePage(
                                                context: context,
                                                applicationName: 'FinnAI',
                                                applicationVersion: _appVersion,
                                                applicationLegalese:
                                                    'Created using LFM2.5-VL 1.6B by Liquid AI, Inc. under the LFM Open License v1.0.\n'
                                                    'Powered by llama.cpp and Flutter.',
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SliverToBoxAdapter(child: const SizedBox(height: 24)),

                          // ── ABOUT section ──
                          SliverToBoxAdapter(
                            child: _SpringSection(
                              scrollOffset: _scrollOffset,
                              shiftFn: (offset) => _shiftFor(
                                offset,
                                downMultiplier: 0.30,
                                upMultiplier: 0.10,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: pageHorizontalInset,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                        label: L10n.of(context).settingsAbout),
                                    const SizedBox(height: 8),
                                    FluxGlass(
                                      radius: 20,
                                      child: Column(
                                        children: [
                                          _InfoRow(
                                            icon: FluxIcons.magic,
                                            label: L10n.of(context)
                                                .settingsAppVersion,
                                            value: _appVersion,
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _InfoRow(
                                            icon: FluxIcons.robot,
                                            label: L10n.of(context)
                                                .settingsInferenceEngine,
                                            value: L10n.of(context)
                                                .settingsInferenceEngineValue,
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _InfoRow(
                                            icon: FluxIcons.security,
                                            label: L10n.of(context)
                                                .settingsPrivacyMode,
                                            value: L10n.of(context)
                                                .settingsPrivacyModeValue,
                                          ),
                                          Divider(
                                            height: 1,
                                            color: FluxColors.lineOf(context)
                                                .withValues(alpha: 0.5),
                                          ),
                                          _InfoRow(
                                            icon: FluxIcons.leaf,
                                            label: L10n.of(context)
                                                .settingsModelArchitecture,
                                            value: L10n.of(context)
                                                .settingsModelArchitectureValue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SliverToBoxAdapter(
                            child: SizedBox(height: 40 + safeBottom),
                          ),
                        ],
                      );
                      if (MediaQuery.disableAnimationsOf(context)) {
                        return scrollView;
                      }
                      return ClipRect(
                        child: AnimatedBuilder(
                          animation: _entrance,
                          child: scrollView,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              0,
                              constraints.maxHeight * (1 - _entrance.value),
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Lightweight pinned-header surface ──
                ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, _) {
                    final double scrollUp = math.max(0.0, offset);
                    final double coverProgress = (scrollUp / 24.0).clamp(
                      0.0,
                      1.0,
                    );
                    final double coverHeight = coverProgress <= 0
                        ? 0.0
                        : pinnedTitleTop + titleHeight + 14 * sy;

                    return Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: coverHeight,
                      child: IgnorePointer(
                        child: coverProgress <= 0
                            ? const SizedBox()
                            : ColoredBox(
                                color: FluxColors.canvasOf(
                                  context,
                                ).withValues(alpha: .96),
                              ),
                      ),
                    );
                  },
                ),

                // ── BackControl ──
                Positioned(
                  left: pageHorizontalInset,
                  right: pageHorizontalInset,
                  top: headerTop,
                  height: headerHeight,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, offset, child) {
                      final double shift = _shiftFor(
                        offset,
                        downMultiplier: 0.20,
                        upMultiplier: 0.20,
                      );
                      final double scrollUp = math.max(0.0, offset);
                      final double opacity =
                          (1.0 - (scrollUp / (titleTravelDistance * 0.5)))
                              .clamp(0.0, 1.0);

                      return IgnorePointer(
                        ignoring: opacity < 0.5,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, shift),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BackControl(onTap: widget.onBack),
                    ),
                  ),
                ),

                // ── "Settings" title ──
                Positioned(
                  left: pageHorizontalInset,
                  right: pageHorizontalInset,
                  top: initialTitleTop,
                  height: titleHeight,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, offset, child) {
                      double shift;
                      if (offset < 0) {
                        shift = (-offset) * 0.70;
                      } else {
                        final up = _pullUp(offset);
                        final travelled = math.min(titleTravelDistance, offset);
                        shift = -travelled + (up > 0 ? -up * 0.70 : 0.0);
                      }
                      return Transform.translate(
                        offset: Offset(0, shift),
                        child: child,
                      );
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        L10n.of(context).settingsTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpringSection extends StatelessWidget {
  const _SpringSection({
    required this.scrollOffset,
    required this.shiftFn,
    required this.child,
  });

  final ValueNotifier<double> scrollOffset;
  final double Function(double offset) shiftFn;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scrollOffset,
      builder: (context, offset, _) {
        final shift = shiftFn(offset);
        return Transform.translate(offset: Offset(0, shift), child: child);
      },
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.state, required this.isActive});

  final ModelStorageState state;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final model = state.model;
    final isDark = FluxColors.isDark(context);

    final inference = FinnInference.instance;
    final downloading = inference.phase == InferencePhase.downloading &&
        inference.workingModel?.tier == state.model.tier;
    final progress = downloading
        ? (inference.installProgress ?? inference.downloadProgress ?? 0)
        : 0.0;
    final speedLabel = downloading ? inference.downloadSpeedLabel : null;
    final etaLabel = downloading ? inference.downloadEtaLabel : null;

    final activeAndInstalled = isActive && state.installed;
    final statusLabel = downloading
        ? '${(progress * 100).round()}%'
        : activeAndInstalled
            ? L10n.of(context).settingsModelActive
            : state.installed
                ? L10n.of(context).settingsModelInstalled
                : state.resumable
                    ? L10n.of(context).settingsModelPartial
                    : L10n.of(context).settingsModelNotInstalled;

    final statusColor = downloading
        ? FluxColors.accentBlue
        : activeAndInstalled
            ? (isDark ? FluxColors.accentGreenDark : FluxColors.accentGreen)
            : state.installed
                ? (isDark ? FluxColors.accentGreenDark : FluxColors.accentGreen)
                : state.resumable
                    ? FluxColors.accentAmber
                    : FluxColors.mutedOf(context);

    final transferInfo = [
      if (speedLabel != null) speedLabel,
      if (etaLabel != null) etaLabel,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: FluxColors.inkOf(context).withValues(
                alpha: isDark ? 0.08 : 0.05,
              ),
              borderRadius: BorderRadius.circular(FluxRadius.sm),
            ),
            alignment: Alignment.center,
            child: FluxIcon(
              icon: FluxIcons.chip,
              size: 18,
              color: isActive
                  ? FluxColors.inkOf(context)
                  : FluxColors.mutedOf(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      model.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${model.parameterLabel} · ${model.sizeLabel}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: FluxColors.mutedOf(context),
                      ),
                ),
                if (downloading && transferInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    transferInfo,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: FluxColors.accentBlue,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FluxRadius.pill),
            ),
            child: Text(
              statusLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontSize: 11,
              color: FluxColors.mutedOf(context),
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FluxColors.inkOf(context).withValues(
                alpha: isDark ? 0.08 : 0.05,
              ),
              borderRadius: BorderRadius.circular(FluxRadius.sm),
            ),
            alignment: Alignment.center,
            child: FluxIcon(
              icon: icon,
              size: 17,
              color: FluxColors.mutedOf(context),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FluxRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FluxColors.inkOf(context).withValues(
                    alpha: isDark ? 0.08 : 0.05,
                  ),
                  borderRadius: BorderRadius.circular(FluxRadius.sm),
                ),
                alignment: Alignment.center,
                child: FluxIcon(
                  icon: icon,
                  size: 17,
                  color: FluxColors.inkOf(context),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: FluxColors.mutedOf(context).withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final color = enabled
        ? (isDark ? FluxColors.destructiveDark : FluxColors.destructive)
        : FluxColors.mutedOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(FluxRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(FluxRadius.sm),
                ),
                alignment: Alignment.center,
                child: FluxIcon(icon: icon, size: 17, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                ),
              ),
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

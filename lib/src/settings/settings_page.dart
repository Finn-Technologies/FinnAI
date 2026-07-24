import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../ads/banner_ad_widget.dart';
import '../conversations/conversation_store.dart';
import '../inference/bonsai_inference.dart';
import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/flux_controls.dart';

/// Full-screen Settings page for Finn AI.
///
/// Scroll mechanics mirror the sidebar:
///   • BouncingScrollPhysics for both overscroll directions.
///   • BackControl fades & parallaxes at 0.20× on pull-down and pull-up.
///   • "Settings" title travels up to pin at header on normal scroll and
///     parallaxes at 0.70× on both overscroll directions.
///   • The three sections (AI MODELS / STORAGE & DATA / ABOUT) each have their
///     own parallax multiplier so they fan apart on both overscroll ends:
///       - Pull-down: AI=0.20, STORAGE=0.45, ABOUT=0.70
///         (lower sections move further down → gaps widen downward)
///       - Pull-up:   AI=0.70, STORAGE=0.45, ABOUT=0.20
///         (upper sections move further up → gaps widen upward)
///     This creates a symmetric "accordion" separation on both ends.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _clearingMemory = false;

  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  List<ModelStorageState>? _storageStates;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadStorageStates();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  Future<void> _loadStorageStates() async {
    final states = await BonsaiInference.instance.inspectModels();
    if (mounted) setState(() => _storageStates = states);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  Future<void> _clearMemory() async {
    setState(() => _clearingMemory = true);
    await BonsaiInference.instance.releaseMemory();
    if (mounted) {
      setState(() => _clearingMemory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI model memory released.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _confirmPurgeMemory() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Purge AI Memory?'),
        content: const Text(
          'This will unload the AI model from RAM. It will be reloaded automatically on the next message.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _clearMemory();
            },
            child: Text(
              'Purge',
              style: TextStyle(
                color: FluxColors.isDark(context)
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFFD32F2F),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Conversations?'),
        content: const Text(
          'This will permanently delete all chat history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ConversationStore.instance.clearAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All conversations cleared.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Clear All',
              style: TextStyle(
                color: FluxColors.isDark(context)
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFFD32F2F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pull-up overscroll amount — positive only when past the bottom.
  double _pullUp(double offset) {
    if (!_scrollController.hasClients) return 0;
    if (!_scrollController.position.hasContentDimensions) return 0;
    return math.max(0.0, offset - _scrollController.position.maxScrollExtent);
  }

  /// Extra shift for a section during overscroll.
  ///   [downMultiplier] — applied on pull-down (positive = moves further down).
  ///   [upMultiplier]   — applied on pull-up   (positive = moves further up).
  double _shiftFor(
    double offset, {
    required double downMultiplier,
    required double upMultiplier,
  }) {
    if (offset < 0) return (-offset) * downMultiplier; // pull-down
    final up = _pullUp(offset);
    if (up > 0) return -up * upMultiplier; // pull-up
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

            // ── Layout geometry ────────────────────────────────────────────
            const double pageHorizontalInset = 20;
            const double headerHeight = 34;
            const double adBannerHeight = 50;
            final double headerTop = 71 * sy;
            final double initialTitleTop = headerTop + headerHeight + 10 * sy;
            final double pinnedTitleTop = headerTop;
            const double titleHeight = 30;
            final double titleTravelDistance = initialTitleTop - pinnedTitleTop;
            final double contentTop = initialTitleTop + titleHeight + 10;

            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                _scrollOffset.value = n.metrics.pixels;
                return false;
              },
              child: Stack(
                children: [
                  // ── 1. Scrollable content ──────────────────────────────
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        ConversationStore.instance,
                        BonsaiInference.instance,
                      ]),
                      builder: (context, _) {
                        final totalChats =
                            ConversationStore.instance.conversations.length;
                        final states = _storageStates;
                        final selectedTier =
                            BonsaiInference.instance.selected.tier;

                        return CustomScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            // Top padding — reserves space for header + title
                            SliverToBoxAdapter(
                              child: SizedBox(height: contentTop),
                            ),

                            // ── Banner ad — leads the section spring sequence ──
                            SliverToBoxAdapter(
                              child: _SpringSection(
                                scrollOffset: _scrollOffset,
                                shiftFn: (offset) => _shiftFor(
                                  offset,
                                  downMultiplier: 0.00,
                                  upMultiplier: 0.40,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: pageHorizontalInset,
                                  ),
                                  child: SizedBox(
                                    height: adBannerHeight,
                                    child: BannerAdWidget(
                                      margin: EdgeInsets.zero,
                                      adUnitId:
                                          AdService.settingsBannerAdUnitId,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SliverToBoxAdapter(
                              child: const SizedBox(height: 14),
                            ),

                            // ── AI MODELS section (0.20 down / 0.70 up) ──
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionHeader(label: 'AI MODELS'),
                                      const SizedBox(height: 10),
                                      FluxGlass(
                                        radius: 16,
                                        child: states == null
                                            ? const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 24,
                                                ),
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                              )
                                            : Column(
                                                children: [
                                                  for (
                                                    int i = 0;
                                                    i < states.length;
                                                    i++
                                                  ) ...[
                                                    if (i > 0)
                                                      Divider(
                                                        height: 1,
                                                        color:
                                                            FluxColors.lineOf(
                                                              context,
                                                            ),
                                                      ),
                                                    _ModelRow(
                                                      state: states[i],
                                                      isActive:
                                                          states[i]
                                                              .model
                                                              .tier ==
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

                            SliverToBoxAdapter(
                              child: const SizedBox(height: 28),
                            ),

                            // ── STORAGE & DATA (0.45 down / 0.45 up) ─────
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionHeader(
                                        label: 'STORAGE & DATA',
                                      ),
                                      const SizedBox(height: 10),
                                      FluxGlass(
                                        radius: 16,
                                        child: Column(
                                          children: [
                                            _InfoRow(
                                              icon: FluxIcons.settings,
                                              label: 'Saved Conversations',
                                              value: totalChats == 1
                                                  ? '1 chat'
                                                  : '$totalChats chats',
                                            ),
                                            Divider(
                                              height: 1,
                                              color: FluxColors.lineOf(context),
                                            ),
                                            _DestructiveRow(
                                              icon: FluxIcons.chip,
                                              label: _clearingMemory
                                                  ? 'Releasing Memory…'
                                                  : 'Purge AI Memory',
                                              enabled: !_clearingMemory,
                                              loading: _clearingMemory,
                                              onTap: _confirmPurgeMemory,
                                            ),
                                            Divider(
                                              height: 1,
                                              color: FluxColors.lineOf(context),
                                            ),
                                            _DestructiveRow(
                                              icon: FluxIcons.refresh,
                                              label: 'Clear All Chat History',
                                              enabled: totalChats > 0,
                                              onTap: _confirmClearAllChats,
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
                              child: const SizedBox(height: 28),
                            ),

                            // ── ABOUT (0.70 down / 0.20 up) ──────────────
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionHeader(label: 'ABOUT'),
                                      const SizedBox(height: 10),
                                      FluxGlass(
                                        radius: 16,
                                        child: Column(
                                          children: [
                                            _InfoRow(
                                              icon: FluxIcons.magic,
                                              label: 'App Version',
                                              value: '1.0.0',
                                            ),
                                            Divider(
                                              height: 1,
                                              color: FluxColors.lineOf(context),
                                            ),
                                            _InfoRow(
                                              icon: FluxIcons.robot,
                                              label: 'Inference Engine',
                                              value: 'llama.cpp · GGUF',
                                            ),
                                            Divider(
                                              height: 1,
                                              color: FluxColors.lineOf(context),
                                            ),
                                            _InfoRow(
                                              icon: FluxIcons.security,
                                              label: 'Privacy Mode',
                                              value: 'Full On-Device',
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
                      },
                    ),
                  ),

                  // ── 2. Progressive blur mask ───────────────────────────
                  ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, offset, _) {
                      final double scrollUp = math.max(0.0, offset);
                      final double blurProgress = (scrollUp / 24.0).clamp(
                        0.0,
                        1.0,
                      );
                      final double blurHeight = blurProgress <= 0
                          ? 0.0
                          : pinnedTitleTop + titleHeight + 14 * sy;

                      return Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: blurHeight,
                        child: IgnorePointer(
                          child: blurProgress <= 0
                              ? const SizedBox()
                              : RepaintBoundary(
                                  child: ClipRect(
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black,
                                              Colors.black,
                                              Colors.transparent,
                                            ],
                                            stops: [0.0, 0.65, 1.0],
                                          ).createShader(bounds),
                                      blendMode: BlendMode.dstIn,
                                      child: BackdropFilter(
                                        filter: ui.ImageFilter.blur(
                                          sigmaX: 10 * blurProgress,
                                          sigmaY: 10 * blurProgress,
                                        ),
                                        child: ColoredBox(
                                          color: FluxColors.canvasOf(context)
                                              .withValues(
                                                alpha: .86 * blurProgress,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),

                  // ── 3. BackControl — parallax 0.20× ───────────────────
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

                  // ── 4. "Settings" title — travels up, parallax 0.70× ──
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
                          final travelled = math.min(
                            titleTravelDistance,
                            offset,
                          );
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
                          'Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Spring Section wrapper ─────────────────────────────────────────────────────
// Wraps its child in a Transform.translate driven by the scroll offset,
// using the caller-supplied shift function for both overscroll directions.

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

// ── Model Row ──────────────────────────────────────────────────────────────────

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.state, required this.isActive});

  final ModelStorageState state;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final model = state.model;

    final statusLabel = isActive
        ? 'Active'
        : state.installed
        ? 'Installed'
        : state.resumable
        ? 'Partial'
        : 'Not installed';

    final statusColor = isActive
        ? const Color(0xFF3B82F6)
        : state.installed
        ? const Color(0xFF22C55E)
        : state.resumable
        ? const Color(0xFFF59E0B)
        : FluxColors.mutedOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          FluxIcon(
            icon: FluxIcons.chip,
            size: 18,
            color: isActive
                ? const Color(0xFF3B82F6)
                : FluxColors.mutedOf(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${model.parameterLabel} · ${model.sizeLabel}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              statusLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: FluxColors.mutedOf(context),
      ),
    );
  }
}

// ── Info Row ───────────────────────────────────────────────────────────────────

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          FluxIcon(icon: icon, size: 18, color: FluxColors.mutedOf(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: FluxColors.mutedOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Destructive Row ────────────────────────────────────────────────────────────

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
    final color = enabled
        ? (FluxColors.isDark(context)
              ? const Color(0xFFFF6B6B)
              : const Color(0xFFD32F2F))
        : FluxColors.mutedOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              FluxIcon(icon: icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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

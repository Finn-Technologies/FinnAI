import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/creations/creation_palette.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/safe_expression.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Renders a validated [MiniAppSpec] as real Flutter widgets.
///
/// Styling is not taken from the spec at all: colours, radii and text styles
/// come from the app theme plus the one accent the spec may choose. That is why
/// generated creations look like they belong to Finn, and why there is no path
/// by which a spec could inject arbitrary styling.
class MiniAppRenderer extends StatefulWidget {
  const MiniAppRenderer({super.key, required this.state, this.skipFirst = 0});

  final MiniAppState state;

  /// How many leading top-level nodes the host already shows itself (the
  /// emoji it draws beside the title), so they are not drawn twice.
  final int skipFirst;

  @override
  State<MiniAppRenderer> createState() => _MiniAppRendererState();
}

class _MiniAppRendererState extends State<MiniAppRenderer> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(MiniAppRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      oldWidget.state.removeListener(_onStateChanged);
      widget.state.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    // A reset rewrites the values underneath the inputs, and a direct action
    // (increment, append, set) can change a field-bound key just as well. Push
    // any value that no longer matches back into its controller, so a field
    // never shows text the state has moved on from. A field's own keystrokes
    // already match, so this is a no-op while the user is typing.
    for (final entry in _controllers.entries) {
      final text = SafeExpression.describeValue(
        widget.state.valueOf(entry.key),
      );
      if (entry.value.text != text) entry.value.text = text;
    }
    setState(() {});
  }

  TextEditingController _controllerFor(String key) => _controllers.putIfAbsent(
        key,
        () => TextEditingController(
          text: SafeExpression.describeValue(widget.state.valueOf(key)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final spec = widget.state.spec;
    final children = <Widget>[];
    for (final node in spec.nodes.skip(widget.skipFirst)) {
      children.add(_buildNode(context, node));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Color get _accent => CreationPalette.pastel(widget.state.spec.accent);

  /// The accent deepened enough to be read as text or a thin line on the page
  /// background, in both themes.
  Color _accentInk(BuildContext context) => FluxColors.isDark(context)
      ? Color.lerp(_accent, Colors.white, .1)!
      : Color.lerp(_accent, Colors.black, .55)!;

  Widget _buildNode(BuildContext context, MiniAppNode node) {
    final child = switch (node) {
      TextNode() => _text(context, node),
      ButtonNode() => _button(context, node),
      FieldNode() => _field(context, node),
      ToggleNode() => _toggle(context, node),
      SliderNode() => _slider(context, node),
      ListNode() => _list(context, node),
      ProgressNode() => _progress(context, node),
      ChoiceNode() => _choice(context, node),
      ImageNode() => _image(context, node),
      ContainerNode() => _container(context, node),
      SpacerNode() => SizedBox(height: node.size.toDouble()),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: child,
    );
  }

  Widget _text(BuildContext context, TextNode node) {
    final text = SafeExpression.interpolate(node.value, widget.state.values);
    final theme = Theme.of(context).textTheme;
    final style = switch (node.role) {
      MiniAppTextRole.title => theme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      MiniAppTextRole.body => theme.bodyLarge,
      MiniAppTextRole.caption => theme.labelMedium?.copyWith(
          color: FluxColors.mutedOf(context),
        ),
    };
    return Text(text, style: style);
  }

  Widget _button(BuildContext context, ButtonNode node) {
    // The thing the app is for (add, count, set) is the dark button; undoing
    // it (reset) is quiet. The accent colours the screen around them.
    final quiet = node.action is ResetAction;
    final fill =
        quiet ? FluxColors.cardOf(context) : FluxColors.actionOf(context);
    final ink =
        quiet ? FluxColors.inkOf(context) : FluxColors.actionInkOf(context);
    void tap() {
      HapticFeedback.selectionClick();
      widget.state.dispatch(node.action);
    }

    return Semantics(
      button: true,
      label: node.label,
      onTap: tap,
      excludeSemantics: true,
      child: FluxPressScale(
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(FluxRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            onTap: tap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    node.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, FieldNode node) => TextField(
        controller: _controllerFor(node.key),
        maxLines: 1,
        textInputAction: TextInputAction.done,
        onChanged: (text) => widget.state.setValue(node.key, text),
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: node.hint.isEmpty ? null : node.hint,
          hintStyle: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: FluxColors.mutedOf(context)),
          filled: true,
          fillColor: FluxColors.cardOf(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.md),
            borderSide: BorderSide(color: _accentInk(context), width: 1.5),
          ),
        ),
      );

  Widget _toggle(BuildContext context, ToggleNode node) {
    final value = widget.state.valueOf(node.key) == true;
    return Row(
      children: [
        Expanded(
          child: Text(
            node.label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: _accent,
          activeThumbColor: CreationPalette.onPastel,
          onChanged: (next) {
            HapticFeedback.selectionClick();
            widget.state.setValue(node.key, next);
          },
        ),
      ],
    );
  }

  Widget _slider(BuildContext context, SliderNode node) {
    final current = _asNumber(widget.state.valueOf(node.key))
        .clamp(node.min.toDouble(), node.max.toDouble());
    return Row(
      children: [
        Expanded(
          child: Slider(
            activeColor: _accentInk(context),
            inactiveColor: FluxColors.surfaceOf(context),
            value: current,
            min: node.min.toDouble(),
            max: node.max.toDouble(),
            divisions: (node.max - node.min).clamp(1, 100),
            label: current.round().toString(),
            onChanged: (next) => widget.state.setValue(node.key, next.round()),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            current.round().toString(),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  /// Display cap for a bound list, so a runaway append loop cannot build an
  /// unbounded widget tree.
  static const int _maxListItems = 50;

  Widget _list(BuildContext context, ListNode node) {
    final raw = widget.state.valueOf(node.bind);
    final items = raw is List ? raw : const <Object?>[];
    if (items.isEmpty) {
      final empty = node.empty.trim();
      if (empty.isEmpty) return const SizedBox.shrink();
      return Text(
        empty,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: FluxColors.mutedOf(context),
            ),
      );
    }
    final shown = items.take(_maxListItems).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: FluxColors.cardOf(context),
                borderRadius: BorderRadius.circular(FluxRadius.md),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      SafeExpression.describeValue(item),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _progress(BuildContext context, ProgressNode node) {
    final value = _asNumber(widget.state.valueOf(node.bind));
    final fraction = node.max <= 0 ? 0.0 : (value / node.max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(FluxRadius.pill),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 14,
        backgroundColor: FluxColors.cardOf(context),
        valueColor: AlwaysStoppedAnimation<Color>(_accent),
      ),
    );
  }

  Widget _choice(BuildContext context, ChoiceNode node) {
    final selected = widget.state.valueOf(node.key);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final option in node.options)
          Material(
            color: option == selected ? _accent : FluxColors.cardOf(context),
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(FluxRadius.pill),
              onTap: () => widget.state.setValue(node.key, option),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: option == selected
                            ? CreationPalette.onPastel
                            : FluxColors.inkOf(context),
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _image(BuildContext context, ImageNode node) {
    if (node.url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(FluxRadius.md),
        child: Image.network(
          node.url,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(
            height: 120,
            color: FluxColors.surfaceOf(context),
            child: const Center(
              child: FluxIcon(icon: FluxIcons.brokenImage, size: 26),
            ),
          ),
        ),
      );
    }
    if (node.emoji.isNotEmpty) {
      return Text(node.emoji, style: const TextStyle(fontSize: 42));
    }
    return const SizedBox.shrink();
  }

  Widget _container(BuildContext context, ContainerNode node) {
    final children = [
      for (final child in node.children) _buildNode(context, child),
    ];
    if (node.axis == MiniAppAxis.horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final child in children) Flexible(child: child),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

double _asNumber(Object? value) => switch (value) {
      final int number => number.toDouble(),
      final double number => number,
      final bool flag => flag ? 1 : 0,
      final String text => double.tryParse(text.trim()) ?? 0,
      _ => 0,
    };

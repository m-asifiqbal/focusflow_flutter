/// ============================================================
/// APPEARANCE CONTROLS — accent swatches, text size, app icon (screen 32)
/// ============================================================
///
/// * [AccentPicker]   — six round swatches; the selected one gets a
///   primary ring with a surface gap.
/// * [TextSizeCard]   — small A · slider · large A over a live preview
///   sentence. While dragging only the preview re-scales; the setting is
///   saved (and the whole app re-scales) when the gesture ends.
/// * [AppIconPicker]  — Default / Mint / Night / Mono. Alternate launcher
///   icons need native resources this build doesn't ship yet, so only
///   Default is selectable and the others say "coming soon" honestly.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_text_scaler.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class AccentPicker extends StatelessWidget {
  const AccentPicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final AccentColor selected;
  final ValueChanged<AccentColor> onSelected;

  static const double _swatch = 40;
  static const double _ring = 2.5;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const outer = _swatch + 2 * (_ring + _gap);
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: AppSpacing.sm,
        children: [
          for (final a in AccentColor.values)
            Semantics(
              button: true,
              selected: a == selected,
              label: tr('{label} accent', {'label': a.label}),
              excludeSemantics: true,
              child: FFPressable(
                onTap: () => onSelected(a),
                child: SizedBox.square(
                  dimension: outer,
                  child: Container(
                    padding: const EdgeInsets.all(_gap),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: a == selected ? ff.primary : Colors.transparent,
                        width: _ring,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ff.isDark ? a.primaryDark : a.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TextSizeCard extends StatefulWidget {
  const TextSizeCard({
    required this.index,
    required this.scales,
    required this.onChanged,
    super.key,
  });

  /// Selected (persisted) stop.
  final int index;

  /// Text-scale multiplier of each stop.
  final List<double> scales;

  /// Called once per gesture, when the drag / tap / key press ends.
  final ValueChanged<int> onChanged;

  @override
  State<TextSizeCard> createState() => _TextSizeCardState();
}

class _TextSizeCardState extends State<TextSizeCard> {
  /// Stop under the thumb while dragging (null when idle).
  int? _drag;

  int get _shown => _drag ?? widget.index;

  /// "Default", "Large"… for a scale (stops are 0.85 … 1.3).
  static String nameOf(double scale) {
    if ((scale - 1).abs() < 0.001) return tr('Default');
    final steps = ((scale - 1).abs() / 0.05).round();
    if (scale < 1) {
      return switch ((steps - 1).clamp(0, 2)) {
        0 => tr('Small'),
        1 => tr('Smaller'),
        _ => tr('Smallest'),
      };
    }
    return switch (((steps ~/ 2) - 1).clamp(0, 2)) {
      0 => tr('Large'),
      1 => tr('Larger'),
      _ => tr('Largest'),
    };
  }

  static String percentOf(double scale) => '${(scale * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final stops = widget.scales.length;
    final small = context.text.cardTitle.copyWith(fontSize: 15);
    final preview = Text(
      tr('Preview: The quick brown fox plans tomorrow\'s tasks.'),
      style: context.text.body.copyWith(height: 1.5),
    );
    return FFCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live size indicator: follows the thumb while dragging.
          Row(
            children: [
              Flexible(
                child: Text(
                  tr('Text size'),
                  style: context.text.rowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: AnimatedSwitcher(
                  duration: context.motion(AppMotion.fast),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1).animate(a),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(_shown),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: ff.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '${nameOf(widget.scales[_shown])} · '
                      '${percentOf(widget.scales[_shown])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.buttonSmall.copyWith(
                        color: ff.primaryStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ExcludeSemantics(child: Text('A', style: small)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 7,
                    activeTrackColor: ff.primaryGradient.colors.first,
                    inactiveTrackColor: ff.surfaceMuted,
                    thumbColor: ff.isDark ? ff.ink : ff.surface,
                    overlayColor: ff.primary.withValues(alpha: 0.12),
                    thumbShape: _ThumbShape(
                      fill: ff.isDark ? ff.ink : ff.surface,
                      shadow: ff.ink.withValues(alpha: 0.22),
                    ),
                    // A tick for every size stop; the bubble shows the size
                    // under the thumb while dragging.
                    activeTickMarkColor: ff.onPrimary.withValues(alpha: 0.9),
                    inactiveTickMarkColor: ff.inkFaint,
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 2.5,
                    ),
                    showValueIndicator: ShowValueIndicator.onDrag,
                    valueIndicatorColor: ff.primary,
                    valueIndicatorTextStyle: context.text.buttonSmall.copyWith(
                      color: ff.onPrimary,
                    ),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: _shown.toDouble(),
                    max: (stops - 1).toDouble(),
                    divisions: stops - 1,
                    label: percentOf(widget.scales[_shown]),
                    semanticFormatterCallback: (v) =>
                        tr('Text size {name}, {percent}', {
                          'name': nameOf(widget.scales[v.round()]),
                          'percent': percentOf(widget.scales[v.round()]),
                        }),
                    // Drag ticks only move the local preview; the setting
                    // (one JSON write + an app-wide relayout) is saved
                    // once, when the gesture ends.
                    onChanged: (v) => setState(() => _drag = v.round()),
                    onChangeEnd: (v) {
                      widget.onChanged(v.round());
                      setState(() => _drag = null);
                    },
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text('A', style: small.copyWith(fontSize: 26)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_drag == null || _drag == widget.index)
            preview
          else
            // The app already applies the saved stop; scale the preview
            // by the ratio to show the stop under the thumb.
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: AppTextScaler.compose(
                  MediaQuery.textScalerOf(context),
                  widget.scales[_drag!] / widget.scales[widget.index],
                ),
              ),
              child: preview,
            ),
        ],
      ),
    );
  }
}

/// White 22 pt thumb with a soft blurred shadow (mockup 32).
class _ThumbShape extends SliderComponentShape {
  const _ThumbShape({required this.fill, required this.shadow});

  final Color fill;
  final Color shadow;

  static const double _radius = 11;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas
      ..drawCircle(
        center.translate(0, 1.5),
        _radius,
        Paint()
          ..color = shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawCircle(center, _radius, Paint()..color = fill)
      ..drawCircle(
        center,
        _radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = shadow.withValues(alpha: 0.12),
      );
  }
}

/// One launcher icon variant.
class _IconVariant {
  const _IconVariant(this.id, this.label, this.bg, this.fg, {this.border});

  final String id;
  final String label;

  /// Null = the primary gradient.
  final Color? bg;
  final Color fg;
  final Color? border;
}

class AppIconPicker extends StatelessWidget {
  const AppIconPicker({required this.onUnavailable, super.key});

  /// Called when a variant this build can't apply is tapped.
  final ValueChanged<String> onUnavailable;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final variants = [
      _IconVariant('default', tr('Default'), null, AppPalette.white),
      _IconVariant(
        'mint',
        tr('Mint'),
        AppPalette.emerald100,
        AppPalette.emerald600,
      ),
      _IconVariant(
        'night',
        tr('Night'),
        AppPalette.emerald950,
        AppPalette.emerald400,
      ),
      _IconVariant(
        'mono',
        tr('Mono'),
        AppPalette.white,
        AppPalette.emerald950,
        border: AppPalette.slate200,
      ),
    ];
    // Only the bundled icon can be applied in this build.
    const current = 'default';
    return FFCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          for (final v in variants)
            Expanded(
              child: Semantics(
                button: true,
                selected: v.id == current,
                label: v.id == current
                    ? tr('{label} app icon', {'label': v.label})
                    : tr('{label} app icon, coming soon', {'label': v.label}),
                excludeSemantics: true,
                child: FFPressable(
                  onTap: v.id == current ? null : () => onUnavailable(v.label),
                  child: Column(
                    children: [
                      _iconTile(context, v, selected: v.id == current),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        v.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall.copyWith(
                          color: ff.inkMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconTile(
    BuildContext context,
    _IconVariant v, {
    required bool selected,
  }) {
    final ff = context.ff;
    final radius = BorderRadius.circular(16);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: selected ? ff.primary : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: v.bg,
          gradient: v.bg == null ? ff.primaryGradient : null,
          borderRadius: radius,
          border: v.border == null ? null : Border.all(color: v.border!),
        ),
        child: Icon(FontAwesomeIcons.bolt, size: 22, color: v.fg),
      ),
    );
  }
}

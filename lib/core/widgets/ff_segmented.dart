/// ============================================================
/// FF SEGMENTED — rounded segmented control with a sliding thumb
/// ============================================================
///
/// Light: soft primary track, white thumb with card shadow, primary-strong
/// active label (calendar "Week / Month / Agenda"). Dark: muted track +
/// primary thumb. [vault]: glass track + emerald-400 thumb (generator
/// "Password / Passphrase / PIN"). The thumb animates (instant under reduce
/// motion) and follows RTL.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

/// One segment of [FFSegmented].
@immutable
class FFSegment<T> {
  const FFSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class FFSegmented<T> extends StatelessWidget {
  const FFSegmented({
    required this.segments,
    required this.value,
    required this.onChanged,
    this.vault = false,
    this.height = 46,
    super.key,
  });

  final List<FFSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool vault;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    final Color track;
    final Color thumb;
    final Color activeText;
    final Color idleText;
    Border? border;
    List<BoxShadow>? thumbShadow;
    if (vault) {
      track = ff.vaultSurface;
      border = Border.all(color: ff.vaultBorder);
      thumb = ff.vaultAccent;
      activeText = ff.vaultOnAccent;
      idleText = ff.vaultInkMuted;
    } else if (ff.isDark) {
      track = ff.surfaceMuted;
      border = Border.all(color: ff.surfaceBorder);
      thumb = ff.primary;
      activeText = ff.onPrimary;
      idleText = ff.inkMuted;
    } else {
      track = ff.primarySoft.withValues(alpha: 0.6);
      thumb = ff.surface;
      thumbShadow = ff.cardShadow;
      activeText = ff.primaryStrong;
      idleText = ff.primary.withValues(alpha: 0.55);
    }
    final x = n <= 1 || index < 0 ? 0.0 : -1 + 2 * index / (n - 1);
    final duration = context.motion(AppMotion.normal);
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: border,
      ),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: AlignmentDirectional(x, 0),
                duration: duration,
                curve: AppMotion.curve,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: thumb,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      boxShadow: thumbShadow,
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    inMutuallyExclusiveGroup: true,
                    label: segments[i].label,
                    excludeSemantics: true,
                    child: FFPressable(
                      onTap: () => onChanged(segments[i].value),
                      scale: 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: height - AppSpacing.sm,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: _Label(
                              segment: segments[i],
                              color: i == index ? activeText : idleText,
                              duration: duration,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Label<T> extends StatelessWidget {
  const _Label({
    required this.segment,
    required this.color,
    required this.duration,
  });

  final FFSegment<T> segment;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final style = context.text.buttonSmall.copyWith(fontSize: 15, color: color);
    return AnimatedDefaultTextStyle(
      duration: duration,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (segment.icon != null) ...[
            Icon(segment.icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

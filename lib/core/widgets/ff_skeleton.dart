/// ============================================================
/// FF SKELETON — shimmer placeholders shaped like real rows and cards
/// ============================================================
///
/// [FFSkeleton] is one grey block; [FFShimmer] sweeps a highlight across
/// its child (disabled under reduce motion). [FFSkeletonCard] mimics a note
/// card, [FFSkeletonRow] a list row; [FFSkeletonList] stacks several under a
/// single shimmer and announces "Loading" to screen readers.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_card.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';

class FFSkeleton extends StatelessWidget {
  const FFSkeleton({
    this.width,
    this.height = 14,
    this.radius = AppSpacing.sm,
    this.widthFactor,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  /// Fraction of the available width (wins over [width]).
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widthFactor == null ? width : null,
      height: height,
      decoration: BoxDecoration(
        color: context.ff.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (widthFactor == null) return box;
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: box,
    );
  }
}

/// Sweeps a soft highlight over [child]'s opaque pixels.
class FFShimmer extends StatefulWidget {
  const FFShimmer({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<FFShimmer> createState() => _FFShimmerState();
}

class _FFShimmerState extends State<FFShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FFShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.enabled && !context.reduceMotion;
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || context.reduceMotion) return widget.child;
    final ff = context.ff;
    final base = ff.surfaceMuted;
    final highlight = Color.alphaBlend(
      ff.isDark
          ? ff.ink.withValues(alpha: 0.08)
          : ff.surface.withValues(alpha: 0.8),
      base,
    );
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient((_c.value * 2 - 1) * bounds.width),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Placeholder shaped like a note/task card: tag pill, title, body lines.
class FFSkeletonCard extends StatelessWidget {
  const FFSkeletonCard({
    this.lines = 2,
    this.showTag = true,
    this.shimmer = true,
    super.key,
  });

  final int lines;
  final bool showTag;

  /// Wrap in its own [FFShimmer] (off when inside [FFSkeletonList]).
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final card = FFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTag) ...[
            const FFSkeleton(width: 56, height: 16, radius: 6),
            const SizedBox(height: AppSpacing.md),
          ],
          const FFSkeleton(widthFactor: 0.75, height: 16),
          for (var i = 0; i < lines; i++) ...[
            const SizedBox(height: 10),
            FFSkeleton(widthFactor: i == lines - 1 ? 0.5 : 0.95, height: 12),
          ],
        ],
      ),
    );
    return ExcludeSemantics(child: shimmer ? FFShimmer(child: card) : card);
  }
}

/// Placeholder shaped like an [FFListRow] with a leading tile.
class FFSkeletonRow extends StatelessWidget {
  const FFSkeletonRow({
    this.leading = true,
    this.trailing = false,
    this.shimmer = true,
    super.key,
  });

  final bool leading;
  final bool trailing;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (leading) ...[
              const FFSkeleton(width: 38, height: 38, radius: AppRadii.tile),
              const SizedBox(width: 14),
            ],
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FFSkeleton(widthFactor: 0.6, height: 14),
                  SizedBox(height: AppSpacing.sm),
                  FFSkeleton(widthFactor: 0.4, height: 11),
                ],
              ),
            ),
            if (trailing) ...[
              const SizedBox(width: AppSpacing.md),
              const FFSkeleton(width: 40, height: 22, radius: AppRadii.pill),
            ],
          ],
        ),
      ),
    );
    return ExcludeSemantics(child: shimmer ? FFShimmer(child: row) : row);
  }
}

enum FFSkeletonKind { card, row }

/// [count] skeleton cards/rows under one shimmer, 12 pt apart.
class FFSkeletonList extends StatelessWidget {
  const FFSkeletonList({
    this.count = 4,
    this.kind = FFSkeletonKind.card,
    this.padding = EdgeInsetsDirectional.zero,
    super.key,
  });

  final int count;
  final FFSkeletonKind kind;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < count; i++) ...[
        if (i > 0 && kind == FFSkeletonKind.card)
          const SizedBox(height: AppSpacing.cardGap),
        if (kind == FFSkeletonKind.card)
          FFSkeletonCard(shimmer: false, lines: i.isEven ? 2 : 1)
        else
          const FFSkeletonRow(shimmer: false),
      ],
    ];
    Widget list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
    );
    if (kind == FFSkeletonKind.row) {
      list = FFCard(padding: EdgeInsetsDirectional.zero, child: list);
    }
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: Padding(
        padding: padding,
        child: FFShimmer(child: list),
      ),
    );
  }
}

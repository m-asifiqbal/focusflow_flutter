/// ============================================================
/// LIBRARY MODULE CARD — one space on the Library hub (screen 05)
/// ============================================================
///
/// What: white 22-radius card with the module's solid 42 pt icon tile, a
/// faint → (or the vault's lock), the big count + module name, a module-ink
/// highlight line and a muted line, over a soft module-colour circle
/// peeking from the bottom-end corner. [lines] null = counts still
/// loading (skeleton bars). Why: the Vault card reuses it spanning both
/// columns; it only ever shows counts and "Locked" / "Unlocked".
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/library_format.dart';

class LibraryModuleCard extends StatelessWidget {
  const LibraryModuleCard({
    required this.type,
    required this.lines,
    required this.onTap,
    this.showCount = true,
    this.locked = false,
    super.key,
  });

  final ItemType type;

  /// Null while the counts load.
  final LibraryCardLines? lines;
  final VoidCallback onTap;

  /// Settings › Library "Show counts"; off hides the big number.
  final bool showCount;

  /// Vault card: a lock replaces the arrow while the vault is locked.
  final bool locked;

  /// Inner padding (16 pt in the mockup).
  static const double padding = AppSpacing.lg;

  /// Tile → count row gap (measured on design/05).
  static const double _tileGap = 17;

  /// Highlight / meta lines: 12 pt on an 18 pt line (design/05).
  static const double _lineSize = 12;
  static const double _lineHeight = 1.5;

  /// Diameter / overhang of the decorative circle (measured on design/05).
  static const double _circle = 96;
  static const double _circleEnd = -26;
  static const double _circleBottom = -22;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = type.style;
    final dark = ff.isDark;
    final l = lines;
    final semantic = l == null
        ? tr('{type}, loading', {'type': type.plural})
        : [
            showCount ? '${l.count} ${type.plural}' : type.plural,
            l.highlight,
            l.meta,
          ].join('. ');
    final card = FFCard(
      padding: EdgeInsetsDirectional.zero,
      onTap: onTap,
      semanticLabel: semantic,
      child: Stack(
        children: [
          PositionedDirectional(
            end: _circleEnd,
            bottom: _circleBottom,
            child: Container(
              width: _circle,
              height: _circle,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? style.colors.softFor(Brightness.dark)
                    : style.soft.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FFIconTile(
                      icon: style.icon,
                      colors: style.colors,
                      size: 42,
                    ),
                    const Spacer(),
                    _Corner(type: type, locked: locked),
                  ],
                ),
                const SizedBox(height: _tileGap),
                _CountLine(type: type, lines: l, showCount: showCount),
                const SizedBox(height: 7),
                if (l == null)
                  ..._skeleton()
                else ...[
                  _line(
                    context,
                    l.highlight,
                    context.text.body.copyWith(
                      fontSize: _lineSize,
                      height: _lineHeight,
                      fontWeight: FontWeight.w700,
                      color: style.colors.inkFor(ff.brightness),
                    ),
                  ),
                  _line(
                    context,
                    l.meta,
                    context.text.body.copyWith(
                      fontSize: _lineSize,
                      height: _lineHeight,
                      color: ff.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    // The module's list grows out of its card, as an item's page does out
    // of its row. Not the vault: that page is always dark and would grow
    // out of a light card.
    return type == ItemType.vault ? card : FFOpenOriginTracker(child: card);
  }

  Widget _line(BuildContext context, String text, TextStyle style) => Text(
    text.isEmpty ? ' ' : text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style,
  );

  List<Widget> _skeleton() => const [
    Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: 2.5),
      child: FFSkeleton(width: 78, height: 13),
    ),
    Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: 2.5),
      child: FFSkeleton(width: 96, height: 13),
    ),
  ];
}

/// Faint arrow (→, mirrored in RTL) or the vault's amber lock.
class _Corner extends StatelessWidget {
  const _Corner({required this.type, required this.locked});

  final ItemType type;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    if (locked) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: 2),
        child: Icon(FontAwesomeIcons.lock, size: 13, color: type.style.solid),
      );
    }
    if (type == ItemType.vault) return const SizedBox.shrink();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: EdgeInsetsDirectional.zero,
      child: Icon(
        rtl ? FontAwesomeIcons.arrowLeft : FontAwesomeIcons.arrowRight,
        size: 12,
        color: ff.inkFaint.withValues(alpha: 0.4),
      ),
    );
  }
}

/// "48 Notes": big Lexend count + module name on one baseline; wraps
/// (instead of overflowing) at large text scales on narrow cards.
class _CountLine extends StatelessWidget {
  const _CountLine({
    required this.type,
    required this.lines,
    required this.showCount,
  });

  final ItemType type;
  final LibraryCardLines? lines;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final big = context.text.bigStat;
    final name = context.text.cardTitle.copyWith(fontSize: 14.5);
    final l = lines;
    if (l == null && showCount) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const FFSkeleton(width: 34, height: 24),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(type.plural, maxLines: 1, style: name)),
        ],
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          if (showCount) ...[
            TextSpan(text: '${l!.count}', style: big),
            // ~10 pt gap between the count and the name (design/05).
            TextSpan(text: ' ', style: name.copyWith(letterSpacing: 3)),
          ],
          TextSpan(text: type.plural, style: name),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

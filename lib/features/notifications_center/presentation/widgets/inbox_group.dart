/// ============================================================
/// INBOX GROUP — one day: a pinned "TODAY ··· Clear all" bar + a card of rows
/// ============================================================
///
/// What: one section of screen 27 as a sliver. The uppercase day label and
/// its "Clear all" button stay pinned to the top of the list while the
/// day's rows scroll beneath; when the next day arrives its bar pushes the
/// previous one away, so the label always names the day in view. The rows
/// sit in a rounded card separated by inset hairlines; each swipes away
/// (end → start) to dismiss, and screen readers get a "Dismiss" action.
/// Why: [SliverMainAxisGroup] scopes a pinned header to its own group, which
/// is exactly the "sticky section header" behaviour.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';

class InboxGroup extends StatelessWidget {
  const InboxGroup({
    required this.label,
    required this.entries,
    required this.rowBuilder,
    required this.onDismiss,
    required this.onClear,
    super.key,
  });

  /// Pinned bar height (a 44-pt tap target plus breathing room).
  static const double headerExtent = AppSizes.minTap + AppSpacing.sm;

  /// "Today", "Yesterday", "Monday", "Oct 12".
  final String label;
  final List<InboxEntry> entries;
  final Widget Function(InboxEntry entry) rowBuilder;
  final ValueChanged<InboxEntry> onDismiss;

  /// "Clear all" of this day's [entries].
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _DayBarDelegate(label: label, onClear: onClear),
        ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.grouped,
            0,
            AppSpacing.grouped,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: FFCard(
              padding: EdgeInsetsDirectional.zero,
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.dividerInset,
                        ),
                        child: Container(height: 1, color: ff.divider),
                      ),
                    _swipe(context, entries[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _swipe(BuildContext context, InboxEntry e) {
    final ff = context.ff;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: tr('Dismiss')): () => onDismiss(e),
      },
      child: Dismissible(
        key: ValueKey('inbox-${e.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss(e),
        background: const SizedBox.shrink(),
        secondaryBackground: Container(
          color: ff.surfaceMuted,
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xxl),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FontAwesomeIcons.solidBellSlash,
                size: AppSizes.tileGlyph,
                color: ff.inkMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                tr('Dismiss'),
                style: context.text.meta.copyWith(color: ff.inkMuted),
              ),
            ],
          ),
        ),
        child: rowBuilder(e),
      ),
    );
  }
}

class _DayBarDelegate extends SliverPersistentHeaderDelegate {
  const _DayBarDelegate({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  double get minExtent => InboxGroup.headerExtent;

  @override
  double get maxExtent => InboxGroup.headerExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final ff = context.ff;
    return DecoratedBox(
      // Opaque, so rows scrolling underneath never show through the label.
      decoration: BoxDecoration(
        color: ff.canvas,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? ff.divider : const Color(0x00000000),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.grouped + AppSpacing.xs,
          end: AppSpacing.grouped,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.sectionLabel,
                ),
              ),
            ),
            FFTextButton(
              label: tr('Clear all'),
              semanticLabel: tr('Clear all notifications from {label}', {
                'label': label,
              }),
              onPressed: onClear,
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
              style: context.text.buttonSmall.copyWith(
                fontSize: 14,
                color: ff.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayBarDelegate old) =>
      old.label != label || old.onClear != onClear;
}

/// ============================================================
/// INBOX GROUP — "TODAY" / "EARLIER" label + a card of rows
/// ============================================================
///
/// What: one section of screen 27: an uppercase label and a rounded card
/// whose rows are separated by inset hairlines. Each row swipes away
/// (end → start) to dismiss; screen readers get a "Dismiss" action.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    super.key,
  });

  final String label;
  final List<InboxEntry> entries;
  final Widget Function(InboxEntry entry) rowBuilder;
  final ValueChanged<InboxEntry> onDismiss;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.xs,
            bottom: AppSpacing.md,
          ),
          child: Semantics(
            header: true,
            child: Text(label.toUpperCase(), style: context.text.sectionLabel),
          ),
        ),
        FFCard(
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
      ],
    );
  }

  Widget _swipe(BuildContext context, InboxEntry e) {
    final ff = context.ff;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Dismiss'): () => onDismiss(e),
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
                'Dismiss',
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

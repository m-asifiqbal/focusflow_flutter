/// ============================================================
/// INBOX ROW — one notification in the Notification center (screen 27)
/// ============================================================
///
/// What: unread dot · module tile · title + time · body · inline action
/// pills. Unread rows get the soft accent tint (emerald-50 in the mockup).
/// Tapping the row opens the item; the pills run [onAction].
/// Why: purely presentational — the screen wires the flows.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/notifications_center/presentation/widgets/inbox_action_button.dart';
import 'package:focusflow/features/notifications_center/presentation/widgets/inbox_kind_style.dart';

class InboxRow extends StatelessWidget {
  const InboxRow({
    required this.entry,
    required this.timeLabel,
    required this.timeSemantic,
    required this.actionLabel,
    required this.onTap,
    required this.onAction,
    super.key,
  });

  /// Size of the unread dot.
  static const double dot = 8;

  /// Module tile size (40 pt in design/27).
  static const double tile = 40;

  /// Title / body sizes measured on design/27 (no text token is this size).
  static const double titleSize = 16;
  static const double bodySize = 14.5;
  static const double _bodyHeight = 1.4;

  final InboxEntry entry;

  /// "now", "8:00", "Yesterday" …
  final String timeLabel;

  /// Spoken time ("8:00 AM").
  final String timeSemantic;

  /// Label of an action key ("Snooze 10m").
  final String Function(String action) actionLabel;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final colors = entry.kind.colors;
    const outset = (AppSizes.minTap - InboxActionButton.height) / 2;
    final unread = !entry.isRead;
    final actions = entry.actions;
    return Container(
      color: unread
          ? Color.alphaBlend(ff.primarySoft.withValues(alpha: 0.35), ff.surface)
          : null,
      child: Semantics(
        container: true,
        child: FFPressable(
          scale: 1,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              actions.isEmpty ? AppSpacing.lg : AppSpacing.lg - outset,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: dot,
                  height: tile,
                  child: unread
                      ? Center(
                          child: Container(
                            width: dot,
                            height: dot,
                            decoration: BoxDecoration(
                              color: ff.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                FFIconTile.soft(
                  icon: entry.kind.icon,
                  colors: colors,
                  size: tile,
                  radius: AppRadii.tile,
                  semanticLabel: tr('{label} notification', {
                    'label': entry.kind.label,
                  }),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _content(context, ff)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, FFColors ff) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                label: entry.isRead ? null : tr('Unread'),
                child: Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.cardTitle.copyWith(fontSize: titleSize),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1),
              child: Semantics(
                label: timeSemantic,
                excludeSemantics: true,
                child: Text(
                  timeLabel,
                  maxLines: 1,
                  style: text.meta.copyWith(
                    fontWeight: FontWeight.w500,
                    color: ff.inkFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (entry.body.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            entry.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall.copyWith(
              fontSize: bodySize,
              height: _bodyHeight,
            ),
          ),
        ],
        if (entry.actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < entry.actions.length; i++)
                InboxActionButton(
                  label: actionLabel(entry.actions[i]),
                  filled: i == 0,
                  onPressed: () => onAction(entry.actions[i]),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

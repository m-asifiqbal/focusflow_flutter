/// ============================================================
/// CALENDAR AGENDA ROW — time column + module-bordered card (mockup 26)
/// ============================================================
///
/// What: "09:00" / "All day" on the start side, then a rounded card whose
/// start edge is a module-colour crescent, the title and the coloured
/// type line ("Task · High", "Habit · done ✓"). Done rows are dimmed.
/// Tap opens the item; in Week view task rows are long-press draggable
/// onto another day cell (reschedule).
/// Why: the one row shape of the Month, Week and Agenda views.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/calendar/presentation/calendar_tokens.dart';

class CalendarAgendaRow extends StatelessWidget {
  const CalendarAgendaRow({
    required this.entry,
    required this.use24h,
    required this.onTap,
    this.draggable = false,
    super.key,
  });

  final CalendarEntry entry;
  final bool use24h;
  final VoidCallback onTap;

  /// Week view: task rows can be dragged onto a day cell.
  final bool draggable;

  /// "09:00" (24 h) / "9:00 AM" (wraps under the time at large text).
  static String timeLabel(CalendarEntry e, {required bool use24h}) {
    final t = e.time;
    if (t == null) return tr('All day');
    return DateFormats.of(use24h ? 'HH:mm' : 'h:mm a').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final time = timeLabel(entry, use24h: use24h);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: CalendarDimens.timeColumn,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              top: CalendarDimens.cardPaddingV + AppSpacing.xxs,
            ),
            child: Text(
              time,
              maxLines: 2,
              textAlign: TextAlign.end,
              style: context.text.meta.copyWith(
                fontSize: CalendarDimens.time,
                color: context.ff.inkMuted.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
        const SizedBox(width: CalendarDimens.timeGap),
        Expanded(child: _card(context)),
      ],
    );
    final hint = draggable && entry.canReschedule
        ? tr('Long press and drag to another day to reschedule')
        : null;
    final semantic = Semantics(
      button: true,
      label: '$time, ${entry.title}, ${entry.meta}',
      hint: hint,
      excludeSemantics: true,
      child: FFPressable(onTap: onTap, child: row),
    );
    if (!draggable || !entry.canReschedule) return semantic;
    return LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<CalendarEntry>(
        data: entry,
        hapticFeedbackOnStart: true,
        feedback: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: constraints.maxWidth - CalendarDimens.timeColumn,
            child: Opacity(opacity: 0.92, child: _card(context)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: row),
        child: semantic,
      ),
    );
  }

  Widget _card(BuildContext context) {
    final ff = context.ff;
    final module = entry.type.style.colors;
    final brightness = Theme.of(context).brightness;
    final metaColor = module.inkFor(brightness);
    const radius = BorderRadius.all(Radius.circular(CalendarDimens.cardRadius));
    // Dark surfaces are translucent; flatten them over the canvas so the
    // module colour only shows as the start-edge crescent.
    final surface = Color.alphaBlend(ff.surface, ff.canvas);
    // The module colour peeks out at the start edge as a crescent: a
    // coloured rounded block sits behind the card, offset by the stripe.
    return Stack(
      children: [
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: CalendarDimens.cardRadius * 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: module.solid,
              borderRadius: radius,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: CalendarDimens.cardStripe,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: radius,
              border: ff.isDark ? Border.all(color: ff.surfaceBorder) : null,
              boxShadow: ff.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: CalendarDimens.cardPaddingH,
                vertical: CalendarDimens.cardPaddingV,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.cardTitle.copyWith(
                      fontSize: CalendarDimens.cardTitle,
                      color: entry.done ? ff.inkMuted : ff.ink,
                    ),
                  ),
                  const SizedBox(height: CalendarDimens.cardMetaGap),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.meta.copyWith(
                            fontSize: CalendarDimens.cardMeta,
                            color: metaColor,
                          ),
                        ),
                      ),
                      if (entry.done) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          FontAwesomeIcons.check,
                          size: CalendarDimens.metaCheck,
                          color: metaColor,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

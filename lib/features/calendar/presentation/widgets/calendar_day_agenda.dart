/// ============================================================
/// CALENDAR DAY AGENDA — "Tuesday, June 13 ……… 4 items" + rows (screen 26)
/// ============================================================
///
/// What: one day's title and item count over its ordered agenda rows,
/// live over [calendarAgendaProvider]. Empty day: "Nothing planned · Add"
/// (Quick Add on that day). Loading: skeleton rows. Error: banner + Retry.
/// [dense] is the smaller per-day group of the Agenda (7-day) view.
/// Why: the Month, Week and Agenda views all list days the same way.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/calendar/presentation/calendar_flows.dart';
import 'package:focusflow/features/calendar/presentation/calendar_tokens.dart';
import 'package:focusflow/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_agenda_row.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:intl/intl.dart' show DateFormat;

class CalendarDayAgenda extends ConsumerWidget {
  const CalendarDayAgenda({
    required this.day,
    this.draggable = false,
    this.dense = false,
    super.key,
  });

  /// Local midnight.
  final DateTime day;

  /// Week view: task rows can be dragged onto the week cells.
  final bool draggable;

  /// Agenda view: smaller title, tighter spacing.
  final bool dense;

  /// "4 items" / "1 item".
  static String countLabel(int n) => n == 1 ? '1 item' : '$n items';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(calendarAgendaProvider(day));
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final entries = agenda.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(day: day, count: entries?.length, dense: dense),
        SizedBox(height: dense ? AppSpacing.md : CalendarDimens.titleGap),
        if (agenda.hasError && entries == null)
          FFErrorBanner(
            message: "Couldn't load this day.",
            onRetry: () => retryCalendarAgenda(ref, day),
          )
        else if (entries == null)
          const _AgendaSkeleton()
        else if (entries.isEmpty)
          CalendarEmptyDay(
            day: day,
            onAdd: () => addOnCalendarDay(context, day),
          )
        else
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: CalendarDimens.cardGap),
            CalendarAgendaRow(
              key: ValueKey(entries[i].ref),
              entry: entries[i],
              use24h: use24h,
              draggable: draggable,
              onTap: () => openCalendarEntry(context, entries[i]),
            ),
          ],
      ],
    );
  }
}

/// "Tuesday, June 13" + "4 items".
class _Title extends StatelessWidget {
  const _Title({required this.day, required this.count, required this.dense});

  final DateTime day;
  final int? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final n = count;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              DateFormat('EEEE, MMMM d').format(day),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.title.copyWith(
                fontSize: dense
                    ? CalendarDimens.cardTitle
                    : CalendarDimens.dayTitle,
              ),
            ),
          ),
        ),
        if (n != null) ...[
          const SizedBox(width: AppSpacing.md),
          Text(
            CalendarDayAgenda.countLabel(n),
            maxLines: 1,
            style: context.text.buttonSmall.copyWith(
              fontSize: CalendarDimens.itemCount,
              color: ff.primary,
            ),
          ),
        ],
      ],
    );
  }
}

/// "Nothing planned · Add" — the whole card opens Quick Add on [day].
class CalendarEmptyDay extends StatelessWidget {
  const CalendarEmptyDay({required this.day, required this.onAdd, super.key});

  final DateTime day;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = context.text.rowTitle.copyWith(color: ff.inkMuted);
    return Semantics(
      button: true,
      label:
          'Nothing planned. Add something on '
          '${DateFormat('EEEE, MMMM d').format(day)}',
      excludeSemantics: true,
      child: FFCard(
        onTap: onAdd,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: CalendarDimens.cardPaddingH,
          vertical: AppSpacing.md,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Nothing planned · '),
              TextSpan(
                text: 'Add',
                style: style.copyWith(
                  color: ff.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

/// Three placeholder rows while the day loads.
class _AgendaSkeleton extends StatelessWidget {
  const _AgendaSkeleton();

  @override
  Widget build(BuildContext context) {
    return FFShimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: CalendarDimens.cardGap),
            const Row(
              children: [
                SizedBox(
                  width: CalendarDimens.timeColumn,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FFSkeleton(width: 36, height: 12),
                  ),
                ),
                SizedBox(width: CalendarDimens.timeGap),
                Expanded(
                  child: FFSkeleton(
                    height: 64,
                    radius: CalendarDimens.cardRadius,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

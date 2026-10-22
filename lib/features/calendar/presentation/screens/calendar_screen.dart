/// ============================================================
/// CALENDAR SCREEN — screen 26 (`/calendar?date=yyyy-MM-dd`)
/// ============================================================
///
/// What: back · "June 2023" · search · "+"; Week / Month / Agenda; then
///   • Month — the grid card (swipe months) + the selected day's agenda;
///   • Week — the selected week's row + agenda; task rows drag onto a day
///     to reschedule (Undo snackbar);
///   • Agenda — 7 days from the selected day, grouped.
/// Tap a day to list it; long-press a day for Quick Add on that date.
/// Why: one place to see tasks, reminders, habits and notes by date; all
/// data is live over [calendarDotsProvider] / [calendarAgendaProvider].
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/calendar/domain/services/calendar_rules.dart';
import 'package:focusflow/features/calendar/presentation/calendar_flows.dart';
import 'package:focusflow/features/calendar/presentation/calendar_tokens.dart';
import 'package:focusflow/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_agenda_range.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_day_agenda.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_grid_card.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_header.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({this.initialDay, super.key});

  /// The route's `?date=`; null = today.
  final DateTime? initialDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = calendarViewProvider(initialDay);
    final view = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return MinuteTicker(
      child: FFScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalendarHeader(
              title: DateFormat.yMMMM().format(view.month),
              onSearch: () => context.push(AppRoutes.search),
              onAdd: () => addOnCalendarDay(context, view.selectedDay),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: FFSegmented<CalendarMode>(
                segments: [
                  for (final m in CalendarMode.values)
                    FFSegment(value: m, label: m.label),
                ],
                value: view.mode,
                onChanged: controller.setMode,
                height: CalendarDimens.segmentedHeight,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.grouped,
                  AppSpacing.lg,
                  AppSpacing.grouped,
                  AppSpacing.xxxl,
                ),
                children: switch (view.mode) {
                  CalendarMode.month => [
                    _MonthGrid(view: view, controller: controller),
                    ..._dayAgenda(view.selectedDay, draggable: false),
                  ],
                  CalendarMode.week => [
                    _WeekRow(view: view, controller: controller),
                    const SizedBox(height: AppSpacing.sm),
                    const _DragHint(),
                    ..._dayAgenda(view.selectedDay, draggable: true),
                  ],
                  CalendarMode.agenda => [
                    CalendarAgendaRange(
                      start: view.selectedDay,
                      onShift: controller.shiftWeek,
                    ),
                  ],
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _dayAgenda(DateTime day, {required bool draggable}) => [
    const SizedBox(height: CalendarDimens.sectionGap),
    Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
      child: CalendarDayAgenda(day: day, draggable: draggable),
    ),
  ];
}

/// Dots of [range], or an error banner with Retry above [child]'s card.
Widget _withDots(
  WidgetRef ref,
  CalendarRange range,
  Widget Function(Map<String, List<ItemType>> dots) child,
) {
  final dots = ref.watch(calendarDotsProvider(range));
  final card = child(dots.valueOrNull ?? const {});
  if (!(dots.hasError && !dots.hasValue)) return card;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FFErrorBanner(
        message: tr('Couldn\'t load the calendar.'),
        onRetry: () => retryCalendarDots(ref, range),
      ),
      const SizedBox(height: AppSpacing.md),
      card,
    ],
  );
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.view, required this.controller});

  final CalendarViewState view;
  final CalendarController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
    final today = ref.watch(todayProvider);
    final grid = CalendarRules.monthGrid(view.month, weekStart);
    return _withDots(
      ref,
      calendarRangeOf(grid),
      (dots) => CalendarMonthCard(
        month: view.month,
        weekStart: weekStart,
        today: today,
        selectedDay: view.selectedDay,
        dots: dots,
        onSelect: controller.select,
        onLongPress: (day) => addOnCalendarDay(context, day),
        onShift: controller.shiftMonth,
      ),
    );
  }
}

class _WeekRow extends ConsumerWidget {
  const _WeekRow({required this.view, required this.controller});

  final CalendarViewState view;
  final CalendarController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
    final today = ref.watch(todayProvider);
    final days = DateUtilsX.weekDays(view.selectedDay, weekStart);
    return _withDots(
      ref,
      calendarRangeOf(days),
      (dots) => CalendarWeekCard(
        days: days,
        weekStart: weekStart,
        today: today,
        selectedDay: view.selectedDay,
        dots: dots,
        onSelect: controller.select,
        onLongPress: (day) => addOnCalendarDay(context, day),
        onShift: controller.shiftWeek,
        onDrop: (CalendarEntry entry, DateTime day) =>
            moveCalendarEntry(context, ref, entry, day),
      ),
    );
  }
}

/// Week view tip under the row.
class _DragHint extends StatelessWidget {
  const _DragHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      tr('Long-press a task and drop it on a day to reschedule'),
      textAlign: TextAlign.center,
      style: context.text.caption,
    );
  }
}

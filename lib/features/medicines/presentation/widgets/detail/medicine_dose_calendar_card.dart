/// ============================================================
/// MEDICINE DOSE CALENDAR — Week · Month · Year of the detail screen
/// ============================================================
///
/// What: the "taken doses" calendar. A Week | Month | Year switch picks the
/// view: Week = the last 7 days (dot per dose, the stats' own data, no
/// query); Month = a calendar of one month; Year = twelve mini months.
/// Month and Year have ‹ › arrows to go back to the month / year the
/// medicine started (and forward to the present); tapping a month in the
/// Year view opens it in the Month view.
/// Why: Month / Year read their logs only while selected
/// ([medicineCalendarProvider]); while the next span loads the previous one
/// stays on screen, dimmed, so browsing never flashes a spinner.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_calendar.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/providers/medicine_calendar_providers.dart';
import 'package:focusflow/features/medicines/presentation/widgets/detail/medicine_month_grid.dart';
import 'package:focusflow/features/medicines/presentation/widgets/detail/medicine_week_card.dart';
import 'package:focusflow/features/medicines/presentation/widgets/detail/medicine_year_grid.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

enum MedicineCalendarView { week, month, year }

/// The first day of [month]'s month, kept within `[min, max]` (both firsts).
DateTime clampMonth(DateTime month, DateTime min, DateTime max) {
  final m = DateTime(month.year, month.month);
  if (m.isBefore(min)) return min;
  if (m.isAfter(max)) return max;
  return m;
}

class MedicineDoseCalendarCard extends ConsumerStatefulWidget {
  const MedicineDoseCalendarCard({
    required this.medicine,
    required this.week,
    super.key,
  });

  final Medicine medicine;

  /// The last 7 days from the detail stats (today last).
  final List<MedicineWeekDay> week;

  @override
  ConsumerState<MedicineDoseCalendarCard> createState() =>
      _MedicineDoseCalendarCardState();
}

class _MedicineDoseCalendarCardState
    extends ConsumerState<MedicineDoseCalendarCard> {
  MedicineCalendarView _view = MedicineCalendarView.week;

  /// First day of the month shown (the Year view uses its year).
  DateTime? _month;

  /// Last non-empty span shown, kept while the next one loads.
  List<MedicineWeekDay> _last = const [];

  DateTime get _today => widget.week.isEmpty
      ? DateUtilsX.dateOnly(DateTime.now())
      : widget.week.last.day;
  DateTime get _minMonth {
    final s = widget.medicine.startDate;
    return DateTime(s.year, s.month);
  }

  DateTime get _maxMonth => DateTime(_today.year, _today.month);
  DateTime get _current => _month ?? _maxMonth;

  MedicineLogSpan get _span {
    final c = _current;
    return _view == MedicineCalendarView.year
        ? MedicineLogSpan(
            widget.medicine.id,
            DateTime(c.year),
            DateTime(c.year, 12, 31),
          )
        : MedicineLogSpan(
            widget.medicine.id,
            c,
            DateTime(c.year, c.month + 1, 0),
          );
  }

  bool get _canGoBack => _view == MedicineCalendarView.year
      ? _current.year > _minMonth.year
      : _current.isAfter(_minMonth);

  bool get _canGoForward => _view == MedicineCalendarView.year
      ? _current.year < _maxMonth.year
      : _current.isBefore(_maxMonth);

  void _shift(int step) => setState(() {
    final c = _current;
    _month = clampMonth(
      _view == MedicineCalendarView.year
          ? DateTime(c.year + step, c.month)
          : DateTime(c.year, c.month + step),
      _minMonth,
      _maxMonth,
    );
  });

  void _select(MedicineCalendarView v) {
    if (v == _view) return;
    setState(() {
      _view = v;
      _last = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final week = _view == MedicineCalendarView.week;
    final days = week
        ? const <MedicineWeekDay>[]
        : ref.watch(medicineCalendarProvider(_span));
    if (days.isNotEmpty) _last = days;
    final shown = days.isNotEmpty ? days : _last;
    final stale = !week && days.isEmpty && _last.isNotEmpty;
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));

    final Widget body;
    if (week) {
      body = MedicineWeekGrid(week: widget.week);
    } else if (shown.isEmpty) {
      body = const SizedBox(
        height: InsightsDimens.chartHeight,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    } else {
      body = AnimatedOpacity(
        opacity: stale ? InsightsDimens.staleOpacity : 1,
        duration: context.motion(AppMotion.fast),
        child: Column(
          children: [
            if (_view == MedicineCalendarView.month)
              MedicineMonthGrid(
                days: shown,
                today: _today,
                weekStart: weekStart,
              )
            else
              MedicineYearGrid(
                days: shown,
                weekStart: weekStart,
                onMonth: (m) => setState(() {
                  _view = MedicineCalendarView.month;
                  _month = clampMonth(m, _minMonth, _maxMonth);
                  _last = const [];
                }),
              ),
            const SizedBox(height: AppSpacing.lg),
            _view == MedicineCalendarView.year
                ? const _YearLegend()
                : const MedicineDoseLegend(),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: switch (_view) {
            MedicineCalendarView.week => tr('This week'),
            MedicineCalendarView.month => DateFormats.of(
              'MMMM y',
            ).format(_current),
            MedicineCalendarView.year => '${_current.year}',
          },
          trailing: week
              ? null
              : _Arrows(
                  year: _view == MedicineCalendarView.year,
                  onBack: _canGoBack ? () => _shift(-1) : null,
                  onForward: _canGoForward ? () => _shift(1) : null,
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        FFSegmented<MedicineCalendarView>(
          segments: [
            FFSegment(value: MedicineCalendarView.week, label: tr('Week')),
            FFSegment(value: MedicineCalendarView.month, label: tr('Month')),
            FFSegment(value: MedicineCalendarView.year, label: tr('Year')),
          ],
          value: _view,
          onChanged: _select,
        ),
        const SizedBox(height: AppSpacing.md),
        FFCard(
          child: AnimatedSize(
            duration: context.motion(AppMotion.fast),
            alignment: Alignment.topCenter,
            child: body,
          ),
        ),
      ],
    );
  }
}

class _Arrows extends StatelessWidget {
  const _Arrows({
    required this.year,
    required this.onBack,
    required this.onForward,
  });

  final bool year;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FFRoundIconButton(
          icon: rtl
              ? FontAwesomeIcons.chevronRight
              : FontAwesomeIcons.chevronLeft,
          semanticLabel: year ? tr('Previous year') : tr('Previous month'),
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.sm),
        FFRoundIconButton(
          icon: rtl
              ? FontAwesomeIcons.chevronLeft
              : FontAwesomeIcons.chevronRight,
          semanticLabel: year ? tr('Next year') : tr('Next month'),
          onPressed: onForward,
        ),
      ],
    );
  }
}

/// Key of the Year view's squares.
class _YearLegend extends StatelessWidget {
  const _YearLegend();

  @override
  Widget build(BuildContext context) {
    final entries = [
      (DayOutcome.taken, tr('Taken')),
      (DayOutcome.partial, tr('Partly taken')),
      (DayOutcome.missed, tr('Missed')),
      (DayOutcome.skipped, tr('Skipped')),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (o, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: MedicineSizes.weekDot - 2,
                height: MedicineSizes.weekDot - 2,
                decoration: BoxDecoration(
                  color: outcomeColor(context, o),
                  borderRadius: BorderRadius.circular(
                    (MedicineSizes.weekDot - 2) * 0.24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: context.text.caption),
            ],
          ),
      ],
    );
  }
}

/// ============================================================
/// INSIGHTS RANGE BAR — 7 Days · Today · 30 Days · 90 Days · Custom
/// ============================================================
///
/// FFChipBar over InsightsPreset. "Custom" opens the platform date-range
/// picker (days up to today) and then shows the picked span ("Oct 1 –
/// Oct 9"); cancelling keeps the previous range.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/presentation/providers/insights_providers.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:intl/intl.dart' show DateFormat;

class InsightsRangeBar extends ConsumerWidget {
  const InsightsRangeBar({super.key});

  /// How far back a custom range may start.
  static const int _maxYearsBack = 5;

  static String customLabel(InsightsRange r) {
    if (!r.isCustom) return InsightsPreset.custom.label;
    final f = DateFormat('MMM d');
    final a = r.customStart!;
    final b = r.customEnd!;
    return DateUtilsX.isSameDay(a, b)
        ? f.format(a)
        : '${f.format(a)} – ${f.format(b)}';
  }

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final today = readFreshToday(ref);
    final current = ref.read(insightsRangeProvider).resolve(today);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - _maxYearsBack, today.month, today.day),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: current.start,
        end: current.lastDay,
      ),
      helpText: 'Insights range',
    );
    if (picked == null) return;
    ref
        .read(insightsRangeProvider.notifier)
        .select(InsightsRange.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    return FFChipBar<InsightsPreset>(
      items: [
        for (final p in InsightsPreset.values)
          FFChipItem(
            value: p,
            label: p == InsightsPreset.custom ? customLabel(range) : p.label,
          ),
      ],
      selected: range.preset,
      onSelected: (p) {
        if (p == InsightsPreset.custom) {
          _pickCustom(context, ref);
        } else {
          ref
              .read(insightsRangeProvider.notifier)
              .select(InsightsRange.preset(p));
        }
      },
    );
  }
}

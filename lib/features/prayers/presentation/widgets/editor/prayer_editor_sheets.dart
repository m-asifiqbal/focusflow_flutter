/// ============================================================
/// PRAYER EDITOR SHEETS — the small pickers of the prayer editor
/// ============================================================
///
/// What: a time wheel ("Starts at"), the sun-event list (dawn, sunrise …
/// with today's time next to each when a location is saved), ± minutes
/// offsets, "minutes before" choices for reminders (with Off), a goal count
/// and the date range of a fast.
/// Why: the editor rows stay one line each; every choice opens a familiar
/// bottom sheet (the app's FF sheets, the reminder time wheel).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_time_wheel.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

/// Minute-of-day picker; null when dismissed.
Future<int?> showPrayerTimeSheet(
  BuildContext context, {
  required String title,
  required int minutes,
  required bool use24h,
}) => showFFBottomSheet<int>(
  context,
  builder: (_) => _TimeSheet(title: title, minutes: minutes, use24h: use24h),
);

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.title,
    required this.minutes,
    required this.use24h,
  });

  final String title;
  final int minutes;
  final bool use24h;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _minutes = widget.minutes;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(widget.title, style: context.text.title),
      const SizedBox(height: AppSpacing.lg),
      FFCard(
        padding: EdgeInsetsDirectional.zero,
        child: ReminderTimeWheel(
          minutes: widget.minutes,
          use24h: widget.use24h,
          onChanged: (m) => _minutes = m,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      FFPrimaryButton(
        label: tr('Done'),
        onPressed: () => Navigator.of(context).pop(_minutes),
      ),
    ],
  );
}

/// The sun events; [today] adds each one's time today (null = no location).
Future<SolarEvent?> showSolarEventSheet(
  BuildContext context, {
  required String title,
  required SolarEvent? selected,
  required SolarDay? today,
  required bool use24h,
}) async {
  final picked = await showOptionSheet<SolarEvent?>(
    context,
    title: title,
    subtitle: today == null
        ? tr('Set your location to see today\'s times')
        : tr('Follows the sun where you are, every day'),
    options: [
      for (final e in SolarEvent.values)
        OptionItem(
          value: e,
          label: e.label,
          subtitle: today == null
              ? null
              : PrayerFormat.time(today.at(e), use24h: use24h),
          icon: switch (e) {
            SolarEvent.dawn || SolarEvent.sunrise => FontAwesomeIcons.solidSun,
            SolarEvent.noon || SolarEvent.asr => FontAwesomeIcons.sun,
            SolarEvent.sunset => FontAwesomeIcons.cloudSun,
            _ => FontAwesomeIcons.solidMoon,
          },
          colors: PrayerStyle.module,
        ),
    ],
    selected: selected,
    accent: PrayerStyle.module.solid,
  );
  return picked?.value;
}

/// ± minutes after a sun event.
Future<int?> showOffsetSheet(
  BuildContext context, {
  required int selected,
}) async {
  const offsets = [-30, -20, -15, -10, -5, 0, 5, 10, 15, 20, 30];
  final picked = await showOptionSheet<int>(
    context,
    title: tr('Adjust by'),
    subtitle: tr('Minutes before (−) or after (+) the sun event'),
    options: [
      for (final o in offsets)
        OptionItem(
          value: o,
          label: o == 0 ? tr('Exactly at it') : PrayerFormat.offset(o),
          icon: FontAwesomeIcons.sliders,
          colors: PrayerStyle.module,
        ),
    ],
    selected: selected,
    accent: PrayerStyle.module.solid,
  );
  return picked?.value;
}

/// "Minutes before" choices with Off. Resolves to `Picked(null)` for Off,
/// null when dismissed.
Future<Picked<int?>?> showMinutesBeforeSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required int? selected,
  required List<int> choices,
  required String Function(int minutes) label,
}) => showOptionSheet<int?>(
  context,
  title: title,
  subtitle: subtitle,
  options: [
    OptionItem(
      value: null,
      label: tr('Off'),
      icon: FontAwesomeIcons.bellSlash,
      colors: PrayerStyle.module,
    ),
    for (final m in choices)
      OptionItem(
        value: m,
        label: label(m),
        icon: FontAwesomeIcons.solidBell,
        colors: PrayerStyle.module,
      ),
  ],
  selected: selected,
  accent: PrayerStyle.module.solid,
);

/// A daily goal (33 / 99 / 100 / 108 / custom). `Picked(null)` = no goal.
Future<Picked<int?>?> showGoalSheet(
  BuildContext context, {
  required int? selected,
}) async {
  const goals = [33, 34, 50, 99, 100, 108, 1000];
  final picked = await showOptionSheet<int?>(
    context,
    title: tr('Daily goal'),
    options: [
      OptionItem(
        value: null,
        label: tr('No goal'),
        icon: FontAwesomeIcons.infinity,
        colors: PrayerStyle.module,
      ),
      for (final g in goals)
        OptionItem(
          value: g,
          label: '$g',
          icon: FontAwesomeIcons.bullseye,
          colors: PrayerStyle.module,
        ),
      OptionItem(
        value: -1,
        label: tr('Custom…'),
        icon: FontAwesomeIcons.pen,
        colors: PrayerStyle.module,
      ),
    ],
    selected: goals.contains(selected) || selected == null ? selected : -1,
    accent: PrayerStyle.module.solid,
  );
  if (picked == null || picked.value != -1 || !context.mounted) return picked;
  final typed = await showTextInputSheet(
    context,
    title: tr('Daily goal'),
    hint: '100',
    initial: selected?.toString() ?? '',
  );
  final n = int.tryParse(typed ?? '');
  return n == null || n <= 0 ? null : Picked(n);
}

/// The date range of a prayer (a Ramadan fast); null when dismissed.
Future<DateTimeRange?> showPrayerDatesSheet(
  BuildContext context, {
  required DateTime? from,
  required DateTime? to,
  required DateTime now,
}) => showDateRangePicker(
  context: context,
  firstDate: DateTime(now.year - 1),
  lastDate: DateTime(now.year + 3),
  initialDateRange: from == null || to == null
      ? null
      : DateTimeRange(start: from, end: to),
  helpText: tr('Only between these days'),
);

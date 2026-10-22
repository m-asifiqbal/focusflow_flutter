/// ============================================================
/// DIGEST SECTION — "DAILY DIGEST" card of screen 31
/// ============================================================
///
/// What: Morning briefing · Evening review (time wheel sheets) and Weekly
/// report (weekday list), each showing its time/day or "Off".
/// Why: digests have no switch in the mockup — the sheet both sets the
/// time and offers "Turn off", so one tap covers both.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_pickers.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_controller.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_style.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Leading tile of every row on screen 31 (32 pt, solid).
class NotificationRowTile extends StatelessWidget {
  const NotificationRowTile(this.icon, this.colors, {super.key});

  final IconData icon;
  final ModuleColors colors;

  @override
  Widget build(BuildContext context) => FFIconTile(
    icon: icon,
    colors: colors,
    size: AppSizes.iconTileSm,
    iconSize: AppSizes.tileGlyph,
  );
}

class NotificationDigestSection extends ConsumerWidget {
  const NotificationDigestSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final controller = ref.read(notificationSettingsControllerProvider);
    final use24h = s.use24HourTime;
    String timeOrOff(bool on, int minutes) =>
        on ? NotificationLabels.time(minutes, use24h: use24h) : tr('Off');

    Future<void> pickTime(DigestKind kind, bool on, int minutes) async {
      final morning = kind == DigestKind.morning;
      final choice = await showNotificationTimeSheet(
        context,
        title: morning ? tr('Morning briefing') : tr('Evening review'),
        subtitle: morning
            ? tr('Today\'s plan: tasks, reminders and habits')
            : tr('What\'s done, what\'s left and tomorrow\'s first items'),
        minutes: minutes,
        use24h: use24h,
        offLabel: !on
            ? null
            : morning
            ? tr('Turn off morning briefing')
            : tr('Turn off evening review'),
      );
      if (choice != null) await controller.setDigest(kind, choice.value);
    }

    return FFGroupedList(
      label: tr('DAILY DIGEST'),
      children: [
        FFListRow(
          leading: const NotificationRowTile(
            FontAwesomeIcons.solidSun,
            NotificationTints.morning,
          ),
          title: tr('Morning briefing'),
          value: timeOrOff(s.morningBriefing, s.morningBriefingMinutes),
          onTap: () => pickTime(
            DigestKind.morning,
            s.morningBriefing,
            s.morningBriefingMinutes,
          ),
        ),
        FFListRow(
          leading: const NotificationRowTile(
            FontAwesomeIcons.solidMoon,
            NotificationTints.night,
          ),
          title: tr('Evening review'),
          value: timeOrOff(s.eveningReview, s.eveningReviewMinutes),
          onTap: () => pickTime(
            DigestKind.evening,
            s.eveningReview,
            s.eveningReviewMinutes,
          ),
        ),
        FFListRow(
          leading: const NotificationRowTile(
            FontAwesomeIcons.solidCalendar,
            NotificationTints.sky,
          ),
          title: tr('Weekly report'),
          value: s.weeklyReport
              ? NotificationLabels.weekdayShort(s.weeklyReportWeekday)
              : tr('Off'),
          onTap: () => _pickWeekday(context, s, controller),
        ),
      ],
    );
  }

  Future<void> _pickWeekday(
    BuildContext context,
    AppSettings s,
    NotificationSettingsController controller,
  ) async {
    final choice = await showNotificationOptionSheet<int>(
      context,
      title: tr('Weekly report'),
      subtitle: tr('A summary of your week, sent at {time}', {
        'time': NotificationLabels.time(
          PlannerTimes.weeklyReportMinutes,
          use24h: s.use24HourTime,
        ),
      }),
      selected: s.weeklyReport ? s.weeklyReportWeekday : null,
      options: [
        for (final d in NotificationLabels.orderedWeekdays(s.weekStartsOn))
          NotificationOption(
            value: d,
            label: NotificationLabels.weekdayLong(d),
          ),
        NotificationOption(value: null, label: tr('Off')),
      ],
    );
    if (choice != null) await controller.setWeeklyReport(choice.value);
  }
}

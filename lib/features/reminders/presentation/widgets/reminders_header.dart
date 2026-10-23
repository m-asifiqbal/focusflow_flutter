/// ============================================================
/// REMINDERS HEADER — top of screen 12
/// ============================================================
///
/// What: large header ("Reminders" · "3 today · next in 25 min", calendar
/// and ⋯ buttons), the "Notifications are off — Enable" banner when the
/// OS permission is denied, the week card (M–S, selected day in an
/// orange circle, dots on days with pending reminders) and the filter
/// chips (Today · Upcoming · Recurring · Location · Snoozed).
/// Why: all state comes from reminders_list_providers.dart; picking a
/// day switches back to the Today chip so the timeline shows that day.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/reminders/presentation/providers/reminders_list_providers.dart';
import 'package:focusflow/features/reminders/presentation/reminder_flows.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// The fixed toolbar (title, subtitle, calendar + more); the timeline below
/// it scrolls.
class RemindersToolbar extends ConsumerWidget {
  const RemindersToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = ref.watch(remindersSubtitleProvider);
    return FFLargeHeader(
      title: tr('Reminders'),
      leading: const FFBackButton(),
      fitTitle: true,
      subtitle: subtitle ?? ' ',
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        ReminderSizes.headerTop,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      actions: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.solidCalendarDays,
          semanticLabel: tr('Open calendar'),
          onPressed: () => context.push(AppRoutes.calendar),
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.ellipsis,
          semanticLabel: tr('More options'),
          onPressed: () => _showMore(context),
        ),
      ],
    );
  }

  void _showMore(BuildContext context) {
    showFFActionSheet(
      context,
      FFActionSheetData(
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.plus,
            label: tr('New reminder'),
            colors: ModuleStyle.reminders.colors,
            onTap: () => context.push(AppRoutes.newReminder()),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.solidBell,
            label: tr('Notification settings'),
            colors: ModuleStyle.tasks.colors,
            onTap: () => context.push(AppRoutes.settingsNotifications),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.boxArchive,
            label: tr('Archived reminders'),
            colors: ModuleStyle.habits.colors,
            onTap: () => context.push(AppRoutes.archive),
          ),
        ],
      ),
    );
  }
}

/// Header, permission banner, week card and chips (a list of slivers'
/// worth of boxes, top to bottom).
class RemindersHeader extends ConsumerWidget {
  const RemindersHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final denied =
        ref.watch(notificationPermissionProvider).valueOrNull ==
        NotificationPermission.denied;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (denied)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              0,
            ),
            child: FFInfoBanner(
              icon: FontAwesomeIcons.solidBellSlash,
              colors: ModuleStyle.reminders.colors,
              text: tr('Notifications are off — reminders can\'t alert you.'),
              actionLabel: tr('Enable'),
              onAction: () => enableReminderNotifications(ref),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        const _WeekCard(),
        const SizedBox(height: AppSpacing.lg),
        const _FilterChips(),
      ],
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(reminderDayProvider);
    final today = ref.watch(todayProvider);
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
    final days = DateUtilsX.weekDays(day, weekStart);
    final dots =
        ref.watch(reminderWeekDotsProvider(days.first)).valueOrNull ??
        const <String>{};
    final accent = ModuleStyle.reminders.solid;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
      ),
      child: FFCard(
        radius: AppRadii.hero,
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: ReminderSizes.weekCardVertical,
        ),
        child: FFWeekStrip(
          style: FFWeekStripStyle.circle,
          days: days,
          selected: day,
          today: today,
          accent: accent,
          dotColor: accent.withValues(alpha: 0.55),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ReminderSizes.weekStripSide,
          ),
          hasItems: (d) => dots.contains(DateUtilsX.dayKey(d)),
          onSelected: (d) {
            ref.read(selectedReminderDayProvider.notifier).select(d);
            // The Medicine chip stays on: it shows the picked day too.
            ref.read(reminderFilterProvider.notifier).set(RemindersScope.today);
          },
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  /// Value of the "Medicine" chip (the others are [RemindersScope]s).
  static const Object _medicine = 'medicine';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(reminderFilterProvider);
    final medicine = ref.watch(reminderMedicineChipProvider);
    final filters = reminderFilters;
    return FFChipBar<Object>(
      items: [
        for (final (i, (scope, label)) in filters.indexed) ...[
          FFChipItem<Object>(value: scope, label: label),
          // After "Upcoming": the doses of the picked day.
          if (i == 1)
            FFChipItem<Object>(
              value: _medicine,
              label: tr('Medicine'),
              icon: FontAwesomeIcons.pills,
            ),
        ],
      ],
      selected: medicine ? _medicine : selected,
      onSelected: (v) {
        final chip = ref.read(reminderMedicineChipProvider.notifier);
        if (v == _medicine) {
          chip.set(true);
          return;
        }
        chip.set(false);
        ref.read(reminderFilterProvider.notifier).set(v as RemindersScope);
      },
    );
  }
}

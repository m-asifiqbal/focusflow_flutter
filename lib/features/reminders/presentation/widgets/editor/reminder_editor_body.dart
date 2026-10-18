/// ============================================================
/// REMINDER EDITOR BODY — the scrolling form of screen 13
/// ============================================================
///
/// What: (notifications-off banner | reliability banners: exact alarms,
/// background delivery) → title card → WHEN (day chips + time
/// wheel) → REPEAT chips → ALERT → LINK TO → Archive / Delete (existing
/// reminders), spaced like the task editor (same section rhythm).
/// Why: keeps the screen file to navigation and lifecycle flows.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/alarm_overlay.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_editor_controller.dart';
import 'package:focusflow/features/reminders/presentation/reminder_flows.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_alert_card.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_reliability_banners.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_time_wheel.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_title_card.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_when_section.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_labels.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_body.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_chrome.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';

class ReminderEditorBody extends ConsumerWidget {
  const ReminderEditorBody({
    required this.args,
    required this.state,
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  final ReminderEditorArgs args;
  final ReminderEditorState state;

  /// Null hides Archive.
  final VoidCallback? onArchive;
  final VoidCallback onDelete;

  /// Card → next section label (as in the task editor).
  static const double _sectionGap = 25;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.read(reminderEditorControllerProvider(args).notifier);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final permission = ref.watch(notificationPermissionProvider).valueOrNull;
    final denied = permission == NotificationPermission.denied;
    final r = state.draft;
    final fullScreenOff =
        r.alertStyle == AlertStyle.alarm &&
        ref.watch(fullScreenAlarmsAllowedProvider).valueOrNull == false;
    final overAppsOff =
        r.alertStyle == AlertStyle.alarm &&
        ref.watch(alarmOverAppsAllowedProvider).valueOrNull == false;
    // A one-time time that has passed moves forward on Save; say so here.
    final now = ref.watch(minuteClockProvider);
    final rolled = state.pastTimeRollsTo(now);
    const gap = SizedBox(height: _sectionGap);
    const labelPadding = TaskEditorBody.labelPadding;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (denied) ...[
          FFInfoBanner(
            icon: FontAwesomeIcons.solidBellSlash,
            colors: ModuleStyle.reminders.colors,
            text: "Notifications are off — this reminder can't alert you.",
            actionLabel: 'Enable',
            onAction: () => enableReminderNotifications(ref),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // Exact alarms / background delivery (Android; nothing on iOS).
        const ReminderReliabilityBanners(),
        ReminderTitleCard(
          title: r.title,
          note: r.note,
          autofocus: state.isNew && r.title.isEmpty,
          onTitleChanged: form.setTitle,
          onNoteChanged: form.setNote,
        ),
        gap,
        const FFSectionLabel('When', padding: labelPadding),
        ReminderDayChips(args: args, reminder: r),
        const SizedBox(height: ReminderSizes.whenGap),
        ReminderTimeWheel(
          minutes: state.minutes,
          use24h: use24h,
          onChanged: form.setTime,
        ),
        if (rolled != null)
          ReminderPastTimeHint(
            text:
                'This time has passed — saving sets it for '
                '${ReminderLabels.rolledTo(rolled, now, use24h: use24h)}.',
          ),
        gap,
        const FFSectionLabel('Repeat', padding: labelPadding),
        ReminderRepeatChips(args: args, reminder: r),
        gap,
        const FFSectionLabel('Alert', padding: labelPadding),
        ReminderAlertCard(args: args, reminder: r),
        if (fullScreenOff) ...[
          const SizedBox(height: AppSpacing.md),
          FFInfoBanner(
            icon: FontAwesomeIcons.bellConcierge,
            colors: ModuleStyle.reminders.colors,
            text:
                'Full-screen alarms are off — this reminder will show as a '
                'regular alert.',
            actionLabel: 'Allow',
            onAction: () => allowFullScreenAlarms(ref),
          ),
        ],
        if (overAppsOff) ...[
          const SizedBox(height: AppSpacing.md),
          FFInfoBanner(
            icon: FontAwesomeIcons.windowRestore,
            colors: ModuleStyle.reminders.colors,
            text: ReminderReliabilityBanners.overAppsText,
            actionLabel: 'Allow',
            onAction: () => allowAlarmOverApps(ref),
          ),
        ],
        gap,
        const FFSectionLabel('Link to', padding: labelPadding),
        ReminderLinkCard(args: args, reminder: r),
        if (!state.isNew) ...[
          const SizedBox(height: AppSpacing.xxl),
          TaskEditorFooter(onArchive: onArchive, onDelete: onDelete),
        ],
      ],
    );
  }
}

/// Inline warning under the time wheel: the chosen one-time time has
/// passed, and where Save will move it.
class ReminderPastTimeHint extends StatelessWidget {
  const ReminderPastTimeHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final ink = ModuleStyle.reminders.colors.inkFor(ff.brightness);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: AppSpacing.sm,
          start: AppSpacing.xs,
          end: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
              child: Icon(
                FontAwesomeIcons.circleExclamation,
                size: AppSizes.tileGlyph,
                color: ink,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: context.text.reminderNote.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

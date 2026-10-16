/// ============================================================
/// SETTINGS ROOT ACTIONS — what tapping a row / search result does
/// ============================================================
///
/// What: [runSettingsEntry] opens a search result (deep link or in-place
/// action); [runRootAction] runs the picker sheets of the root rows
/// (language, start screen, week start, time format), the mail
/// links (help, feedback) and the rate prompt; [confirmSignOut] signs out.
/// Why: the same actions are reachable from a row and from a search
/// result, so they live in one place. Pickers reuse the single-choice
/// sheet of Settings › Notifications for a consistent look.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/google_account.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_pickers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a search result.
Future<void> runSettingsEntry(
  BuildContext context,
  WidgetRef ref,
  SettingsEntry entry,
) async {
  final route = entry.route;
  if (route != null) {
    await context.push(route);
    return;
  }
  await runRootAction(context, ref, entry.action!);
}

Future<void> runRootAction(
  BuildContext context,
  WidgetRef ref,
  SettingsRootAction action,
) async {
  final s = ref.read(settingsProvider);
  final editor = ref.read(settingsEditorProvider);
  switch (action) {
    case SettingsRootAction.language:
      final c = await showNotificationOptionSheet<String>(
        context,
        title: 'Language',
        subtitle: 'More languages are coming in a future update.',
        selected: s.languageCode,
        options: [
          for (final e in SettingsLabels.languages.entries)
            NotificationOption(value: e.key, label: e.value),
        ],
      );
      if (c?.value != null) await editor.setLanguage(c!.value!);
    case SettingsRootAction.startScreen:
      final c = await showNotificationOptionSheet<StartScreen>(
        context,
        title: 'Start screen',
        subtitle: 'The tab FocusFlow opens on.',
        selected: s.startScreen,
        options: [
          for (final v in StartScreen.values)
            NotificationOption(value: v, label: SettingsLabels.startScreen(v)),
        ],
      );
      if (c?.value != null) await editor.setStartScreen(c!.value!);
    case SettingsRootAction.weekStart:
      final c = await showNotificationOptionSheet<int>(
        context,
        title: 'Week starts on',
        subtitle: 'Used by the calendar, week strips, habits and insights.',
        selected: s.weekStartsOn,
        options: [
          for (final d in const [
            DateTime.monday,
            DateTime.saturday,
            DateTime.sunday,
          ])
            NotificationOption(value: d, label: SettingsLabels.weekday(d)),
        ],
      );
      if (c?.value != null) await editor.setWeekStart(c!.value!);
    case SettingsRootAction.dateTimeFormat:
      final c = await showNotificationOptionSheet<bool>(
        context,
        title: 'Date & time format',
        selected: s.use24HourTime,
        options: const [
          NotificationOption(
            value: false,
            label: '12-hour',
            subtitle: '9:41 PM',
          ),
          NotificationOption(value: true, label: '24-hour', subtitle: '21:41'),
        ],
      );
      if (c?.value != null) await editor.setUse24Hour(c!.value!);
    case SettingsRootAction.hideInSwitcher:
      await editor.setHideInAppSwitcher(!s.hideInAppSwitcher);
      if (context.mounted) {
        showFFToast(
          context,
          s.hideInAppSwitcher
              ? 'Content shown in the app switcher'
              : 'Content hidden in the app switcher',
          icon: FontAwesomeIcons.solidEyeSlash,
        );
      }
    case SettingsRootAction.help:
      await _mail(context, subject: '${AppInfo.name} help');
    case SettingsRootAction.feedback:
      final version = ref.read(appVersionProvider).valueOrNull ?? '';
      await _mail(context, subject: '${AppInfo.name} feedback $version'.trim());
    case SettingsRootAction.rate:
      showFFToast(
        context,
        'Thank you! Rating opens once ${AppInfo.name} is in the store.',
        icon: FontAwesomeIcons.solidStar,
      );
  }
}

Future<void> _mail(BuildContext context, {required String subject}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppInfo.supportEmail,
    query: 'subject=${Uri.encodeComponent(subject)}',
  );
  var opened = false;
  try {
    opened = await launchUrl(uri);
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    showFFToast(
      context,
      'No mail app found. Write to ${AppInfo.supportEmail}',
      icon: FontAwesomeIcons.solidEnvelope,
    );
  }
}

/// Asks, then signs out. Local data stays on the device.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showFFConfirm(
    context,
    title: 'Sign out?',
    message:
        'Your notes, tasks and vault stay on this device. Backups to Google '
        'Drive pause until you sign in again.',
    confirmLabel: 'Sign out',
    destructive: true,
    icon: FontAwesomeIcons.rightFromBracket,
  );
  if (!ok) return;
  await ref.read(cloudAccountControllerProvider).signOut();
  if (context.mounted) {
    showFFToast(context, 'Signed out', icon: FontAwesomeIcons.solidCircleCheck);
  }
}

/// Signed-out card: Google sign-in in place (or an honest message when the
/// build has no OAuth client ids).
Future<void> signInWithGoogle(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(cloudAccountControllerProvider);
  if (!controller.googleAvailable) {
    showFFToast(
      context,
      'Google Drive is not set up in this build',
      icon: FontAwesomeIcons.circleInfo,
    );
    return;
  }
  try {
    await controller.signInWithGoogle();
  } on CloudAuthException catch (e) {
    if (context.mounted) showFFToast(context, e.message);
  } on Object {
    if (context.mounted) {
      showFFToast(context, "Couldn't sign in. Check your connection.");
    }
  }
}

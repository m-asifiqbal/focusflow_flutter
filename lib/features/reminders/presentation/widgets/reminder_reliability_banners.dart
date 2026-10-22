/// ============================================================
/// REMINDER RELIABILITY BANNERS — "will this reminder really fire?"
/// ============================================================
///
/// What: inline banners for what can still delay or drop a reminder once
/// notifications are allowed (Android only; nothing on iOS):
///   • exact alarms not allowed → "Reminders may be late — allow exact
///     alarms" → opens Android's "Alarms & reminders" page;
///   • battery optimisation on → "Allow reminders in the background" →
///     Android's battery-optimisation dialog (opt-in, see
///     core/notifications/background_delivery.dart);
///   • a phone maker known to stop alarms of swiped-away apps (Xiaomi,
///     Oppo, Vivo, Huawei, Samsung …) → "allow auto-start" → that maker's
///     own auto-start / background screen.
/// The reminder editor shows at most one (exact alarms first, then
/// battery, then auto-start) and stops suggesting the last two once asked;
/// Settings › Notifications can show all with [showAll].
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/notifications/alarm_overlay.dart';
import 'package:focusflow/core/notifications/background_delivery.dart';
import 'package:focusflow/core/notifications/lock_screen_access.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/reminder_flows.dart';

class ReminderReliabilityBanners extends ConsumerWidget {
  const ReminderReliabilityBanners({this.showAll = false, super.key});

  /// Settings: both banners, and the battery one even after it was asked.
  final bool showAll;

  // Getters, not constants, so the texts follow the active language.
  static String get exactText =>
      tr('Reminders may be late — allow exact alarms.');
  static String get backgroundText => tr(
    'Allow reminders in the background — some phones stop them when the '
    'app is closed.',
  );

  static String get overAppsText => tr(
    'Let alarms appear over other apps — otherwise the alarm screen opens '
    'only when you tap the notification.',
  );

  static String get lockScreenMakerText => tr(
    'On Xiaomi phones, allow "Show on lock screen" and "Display pop-up '
    'windows while running in the background" for the app — otherwise '
    'alarms and reminders can stay off the lock screen.',
  );

  static String get lockScreenChannelText => tr(
    'Lock-screen alerts are turned off for some reminders in system '
    'settings — turn "Lock screen" back on.',
  );

  /// [brand] phones stop alarms of an app that is swiped away unless it is
  /// on the maker's auto-start list.
  static String autostartText(String brand) => tr(
    'On {brand} phones, allow auto-start / background activity for the '
    'app, or reminders can stop after you swipe it away.',
    {'brand': brand},
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(notificationPermissionProvider).valueOrNull;
    // Only meaningful once notifications themselves are allowed.
    if (permission != NotificationPermission.granted) {
      return const SizedBox.shrink();
    }
    final inexact =
        ref.watch(exactAlarmPermissionProvider).valueOrNull ==
        ExactAlarmPermission.denied;
    final restricted = showAll
        ? ref.watch(unrestrictedBackgroundProvider).valueOrNull == false
        : ref.watch(suggestUnrestrictedBackgroundProvider);
    // Settings only: the editor shows its own, for alarm-style reminders.
    final overAppsOff =
        showAll && ref.watch(alarmOverAppsAllowedProvider).valueOrNull == false;
    final lock =
        ref.watch(lockScreenAccessProvider).valueOrNull ??
        LockScreenAccess.fine;
    // Known off always; "could not read" only in Settings (never nag the
    // editor over something that may be fine).
    final lockOff = lock.needsAttention || (showAll && lock.makerSwitchUnknown);
    final lockShown = lockOff && (showAll || !inexact);
    final brand = ref.watch(aggressiveBrandProvider).valueOrNull;
    final autostartWanted = showAll || ref.watch(suggestAutostartProvider);
    final colors = ModuleStyle.reminders.colors;
    final banners = <Widget>[
      if (inexact)
        FFInfoBanner(
          icon: FontAwesomeIcons.solidClock,
          colors: colors,
          text: exactText,
          actionLabel: tr('Allow'),
          onAction: () => allowExactAlarms(ref),
        ),
      if (lockShown)
        FFInfoBanner(
          icon: FontAwesomeIcons.lock,
          colors: colors,
          text: lock.makerSwitchOff || lock.makerSwitchUnknown
              ? lockScreenMakerText
              : lockScreenChannelText,
          actionLabel: tr('Open'),
          onAction: () => ref.read(lockScreenSettingsRequestProvider)(
            channelId: lock.blockedChannels.firstOrNull,
          ),
        ),
      if (restricted && (showAll || (!inexact && !lockShown)))
        FFInfoBanner(
          icon: FontAwesomeIcons.batteryHalf,
          colors: colors,
          text: backgroundText,
          actionLabel: tr('Allow'),
          onAction: () => allowRemindersInBackground(ref),
        ),
      if (overAppsOff)
        FFInfoBanner(
          icon: FontAwesomeIcons.windowRestore,
          colors: colors,
          text: overAppsText,
          actionLabel: tr('Allow'),
          onAction: () => allowAlarmOverApps(ref),
        ),
      // Last, and only when nothing else is pending (the editor shows one).
      if (brand != null &&
          autostartWanted &&
          (showAll || (!inexact && !restricted && !lockShown)))
        FFInfoBanner(
          icon: FontAwesomeIcons.powerOff,
          colors: colors,
          text: autostartText(brand),
          actionLabel: tr('Open'),
          onAction: () => allowAutostart(ref),
        ),
    ];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < banners.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            banners[i],
          ],
        ],
      ),
    );
  }
}

# Notifications — delivery, sound and platform notes

How FocusFlow gets reminders to fire on time, with sound, while the app is
closed (code: `lib/core/notifications/`).

## Scheduling
* The engine (`engine/reconciling_engine.dart`) keeps the OS schedule equal
  to the plan. Editors (reminder, task "Remind me") **await** a pass after
  saving (`flushNotifications`), and the engine flushes when the app goes to
  the background, so a reminder saved right before the app is swiped away is
  already with the OS. The OS then delivers it with the app closed
  (Android `AlarmManager` via flutter_local_notifications'
  `ScheduledNotificationReceiver`; iOS `UNCalendarNotificationTrigger`).
* iOS keeps at most 64 pending requests, so the plan is a rolling window
  (60). It is refilled while the app runs, after every notification action
  (background isolate) and by the 12 h maintenance task
  (`core/sync/background_runner.dart` → `engine/background_reconcile.dart`).

## Android
* **Exact alarms.** `USE_EXACT_ALARM` (API 33+) is granted at install for apps
  whose core function is reminders/alarms; `SCHEDULE_EXACT_ALARM` is declared
  with `maxSdkVersion="32"` (granted by default on Android 12/12L). Without
  either, alarms fall back to inexact delivery, which Doze can delay by hours.
  **Play policy:** `USE_EXACT_ALARM` must be declared in the Play Console
  (App content › Exact alarm permission) with the use case *"Calendar or
  alarm clock / reminders"*. If the declaration is ever rejected, remove
  `USE_EXACT_ALARM`, drop the `maxSdkVersion` on `SCHEDULE_EXACT_ALARM`, and
  rely on the in-app "Reminders may be late — allow exact alarms" banner
  (reminder editor; `exactAlarmPermissionProvider`).
* **Battery optimisation.** Some OEM builds (Xiaomi, Oppo, Vivo, Samsung
  "sleeping apps") kill alarms of optimised apps. "Allow reminders in the
  background" (reminder editor banner; Settings can show
  `ReminderReliabilityBanners(showAll: true)`) asks for
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — opt-in, only on tap. **Play
  policy** allows this permission for apps whose core function is
  time-critical reminders; justify it in the review if asked, or remove the
  permission (the banner then shows nothing).
* **Channels are immutable** once created on a device (sound, importance).
  Channel ids are versioned (`*_v2`, `NotificationChannelId`); the old ids
  are deleted after the first pass has moved every pending notification to
  the new channels. Change a channel's sound/importance ⇒ bump the version.
* **Sounds.** Chime / Bell / Gentle / Pulse are generated WAVs
  (`tool/sounds/generate_sounds.py`) in `res/raw/` (kept from resource
  shrinking by `res/raw/keep.xml`), one channel per tone. Alarm-style uses
  the alarm audio stream, is insistent and uses a full-screen intent
  (Android 14+ may require the user to allow full-screen notifications —
  the editor asks when alarm-style is switched on).
* The activity shows over the lock screen **only** when launched by an
  alarm-style full-screen notification (MainActivity.kt).

## iOS
* The tones are bundled as Flutter assets (`assets/sounds/`) and copied to
  `Library/Sounds` at start-up; iOS plays `<tone>.wav` from there (a missing
  file falls back to the default sound). No Xcode project change needed.
* Requests set `presentSound`, `sound`, `presentAlert/Banner/List`
  explicitly (the plugin leaves the sound nil — silent — when
  `presentSound` is not true).
* Alarm-style uses `InterruptionLevel.timeSensitive`. Breaking through
  Focus needs the Time Sensitive Notifications capability (entitlement
  `com.apple.developer.usernotifications.time-sensitive`, App ID +
  provisioning profile); it is not enabled so builds signed without that
  profile keep working — iOS then delivers at the normal level.
* Permission (alert, badge, sound) is requested on the first save of a
  reminder / task reminder / habit reminder while it is undetermined;
  afterwards Settings › Notifications opens the system page.

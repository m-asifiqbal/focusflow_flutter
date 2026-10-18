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

## When the app is killed
What survives, and what the engine does about the rest:
* **Swiped away on stock Android / Samsung with default settings:** nothing
  is lost. The alarms belong to the OS and fire with no app process.
* **Force-stopped, or swiped away on Xiaomi / Oppo / Vivo / Huawei / some
  Samsung modes:** Android drops *every* alarm of the app. The plugin's own
  list of pending requests is stored data and keeps naming them, so the
  engine cannot tell. Therefore:
  * the **first pass of every process** (app launch, the 12 h background
    task) passes `rearm: true` to `NotificationReconciler.reconcile`:
    every planned request is handed to the OS again (same id = replaced, so
    a healthy alarm is just renewed);
  * a request that is past its time yet still listed was *lost*, not late
    (a delivered one-shot request leaves the plugin's list at once). A lost
    reminder / task alert is recorded in the inbox and shown now as
    **"Missed · was due at 9:00 AM"** (within 24 h; silent in quiet hours;
    an alarm-style one comes back as a plain heads-up). Habit nudges and
    digests only go to the inbox.
  * Until the user opens the app (or the background task runs), nothing can
    fire — that is Android's rule for a stopped app. The only prevention is
    the user's: Settings › Notifications offers **"allow auto-start"** on
    the makers that need it (`aggressiveBackgroundMakers`), which opens the
    maker's own screen (`MainActivity.openAutostartSettings`), plus the
    battery-optimisation switch.
* **Reach.** Reminders, alarms and task alerts ("vital") get their slots
  first; habit nudges and digests fill the rest. On Android the next
  occurrence of a reminder is planned up to 120 days ahead and up to 240
  requests are held (AlarmManager allows 500); iOS keeps 60 (limit 64), so
  there a reminder further than 45 days waits for the next refill.
  (`PlannerLimits`, `NotificationPlanner.plan`.)

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

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

## Medicine doses
* `planning/medicine_planner.dart` plans one notification per dose time;
  doses of several medicines due at the same minute share one ("Time for 2
  medicines") and its Taken / Snooze / Skip apply to all of them (the
  payload's `doses` lists the medicine ids). Keys: `med:<day>:<minute>`,
  `…:s` for snoozed doses (a new key, so an alarm the alarm service
  re-armed on its own is cancelled rather than doubled) and `…:f` for the
  "Did you take your 8:00 AM dose?" follow-up (`followUpMinutes` after the
  dose while it is still not logged; not vital, no inbox row).
* Doses are vital (they take their cap slots first, like reminders) and
  ignore quiet hours. They are planned over `horizonDays` (14), not the
  longer vital horizon, so a daily medicine can't fill the cap for months.
* Alarm-style medicines ring through the alarm service; the follow-up is
  always a plain notification. Settings › Notifications › "Medicine doses"
  (`AppSettings.notifyMedicines`) turns them all off.
* Taken / Skip / Snooze write through `MedicinesRepository` from the
  foreground handler, the background isolate and the alarm's Snooze alike
  (`engine/notification_actions.dart`).
* The medicine name only appears in the text; the lock-screen setting
  (Settings › Notifications) decides what a locked phone shows.

## Alarms (Android): real ones
An alarm-style reminder used to be a "max priority, insistent" notification:
it played its channel sound once and stayed silent in Do-not-disturb, so it
did not *ring*. On Android it is now a real alarm, built the way alarm-clock
apps are (`core/notifications/engine/alarm_driver.dart`, the `alarm` package):
* `AlarmManager.setAlarmClock` — exempt from Doze and battery savers, listed
  by the system as the next alarm;
* a **foreground service** loops the sound on the alarm stream (fade-in
  3 s) and vibrates, so it needs no Dart and keeps going when the app is
  swiped away (`androidStopAlarmOnTermination: false`);
* a **full-screen intent** lights the lock screen; notification buttons
  **Stop** and **Snooze** (the reminder's snooze length; a swipe cannot
  silence it); a boot receiver re-arms the alarms after a restart;
* the sound is the reminder's tone (`assets/sounds/<tone>.wav`), else the
  system alarm sound.
`LocalNotificationsGateway` sends planned *alarm* notifications there and
everything else to flutter_local_notifications; `pendingIds()` / `cancel()`
cover both, so planning, the ledger, the inbox and "Missed" catch-up are
unchanged. A snooze taken on the ringing alarm is applied to the reminder
(only while it is still in the future). An alarm the service dropped without
ringing (phone off) comes back as "Missed". If the system refuses the alarm
(no exact-alarm grant) it falls back to a notification. iOS has no alarm API:
alarm-style stays a time-sensitive notification there.

**Auto-snooze.** An alarm that rings for 2 minutes without a Stop or Snooze
is snoozed by itself (`android/.../AlarmAutoSnooze.kt`, started by
`FocusFlowApplication` when the ring starts). It calls the alarm package's own
`SnoozeCoordinator` — the same code as the Snooze button — so the alarm is
re-armed for its snooze length (the reminder's "snooze minutes", default 10),
the ring is silenced, the screen closes and Dart is told if it is running.
Each ring is timed separately (a snoozed alarm gets a fresh 2 minutes), and it
repeats for as long as nobody answers. It needs no Flutter engine and no open
alarm screen — only the ringing service, which keeps the process alive.

## The alarm guard (Android)
"Alarms stop when I clear the app from recents." What *fires* an alarm and what
*keeps the app alive* are different jobs, so the guard layers a keeper on top
of the exact alarms (code: `android/app/src/main/kotlin/.../guard/`,
`core/notifications/alarm_guard.dart`):
* **Trigger — `AlarmManager`, exact.** `setAlarmClock` for alarm-style
  reminders, `setExactAndAllowWhileIdle` for the rest. The only API that fires
  at the exact minute with the app not running and the phone in Doze.
  **WorkManager is deliberately not the trigger:** a periodic job is at best
  every 15 min and Doze defers it, so it cannot ring an alarm on time (it stays
  what it was: the 12 h backup / maintenance task).
* **Keeper — `AlarmGuardService`, a sticky foreground service** (type
  `specialUse`, a quiet low-importance notification "Keeping your alarms on
  time · Next: 7:30 AM" with nothing private on it). It runs while a reminder,
  alarm or task alert is due — the engine reports that after every pass
  (`ReconcileResult.vitalPending`; digests and nudges do not count) — and stops
  itself when nothing is left (3 h after the last due time). A process hosting
  a foreground service is the last one phone makers' task killers and memory
  cleaners take, and Android restarts it if it is killed anyway.
  Switch: Settings › Notifications › **Keep alarms running**
  (`AppSettings.keepAlarmsAlive`, on by default, Android only).
* **Watchdog — an exact `AlarmManager` alarm** every 15 min (and 20 s after the
  app is swiped away). If the service is gone it is restarted — an exact alarm
  may start a foreground service from the background, a WorkManager job may
  not — and everything is re-armed; if it is alive the watchdog asks it for its
  periodic check.
* **Receiver — `AlarmGuardReceiver`:** brings the guard back after a reboot and
  after an app update (both stop it).
* **Self-repair (`AlarmGuard.verifyAlarms` / `healNotifications`):** each alarm
  the `alarm` plugin has stored is checked against `AlarmManager` (no live
  `PendingIntent` = not armed) and re-armed; an alarm that passed its time
  without ringing is rung now (older than its 15 min stale window: dropped, and
  reported as "Missed" on the next start, like after a reboot); the scheduled
  notifications of flutter_local_notifications are re-armed (at most every 6 h)
  by running that plugin's own boot receiver. Alarms that are ringing, queued
  or only just due are never touched (delivering one again makes the alarm
  service silence it).
* **What it cannot do:** survive a *force-stop*. On Xiaomi / Oppo / Vivo /
  Huawei / some Samsung modes a swipe from recents *is* a force-stop unless the
  user allowed auto-start for the app; Android then removes the process, its
  services and all its alarms and nothing runs until the app is opened. That is
  an OS rule no service or WorkManager job can get around — the engine's
  re-arm + "Missed" catch-up on the next start, and the auto-start guidance
  below, remain the answer. The guard shrinks the cases where an alarm is lost
  anyway (task killers that spare foreground services, cleaners that only wipe
  alarms, a killed process, reboots and updates).
* **Play Console:** the service uses `FOREGROUND_SERVICE_SPECIAL_USE`; declare it
  (App content › Foreground service permissions) as: "Keeps scheduled alarms and
  reminders reliable after the app is swiped away." The manifest's
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` says the same.
* **Verification status:** the Kotlin compiles (`:app:compileDebugKotlin`), the
  merged manifest has the service / receiver, and the Dart side is unit-tested;
  the native behaviour has **not** been run on a phone. Try it: set an alarm two
  minutes ahead, clear the app from recents, wait.

## When the app is killed
What survives, and what the engine does about the rest:
* **Swiped away on stock Android / Samsung with default settings:** nothing
  is lost. The alarms belong to the OS and fire with no app process (and the
  alarm guard above keeps the app's process up while something is due).
* **Force-stopped, or swiped away on Xiaomi / Oppo / Vivo / Huawei / some
  Samsung modes:** Android drops *every* alarm of the app. The plugin's own
  list of pending requests is stored data and keeps naming them, so the
  engine cannot tell. Therefore:
  * the **first pass of every process** (app launch, the 12 h background
    task) passes `rearm: true` to `NotificationReconciler.reconcile`:
    planned requests are handed to the OS again (same id = replaced, so a
    healthy alarm is just renewed). A *launch* first asks the OS which alarms
    it still holds (`NotificationGateway.armedIds`, native `ArmedAlarms`: a
    live `PendingIntent` for the request code — Android drops every one on a
    force-stop) and renews only the others, so a healthy launch sends
    nothing; after a force-stop none is armed and all are renewed. A *full*
    renewal (everything, no questions) still runs at a launch when the last
    one is 24 h old (`RearmPolicy`) and always in the background task;
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

## Keeping it light
The planner and the engine run on the UI isolate, so they are written not to
cost frames (measured on a heavy dataset: 250 tasks, 150 reminders, 25 habits
with 6 months of history — `NotificationPlanner.plan` went from ~3.3 s to
~35 ms, a launch from seconds of CPU to well under half a second):
* **`TaskDayIndex`** sorts the open dated tasks once by integer day number;
  the overdue / due-today counts behind every badge and digest are binary
  searches. Badges are decided *after* the cap, one lookup per distinct day.
* **Integer day maths** (`DateUtilsX.dayNumber`, `HabitSchedule.isDueByNumber`)
  everywhere a loop walks days — a local `DateTime` is a time-zone lookup.
  Streaks, the schedule and the streak-at-risk projection are linear.
* **One pass at launch**, and it waits ~1.5 s (`notificationSettleProvider`)
  for the first screen to load and animate — unless a notification tap
  launched the app, which is served at once. Settings that plan nothing
  (theme, layout, backup …) and the permission *first loading* do not
  trigger a re-plan; `ReconcilingNotificationEngine._notPlanned` lists the
  former (everything else, new settings included, does).
* **A launch renews only what Android dropped.** Every Android schedule call
  of flutter_local_notifications re-reads and re-writes the plugin's whole
  stored list on the platform thread — the thread that also delivers touches
  and frame callbacks — so re-sending N requests (up to 240) at every launch
  was N × N work right while the user started to scroll: the "laggy first
  seconds". Now only the requests without a live alarm are re-sent (see
  *When the app is killed*); `ReconcileResult`, the ledger and "Missed"
  catch-up are unchanged.
* **Shared live queries:** `watchComputed(shareKey: …)` lets subscribers with
  the same parameters (Home, the library counts and the planner all read
  today's habits) share one computation.
* Auto backups encode, hash, seal and zip on their own isolate.

## Visual effects (low-end phones)
Settings › Appearance › **Visual effects**: *Automatic* (default), *Full*,
*Reduced* (`AppSettings.performanceMode`, kept out of backups — it describes
this phone). Reduced drops the effects that cost a weak GPU the most:
* the **tab bar's live blur** becomes a plain, more opaque glass;
* a tapped card no longer **grows into its page** (a plain slide instead);
* **shimmer** placeholders are still.
Automatic follows `DevicePerformance` (read once at start-up, in parallel
with the other reads): Android "low RAM" flag, ≤ 3 GB installed memory or
Android older than 8.0 ⇒ reduced; anything unknown ⇒ full; iOS ⇒ full. The
design system reads it through `FFEffects` (provided in `app.dart`).
Month-grid swipes in the Calendar also got their own repaint layer, so the
animation moves one cached picture instead of repainting 42 cells per frame.

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

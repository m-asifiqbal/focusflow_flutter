package com.iqballab.focusflow.guard

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.text.format.DateUtils
import android.util.Log
import com.gdelataillade.alarm.alarm.AlarmReceiver
import com.gdelataillade.alarm.alarm.AlarmService
import com.gdelataillade.alarm.models.AlarmEventCause
import com.gdelataillade.alarm.models.AlarmEventVerb
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.models.HostAlarmEvent
import com.gdelataillade.alarm.services.AlarmScheduler
import com.gdelataillade.alarm.services.AlarmStorage

/**
 * The alarm guard: keeps FocusFlow's process alive, and its alarms armed,
 * while something is due — so reminders and alarms still go off after the app
 * has been swiped out of the recent-apps list.
 *
 * What it layers (the alarms themselves stay `AlarmManager` entries — the only
 * API that fires at the exact minute with the app not running, and in Doze):
 *   1. [AlarmGuardService] — a sticky foreground service with a quiet
 *      notification. A process that hosts one is the last thing phone makers'
 *      task killers and memory cleaners go for, and Android restarts it if it
 *      is killed anyway.
 *   2. A watchdog — an exact `AlarmManager` alarm every [WATCHDOG_MS] (and
 *      [REVIVE_SOON_MS] after a swipe) that restarts the service if it is
 *      gone, and re-arms what the system dropped. Exact alarms may start a
 *      foreground service from the background, which a WorkManager job may not.
 *   3. [AlarmGuardReceiver] — brings the guard back after a reboot or an app
 *      update (both stop it).
 *   4. [verifyAlarms] / [healNotifications] — the self-repair: every alarm the
 *      `alarm` plugin has stored is checked against `AlarmManager`, and the
 *      scheduled notifications of flutter_local_notifications are re-armed,
 *      exactly the way those plugins do after a reboot.
 *
 * What it cannot do: survive a *force-stop*. Some phone makers (Xiaomi, Oppo,
 * Vivo, Huawei, some Samsung modes) treat a swipe from the recents list as a
 * force-stop unless the user allowed auto-start for the app; Android then
 * removes the process, its services and all its alarms, and nothing — no
 * service, no WorkManager job — runs until the app is opened again. The app
 * asks for that permission (Settings › Notifications); on next start the
 * notification engine re-arms everything and shows what was missed.
 *
 * Depends on `alarm` 5.15 internals (AlarmStorage, AlarmScheduler,
 * AlarmService), like AlarmActivity does: re-check when that plugin is
 * upgraded.
 *
 * State lives in the app's own preferences, written by the notification
 * engine through the `syncAlarmGuard` channel call (Dart: core/notifications/
 * alarm_guard.dart), so every receiver can read it with no Flutter engine.
 */
object AlarmGuard {
    private const val TAG = "AlarmGuard"

    private const val PREFS = "focusflow_alarm_guard"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PENDING = "pending"
    private const val KEY_NEXT = "next_at"
    private const val KEY_LAST = "last_at"
    private const val KEY_SYNCED = "synced_at"
    private const val KEY_HEALED = "notifications_healed_at"

    const val ACTION_WATCHDOG = "com.iqballab.focusflow.guard.WATCHDOG"

    /** Watchdog extra: the app was just swiped away — do a full repair. */
    const val EXTRA_FULL = "full"
    private const val REQUEST_WATCHDOG = 0x6a11

    /** Period of the watchdog while the guard runs. */
    const val WATCHDOG_MS = 15 * 60 * 1000L

    /** The watchdog's look after a swipe, in case the process is killed. */
    const val REVIVE_SOON_MS = 20 * 1000L

    /** How long past the last known due time the guard keeps running. */
    private const val GRACE_MS = 3 * 60 * 60 * 1000L

    /**
     * An alarm this far past its time without ringing was lost. Younger ones
     * are in flight (AlarmManager → receiver → service takes about a second),
     * and re-delivering one that is ringing would make the service silence it.
     */
    private const val LOST_AFTER_MS = 30 * 1000L

    /** The scheduled notifications are re-armed at most this often. */
    private const val HEAL_NOTIFICATIONS_EVERY_MS = 6 * 60 * 60 * 1000L

    private const val FLN_BOOT_RECEIVER =
        "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    private const val ACTION_QUICKBOOT = "android.intent.action.QUICKBOOT_POWERON"

    /** What the notification engine last told us (see the file comment). */
    data class State(
        val enabled: Boolean,
        /** Reminders, alarms and task alerts the OS holds. */
        val pending: Int,
        /** Epoch ms of the soonest / the latest of them; 0 = none. */
        val nextAt: Long,
        val lastAt: Long,
        val syncedAt: Long,
    )

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun state(context: Context): State {
        val p = prefs(context)
        return State(
            enabled = p.getBoolean(KEY_ENABLED, true),
            pending = p.getInt(KEY_PENDING, 0),
            nextAt = p.getLong(KEY_NEXT, 0L),
            lastAt = p.getLong(KEY_LAST, 0L),
            syncedAt = p.getLong(KEY_SYNCED, 0L),
        )
    }

    /**
     * The notification engine's report after each pass (and when the setting
     * changes): remember it, then start or stop the guard accordingly.
     */
    fun sync(context: Context, enabled: Boolean, pending: Int, nextAt: Long, lastAt: Long) {
        val app = context.applicationContext
        prefs(app).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putInt(KEY_PENDING, pending)
            .putLong(KEY_NEXT, nextAt)
            .putLong(KEY_LAST, lastAt)
            .putLong(KEY_SYNCED, System.currentTimeMillis())
            .apply()
        if (enabled && pending > 0) {
            // Refused when the app is already in the background (Android 12+):
            // the watchdog, which may start it from an exact alarm, retries.
            if (!start(app, AlarmGuardService.ACTION_SYNC)) {
                armWatchdog(app, 5_000L, full = false)
            }
        } else {
            stop(app)
        }
    }

    /**
     * Whether the guard has anything to guard. Reads the alarm plugin's
     * storage (disk): never call it on the main thread.
     */
    fun wanted(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val s = state(context)
        if (!s.enabled) return false
        if (s.pending > 0 && maxOf(s.lastAt, s.syncedAt) + GRACE_MS > now) return true
        return try {
            AlarmStorage(context).getSavedAlarms().any {
                it.dateTime.time + minOf(it.androidStaleAfterMillis ?: GRACE_MS, GRACE_MS) > now
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not read the stored alarms", e)
            false
        }
    }

    /** The soonest thing due, from the engine's report and the alarm store; 0 = none. */
    fun nextAt(context: Context, now: Long = System.currentTimeMillis()): Long {
        var next = state(context).nextAt.takeIf { it > now } ?: 0L
        try {
            for (alarm in AlarmStorage(context).getSavedAlarms()) {
                val at = alarm.dateTime.time
                if (at > now && (next == 0L || at < next)) next = at
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not read the stored alarms", e)
        }
        return next
    }

    /** The ongoing notification's line, from the engine's report only (no disk). */
    fun noticeText(
        context: Context,
        at: Long = state(context).nextAt,
        now: Long = System.currentTimeMillis(),
    ): String = if (at > now) "Next: ${format(context, at, now)}" else "Watching for your next alarm"

    /** "7:30 AM", "Tue 7:30 AM" within the week, "Oct 21, 7:30 AM" beyond. */
    private fun format(context: Context, at: Long, now: Long): String {
        val day = when {
            DateUtils.isToday(at) -> 0
            at - now < 6 * DateUtils.DAY_IN_MILLIS ->
                DateUtils.FORMAT_SHOW_WEEKDAY or DateUtils.FORMAT_ABBREV_WEEKDAY
            else -> DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH
        }
        return DateUtils.formatDateTime(context, at, DateUtils.FORMAT_SHOW_TIME or day)
    }

    // ── service + watchdog ──────────────────────────────────────────────

    /** Starts the service with [action]; false when the platform refuses. */
    fun start(context: Context, action: String): Boolean {
        return try {
            val intent = Intent(context, AlarmGuardService::class.java).setAction(action)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException (Android 12+) when the
            // app is in the background, SecurityException on an odd ROM.
            Log.w(TAG, "The guard could not be started: ${e.message}")
            false
        }
    }

    fun stop(context: Context) {
        cancelWatchdog(context)
        try {
            context.stopService(Intent(context, AlarmGuardService::class.java))
        } catch (e: Exception) {
            Log.w(TAG, "The guard could not be stopped: ${e.message}")
        }
    }

    private fun watchdogIntent(context: Context, full: Boolean): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_WATCHDOG,
            Intent(context, AlarmGuardReceiver::class.java)
                .setAction(ACTION_WATCHDOG)
                .putExtra(EXTRA_FULL, full),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /**
     * Arms the watchdog [afterMs] from now (replacing the previous one). Exact
     * and allowed in Doze, so the receiver may start the foreground service;
     * inexact only where the system withholds the exact-alarm permission.
     */
    fun armWatchdog(context: Context, afterMs: Long, full: Boolean) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val at = SystemClock.elapsedRealtime() + afterMs
        val pending = watchdogIntent(context, full)
        try {
            val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
            if (exact) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pending)
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pending)
            }
        } catch (e: Exception) {
            Log.w(TAG, "The watchdog could not be armed: ${e.message}")
        }
    }

    fun cancelWatchdog(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        try {
            alarms.cancel(watchdogIntent(context, full = false))
        } catch (e: Exception) {
            Log.w(TAG, "The watchdog could not be cancelled: ${e.message}")
        }
    }

    // ── self-repair (worker thread only: it reads and writes the alarm store) ──

    /**
     * Makes the alarm plugin's stored alarms and `AlarmManager` agree.
     *
     * [rearmAll]: the process was dead or the app was swiped away, so assume
     * nothing is armed; otherwise only an alarm without a live `PendingIntent`
     * is re-armed (an `AlarmManager` entry holds that record, so no record
     * means no alarm).
     *
     * [handleOverdue]: an alarm that passed its time without ringing is
     * rung now (as the plugin does after a reboot) or, when older than its
     * stale window, discarded so the app reports it as missed. Off for the
     * start after a reboot or update, which the plugin's own receiver handles.
     * Alarms that are ringing, queued, or only just due are never touched:
     * delivering one again would make the alarm service silence it.
     */
    fun verifyAlarms(context: Context, rearmAll: Boolean, handleOverdue: Boolean) {
        val storage = AlarmStorage(context)
        val now = System.currentTimeMillis()
        val busy = AlarmService.ringingAlarmIds + AlarmService.queuedAlarmIds
        for (alarm in storage.getSavedAlarms()) {
            try {
                if (alarm.id in busy) continue
                val late = now - alarm.dateTime.time
                when {
                    late <= 0 ->
                        if (rearmAll || !isArmed(context, alarm.id)) {
                            val armed = AlarmScheduler.schedule(context, alarm)
                            Log.i(TAG, "Re-armed alarm ${alarm.id}: $armed")
                        }
                    late <= LOST_AFTER_MS || !handleOverdue -> Unit
                    isStale(alarm, now) -> discard(storage, alarm, now)
                    else -> {
                        Log.i(TAG, "Alarm ${alarm.id} never rang; ringing it now")
                        AlarmScheduler.schedule(context, alarm)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not check alarm ${alarm.id}", e)
            }
        }
    }

    private fun isArmed(context: Context, id: Int): Boolean =
        PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, AlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) != null

    private fun isStale(alarm: AlarmSettings, now: Long): Boolean {
        val after = alarm.androidStaleAfterMillis ?: return false
        return now - alarm.dateTime.time > after
    }

    /** Same record the plugin writes for a stale alarm at boot (see its BootReceiver). */
    private fun discard(storage: AlarmStorage, alarm: AlarmSettings, now: Long) {
        storage.saveAlarmEvent(
            HostAlarmEvent(
                alarmId = alarm.id,
                verb = AlarmEventVerb.DROPPED,
                cause = AlarmEventCause.STALE_AT_BOOT,
                atMillis = alarm.dateTime.time,
                recordedAtMillis = now,
            ),
        )
        storage.unsaveAlarm(alarm.id)
        Log.i(TAG, "Alarm ${alarm.id} was too late to ring; discarded")
    }

    fun notificationsHealDue(context: Context, now: Long = System.currentTimeMillis()): Boolean =
        now - prefs(context).getLong(KEY_HEALED, 0L) > HEAL_NOTIFICATIONS_EVERY_MS

    /**
     * Re-arms every scheduled notification (flutter_local_notifications keeps
     * them in its own storage and re-arms them after a reboot). Runs that
     * receiver's code directly rather than broadcasting to it: a broadcast of
     * a boot action is refused for apps, and the plugin's receiver is public.
     * Past-due ones that never showed fire straight away; delivered ones are
     * gone from the plugin's list, so nothing shows twice.
     */
    fun healNotifications(context: Context) {
        try {
            val receiver = Class.forName(FLN_BOOT_RECEIVER)
                .getDeclaredConstructor()
                .newInstance() as BroadcastReceiver
            receiver.onReceive(context, Intent(ACTION_QUICKBOOT))
            prefs(context).edit().putLong(KEY_HEALED, System.currentTimeMillis()).apply()
        } catch (e: Throwable) {
            Log.w(TAG, "Could not re-arm the scheduled notifications", e)
        }
    }
}

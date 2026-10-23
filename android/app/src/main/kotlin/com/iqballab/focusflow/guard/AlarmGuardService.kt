package com.iqballab.focusflow.guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.iqballab.focusflow.R
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * The foreground half of the alarm guard (see [AlarmGuard]).
 *
 * Runs while reminders or alarms are due and the user has not switched
 * "Keep alarms running" off. It owns nothing that rings — `AlarmManager`
 * fires the alarms and the `alarm` plugin's own service plays them — it only
 * keeps this process alive and re-arms what the system dropped. Each start
 * promotes it to the foreground first (a service started with
 * `startForegroundService` must, within seconds), then checks on a worker
 * thread whether anything is left to guard; if not it stops itself.
 *
 * Start actions:
 *  - [ACTION_SYNC]: the app reported its schedule (the app is in front).
 *  - [ACTION_TICK]: the watchdog fired and this service is alive.
 *  - [ACTION_HEAL]: the service was gone and has been revived (watchdog, or
 *    the system restarting it: a null intent), or the app was just swiped
 *    away — assume the alarms may be gone and re-arm everything.
 *  - [ACTION_BOOT]: after a reboot / update; the plugins' own receivers
 *    re-arm the alarms, this only brings the guard itself back.
 *  - [ACTION_STOP]: stop now. Used instead of `stopService` while a
 *    `startForegroundService` is still on its way ([startPending]): a service
 *    stopped before it called `startForeground` makes Android kill the whole
 *    app ("did not then call Service.startForeground()", Android 8–11) — the
 *    restore crash, where the engine starts the guard for the restored
 *    reminders and the restored settings stop it a moment later.
 */
class AlarmGuardService : Service() {
    companion object {
        private const val TAG = "AlarmGuardService"

        const val ACTION_SYNC = "com.iqballab.focusflow.guard.SYNC"
        const val ACTION_TICK = "com.iqballab.focusflow.guard.TICK"
        const val ACTION_HEAL = "com.iqballab.focusflow.guard.HEAL"
        const val ACTION_BOOT = "com.iqballab.focusflow.guard.BOOT"
        const val ACTION_STOP = "com.iqballab.focusflow.guard.STOP"

        private const val CHANNEL_ID = "focusflow_alarm_guard"
        private const val NOTIFICATION_ID = 9_410_117

        /** Whether the service is alive in this process (Settings reads it). */
        @Volatile
        var running = false
            private set

        /** `startForegroundService` calls not yet answered by [promote]. */
        private val pendingStarts = AtomicInteger(0)

        /** A start is on its way: the service must not be stopped from outside. */
        val startPending: Boolean
            get() = pendingStarts.get() > 0

        /** [AlarmGuard.start] is about to call `startForegroundService`. */
        fun noteStartRequested() {
            pendingStarts.incrementAndGet()
        }

        /** A start was answered by onStartCommand, or refused (exception). */
        fun noteStartDone() {
            pendingStarts.updateAndGet { if (it > 0) it - 1 else 0 }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private var shownText: String? = null

    override fun onCreate() {
        super.onCreate()
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val promoted = promote()
        noteStartDone() // this start is answered (either way)
        if (!promoted) {
            stopSelf()
            return START_NOT_STICKY
        }
        // A null intent is the system restarting a sticky service it killed.
        val action = intent?.action ?: ACTION_HEAL
        if (action == ACTION_STOP) {
            // Foreground now, so stopping is safe.
            shutdown()
            return START_NOT_STICKY
        }
        try {
            worker.execute {
                try {
                    evaluate(action)
                } catch (e: Throwable) {
                    Log.e(TAG, "The guard check failed", e)
                }
            }
        } catch (e: Exception) {
            // The executor is gone: the service is being destroyed.
            Log.w(TAG, "The guard check was refused: ${e.message}")
        }
        return START_STICKY
    }

    /** Off the main thread: reads and writes the alarm store. */
    private fun evaluate(action: String) {
        val app = applicationContext
        if (!AlarmGuard.wanted(app)) {
            main.post { shutdown() }
            return
        }
        when (action) {
            ACTION_HEAL -> {
                AlarmGuard.verifyAlarms(app, rearmAll = true, handleOverdue = true)
                AlarmGuard.healNotifications(app)
            }
            // After a reboot / update the plugins' own receivers handle what
            // is overdue; while the app is in front (SYNC) its notification
            // engine does (it lists lost alarms as "Missed"). Either way the
            // guard must not ring or discard the same alarm a second time.
            ACTION_BOOT, ACTION_SYNC ->
                AlarmGuard.verifyAlarms(app, rearmAll = false, handleOverdue = false)
            else -> {
                AlarmGuard.verifyAlarms(app, rearmAll = false, handleOverdue = true)
                if (AlarmGuard.notificationsHealDue(app)) AlarmGuard.healNotifications(app)
            }
        }
        val text = AlarmGuard.noticeText(app, AlarmGuard.nextAt(app))
        main.post { showText(text) }
        AlarmGuard.armWatchdog(app, AlarmGuard.WATCHDOG_MS, full = false)
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // The app was swiped away. Some phones kill the process a moment later
        // (and this service with it); the watchdog then restarts it from a
        // fresh process and re-arms everything. If we survive, it just asks
        // this service for the same repair.
        AlarmGuard.armWatchdog(applicationContext, AlarmGuard.REVIVE_SOON_MS, full = true)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        worker.shutdownNow()
        main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun shutdown() {
        AlarmGuard.cancelWatchdog(applicationContext)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    // ── the quiet notification ──────────────────────────────────────────

    /** Foreground right away, with the last known text. False when refused. */
    private fun promote(): Boolean {
        createChannel()
        val text = shownText ?: AlarmGuard.noticeText(this)
        val notification = notification(text)
        return try {
            enterForeground(notification)
            shownText = text
            true
        } catch (e: Exception) {
            // Not allowed from here (background start on Android 12+), or the
            // type was refused. Without it the service cannot stay up.
            Log.w(TAG, "The guard could not enter the foreground: ${e.message}")
            false
        }
    }

    private fun enterForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun showText(text: String) {
        if (text == shownText) return
        shownText = text
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification(text))
        } catch (e: Exception) {
            Log.w(TAG, "The guard notification could not be updated: ${e.message}")
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Alarm protection",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "A quiet notification while FocusFlow keeps your alarms " +
                "and reminders on time after the app is closed."
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_SECRET
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    private fun notification(text: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Keeping your alarms on time")
            .setContentText(text)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_SECRET)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
        open?.let { builder.setContentIntent(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }
}

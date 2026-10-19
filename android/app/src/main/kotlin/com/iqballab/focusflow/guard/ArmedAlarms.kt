package com.iqballab.focusflow.guard

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.gdelataillade.alarm.alarm.AlarmReceiver

/**
 * Which of the app's scheduled notifications / alarms the OS really holds.
 *
 * Why: at every launch the notification engine used to hand *every* planned
 * request to the OS again, in case Android had dropped them (it does after a
 * force-stop). flutter_local_notifications answers each such call by
 * re-reading and re-writing its whole stored list on the platform thread —
 * the one that also delivers touches and frame callbacks — so N requests cost
 * N × N work, and the app stuttered for seconds after opening, worst when the
 * list is long. Asking first which ones are still armed makes a healthy
 * launch send nothing; after a force-stop none is armed and everything is
 * re-sent, exactly as before.
 *
 * How: an `AlarmManager` entry holds its `PendingIntent`, and Android drops
 * every `PendingIntent` of a force-stopped app, so "a PendingIntent for this
 * request code exists" (`FLAG_NO_CREATE` returns null otherwise) means the
 * alarm is armed. flutter_local_notifications arms request code = notification
 * id on its `ScheduledNotificationReceiver`; the `alarm` plugin arms its alarm
 * id on `AlarmReceiver` (alarm-style reminders use the same ids).
 */
object ArmedAlarms {
    private const val FLN_RECEIVER =
        "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"

    /** The subset of [ids] that has a live alarm of either kind. */
    fun armed(context: Context, ids: Collection<Int>): List<Int> {
        val app = context.applicationContext
        val notifications = ComponentName(app.packageName, FLN_RECEIVER)
        val alarms = ComponentName(app, AlarmReceiver::class.java)
        return ids.filter { id -> exists(app, id, notifications) || exists(app, id, alarms) }
    }

    private fun exists(context: Context, id: Int, receiver: ComponentName): Boolean =
        PendingIntent.getBroadcast(
            context,
            id,
            Intent().setComponent(receiver),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) != null
}

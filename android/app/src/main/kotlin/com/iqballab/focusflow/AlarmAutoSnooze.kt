package com.iqballab.focusflow

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.gdelataillade.alarm.alarm.AlarmService
import com.gdelataillade.alarm.services.SnoozeCoordinator

/**
 * Snoozes a ringing alarm by itself when nobody reacts for [RING_LIMIT_MS]
 * (2 minutes): the same snooze the Snooze button does (the `alarm` package's
 * [SnoozeCoordinator] — re-arms the alarm for its own snooze length, silences
 * the ring, and tells Dart if it is running), so the alarm is never lost and
 * never rings for good in an empty room.
 *
 * Lives next to the process, not the alarm screen: the foreground service
 * that rings keeps the process alive, and no Flutter engine or open screen
 * is needed. Started by [FocusFlowApplication] when an alarm starts ringing;
 * it checks every few seconds while something rings and stops by itself when
 * nothing does. Each ring is timed on its own: a snoozed alarm that rings
 * again gets a fresh 2 minutes, an alarm the user stopped or snoozed is
 * forgotten. An alarm that has no snooze is left ringing (the coordinator
 * refuses it) and tried only once.
 */
class AlarmAutoSnooze(
    private val context: Context,
    private val ringingIds: () -> List<Int> = { AlarmService.ringingAlarmIds },
    private val snooze: (Int) -> Boolean = { SnoozeCoordinator.snooze(context, it) },
    private val clock: () -> Long = { SystemClock.elapsedRealtime() },
    private val handler: Handler = Handler(Looper.getMainLooper()),
) {
    /** alarm id → when this ring was first seen; null once auto-snooze was tried. */
    private val rings = HashMap<Int, Long?>()
    private var scheduled = false

    /** The service lists an alarm as ringing a moment after the "ringing" signal. */
    private var waitForRingUntil = 0L

    private val tick = Runnable {
        scheduled = false
        check()
        if (rings.isNotEmpty() || clock() < waitForRingUntil) schedule()
    }

    /** An alarm may be ringing: start watching. Safe to call repeatedly. */
    fun start() {
        waitForRingUntil = clock() + STARTUP_WAIT_MS
        check()
        if (!scheduled) schedule()
    }

    private fun schedule() {
        scheduled = true
        handler.postDelayed(tick, CHECK_EVERY_MS)
    }

    /** One pass: note new rings, forget finished ones, snooze the overdue. */
    internal fun check() {
        val now = clock()
        val ringing = ringingIds().toSet()
        rings.keys.retainAll(ringing)
        for (id in ringing) {
            if (!rings.containsKey(id)) rings[id] = now
        }
        for (id in ringing) {
            val since = rings[id] ?: continue
            if (now - since < RING_LIMIT_MS) continue
            // Once only: a refused snooze (no snooze configured) is not retried.
            rings[id] = null
            val done = try {
                snooze(id)
            } catch (e: Exception) {
                Log.w(TAG, "Auto-snooze of alarm $id failed: ${e.message}")
                false
            }
            Log.d(TAG, "Alarm $id rang ${RING_LIMIT_MS / 1000} s unanswered; snoozed=$done")
        }
    }

    companion object {
        private const val TAG = "AlarmAutoSnooze"

        /** Ringing without any action for this long snoozes the alarm. */
        const val RING_LIMIT_MS = 2 * 60 * 1000L

        /** How long to look for the ringing alarm after the signal. */
        private const val STARTUP_WAIT_MS = 30_000L

        /** How often a ringing alarm is checked. */
        const val CHECK_EVERY_MS = 5_000L
    }
}

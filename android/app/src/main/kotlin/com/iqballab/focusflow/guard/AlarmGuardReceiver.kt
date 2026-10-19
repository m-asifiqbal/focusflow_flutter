package com.iqballab.focusflow.guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Brings the alarm guard back (see [AlarmGuard]):
 *  - after a reboot or an app update, which stop its service;
 *  - when its watchdog alarm fires: the service is restarted if it is gone,
 *    or asked for its periodic check if it is alive.
 *
 * An exact alarm (the watchdog) and these system broadcasts are all allowed
 * to start a foreground service from the background, so the service can come
 * back with the app not running. The work is off the main thread: whether
 * anything is left to guard is read from the alarm plugin's disk store.
 */
class AlarmGuardReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> AlarmGuardService.ACTION_BOOT

            AlarmGuard.ACTION_WATCHDOG ->
                if (!AlarmGuardService.running || intent.getBooleanExtra(AlarmGuard.EXTRA_FULL, false)) {
                    AlarmGuardService.ACTION_HEAL
                } else {
                    AlarmGuardService.ACTION_TICK
                }

            else -> return
        }
        val app = context.applicationContext
        val pending = goAsync()
        Thread {
            try {
                if (AlarmGuard.wanted(app)) {
                    AlarmGuard.start(app, action)
                } else {
                    AlarmGuard.cancelWatchdog(app)
                }
            } catch (e: Throwable) {
                Log.e("AlarmGuardReceiver", "The guard could not be resumed", e)
            } finally {
                pending.finish()
            }
        }.start()
    }
}

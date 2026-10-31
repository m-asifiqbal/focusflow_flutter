package com.iqballab.focusflow.widget

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import com.iqballab.focusflow.MainActivity
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.fluttercommunity.workmanager.buildTaskInputData

/**
 * What a tap on a widget row, circle or button does. An invisible activity
 * (the PendingIntents of a collection widget can only be activities or
 * broadcasts, and only an activity may open the app): it finishes at once.
 *
 *  * [OP_OPEN]  → opens the app at a route (an item, a list, an editor);
 *  * [OP_DO]    → completes the item right from the home screen: shows the
 *    change at once in the widget, then hands the real work to the app's
 *    Dart code through its own WorkManager task (the encrypted database
 *    belongs to Dart). If the task cannot be queued the app opens instead.
 */
class WidgetActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            when (intent.getStringExtra(EXTRA_OP) ?: OP_OPEN) {
                OP_DO -> if (!complete(intent)) openApp(this, intent.getStringExtra(EXTRA_ROUTE))
                else -> openApp(this, intent.getStringExtra(EXTRA_ROUTE))
            }
        } catch (e: Exception) {
            Log.w(TAG, "Widget action failed: ${e.message}")
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    private fun complete(i: Intent): Boolean {
        val section = i.getStringExtra(EXTRA_SECTION) ?: return false
        val id = i.getStringExtra(EXTRA_ID)?.takeIf { it.isNotEmpty() } ?: return false
        val day = i.getStringExtra(EXTRA_DAY).orEmpty()
        val minutes = i.getIntExtra(EXTRA_MIN, -1)
        val payload = HashMap<String, Any?>()
        payload["id"] = id
        when (section) {
            "tasks" -> { payload["action"] = "complete"; payload["kind"] = "task" }
            "reminders" -> { payload["action"] = "complete"; payload["kind"] = "reminder" }
            "habits" -> payload["action"] = "checkin"
            "medicines" -> {
                if (day.isEmpty() || minutes < 0) return false
                payload["action"] = "take"; payload["day"] = day; payload["min"] = minutes
            }
            else -> return false
        }
        val work = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
            .setInputData(buildTaskInputData(DART_TASK, payload))
            .build()
        // Habits may be tapped again and again (8 glasses): queue them in
        // order; everything else once.
        val policy = if (section == "habits") ExistingWorkPolicy.APPEND_OR_REPLACE else ExistingWorkPolicy.KEEP
        WorkManager.getInstance(applicationContext)
            .enqueueUniqueWork("ffw:$section:$id:$day:$minutes", policy, work)
        // Only now show it done: the change is on its way.
        WidgetStore.markDone(applicationContext, section, id, day, minutes)
        WidgetRenderer.updateAll(applicationContext)
        return true
    }

    companion object {
        private const val TAG = "FFWidget"
        const val ACTION_OPEN = "com.iqballab.focusflow.widget.OPEN"
        const val EXTRA_OP = "ff.op"
        const val OP_OPEN = "open"
        const val OP_DO = "do"
        const val EXTRA_ROUTE = "ff.route"
        const val EXTRA_SECTION = "ff.section"
        const val EXTRA_ID = "ff.id"
        const val EXTRA_DAY = "ff.day"
        const val EXTRA_MIN = "ff.min"

        /** Same values as MainActivity (its constants are private): a launcher shortcut. */
        private const val SHORTCUT_ACTION = "com.iqballab.focusflow.action.SHORTCUT"
        private const val SHORTCUT_EXTRA = "shortcut"

        /** The workmanager task name Dart handles (BackgroundTasks.widgetActionTask). */
        private const val DART_TASK = "com.iqballab.focusflow.widgetAction"

        /** Opens the app, at [route] when it is one. */
        fun openApp(c: Context, route: String?) {
            val i = Intent(c, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            if (!route.isNullOrEmpty()) {
                i.setAction(SHORTCUT_ACTION)
                    .putExtra(SHORTCUT_EXTRA, "route:$route")
            }
            c.startActivity(i)
        }
    }
}

package com.iqballab.focusflow

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextClock
import android.widget.TextView
import androidx.lifecycle.Observer
import com.gdelataillade.alarm.alarm.AlarmService
import com.gdelataillade.alarm.services.AlarmRingingLiveData
import com.gdelataillade.alarm.services.AlarmStorage
import java.util.Date

/**
 * The alarm screen: shown over the lock screen when an alarm rings (the
 * `alarm` package opens whichever activity handles
 * `com.gdelataillade.alarm.action.RING`, for the full-screen intent and for a
 * tap on the notification). Native on purpose — a full-screen intent starts
 * the process *without* a Flutter engine, so this must not wait for Dart:
 * time, title, a big **Stop** and a **Snooze** (when the alarm has one).
 *
 * Both buttons broadcast to the plugin's receiver, which does the real work
 * (silences / re-arms the alarm and tells Dart if it is running). The screen
 * closes by itself when no alarm rings any more (stopped from the
 * notification, audio finished, …). Back just leaves the screen: the alarm
 * keeps ringing and the notification keeps its buttons.
 *
 * Extras (from the plugin): alarmId, alarmTitle, alarmBody, alarmStopLabel,
 * alarmSnoozeLabel (null = this alarm cannot snooze).
 */
class AlarmActivity : Activity() {
    private var alarmId = 0
    private val ringing = Observer<Boolean> { isRinging ->
        // The flag is sticky: a screen opened a moment before the service
        // marks the new ring would otherwise see the previous alarm's "false".
        if (isRinging == false && AlarmService.ringingAlarmIds.isEmpty()) finish()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        render(intent)
        AlarmRingingLiveData.instance.observeForever(ringing)
    }

    /** A second alarm while this one is up (singleInstance) refreshes it. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        render(intent)
    }

    override fun onDestroy() {
        AlarmRingingLiveData.instance.removeObserver(ringing)
        super.onDestroy()
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    private fun render(intent: Intent) {
        alarmId = intent.getIntExtra("alarmId", 0)
        val title = intent.getStringExtra("alarmTitle").orEmpty()
        val body = intent.getStringExtra("alarmBody").orEmpty()
        val stopLabel = intent.getStringExtra("alarmStopLabel") ?: "Stop"
        val snoozeLabel = intent.getStringExtra("alarmSnoozeLabel")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(28), dp(72), dp(28), dp(40))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#0B3B2F"), Color.parseColor("#06231C"))
            )
        }

        root.addView(text("Alarm", 14f, Color.parseColor("#6EE7B7"), bold = true))
        root.addView(
            TextClock(this).apply {
                format12Hour = "h:mm"
                format24Hour = "HH:mm"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 72f)
                setTextColor(Color.WHITE)
                typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
                gravity = Gravity.CENTER
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(8) }
        )
        if (title.isNotBlank()) {
            root.addView(
                text(title, 26f, Color.WHITE, bold = true, maxLines = 3),
                top(dp(28))
            )
        }
        if (body.isNotBlank()) {
            root.addView(
                text(body, 16f, Color.parseColor("#A7F3D0"), maxLines = 4),
                top(dp(10))
            )
        }

        // Pushes the buttons to the bottom thumb zone.
        root.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))

        if (snoozeLabel != null) {
            root.addView(
                button(snoozeLabel, filled = false) { act(ACTION_SNOOZE) },
                bottom(dp(14))
            )
        }
        root.addView(
            button(stopLabel, filled = true) { act(ACTION_STOP) },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(64)
            )
        )
        setContentView(root)
    }

    /** Tells the plugin what the user chose, then leaves the screen. */
    private fun act(action: String) {
        sendBroadcast(
            Intent()
                .setClassName(packageName, RECEIVER)
                .setAction(action)
                .putExtra("id", alarmId)
        )
        finish()
    }

    private fun text(
        value: String,
        sp: Float,
        color: Int,
        bold: Boolean = false,
        maxLines: Int = 1
    ) = TextView(this).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(color)
        gravity = Gravity.CENTER
        this.maxLines = maxLines
        if (bold) typeface = Typeface.DEFAULT_BOLD
    }

    private fun button(label: String, filled: Boolean, onClick: () -> Unit) =
        Button(this).apply {
            text = label
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(if (filled) Color.parseColor("#06231C") else Color.WHITE)
            background = GradientDrawable().apply {
                cornerRadius = dp(32).toFloat()
                if (filled) {
                    setColor(Color.parseColor("#34D399"))
                } else {
                    setColor(Color.TRANSPARENT)
                    setStroke(dp(2), Color.parseColor("#80FFFFFF"))
                }
            }
            minHeight = dp(56)
            setOnClickListener { onClick() }
        }

    private fun top(px: Int) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ).apply { topMargin = px }

    private fun bottom(px: Int) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        dp(56)
    ).apply { bottomMargin = px }

    private fun dp(value: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics
    ).toInt()

    companion object {
        private const val RECEIVER = "com.gdelataillade.alarm.alarm.AlarmReceiver"
        private const val ACTION_STOP = "com.gdelataillade.alarm.ACTION_STOP"
        private const val ACTION_SNOOZE = "com.gdelataillade.alarm.ACTION_SNOOZE"

        /**
         * Whether this app may open a screen over whatever is in front.
         * Android 10+ only allows that from the background with "Display over
         * other apps"; before that it is always allowed.
         */
        fun canShowOverApps(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || Settings.canDrawOverlays(context)

        /**
         * An alarm has just started ringing: put its screen in front of
         * whatever the user is doing. Without "Display over other apps" this
         * does nothing (Android would refuse) and the full-screen intent /
         * the notification's heads-up stay the only way in.
         */
        fun bringToFront(context: Context) {
            if (!canShowOverApps(context)) return
            try {
                val now = Date()
                val saved = AlarmStorage(context).getSavedAlarms()
                // The service marks the ring a moment before its audio counts
                // as playing: fall back to the most recent alarm that is due.
                val id = AlarmService.ringingAlarmIds.firstOrNull()
                    ?: saved.filter { !it.dateTime.after(now) }
                        .maxByOrNull { it.dateTime }?.id
                    ?: return
                val alarm = saved.firstOrNull { it.id == id }
                show(
                    context,
                    id,
                    alarm?.notificationSettings?.title,
                    alarm?.notificationSettings?.body,
                    alarm?.notificationSettings?.stopButton,
                    alarm?.notificationSettings?.androidSnoozeButton
                        ?.takeIf { alarm.canSnooze }
                )
            } catch (e: Exception) {
                // The notification still rings and has its own buttons.
            }
        }

        /** Opens the screen for an alarm that is ringing while the app is open. */
        fun show(
            context: Context,
            id: Int,
            title: String?,
            body: String?,
            stopLabel: String?,
            snoozeLabel: String?
        ) {
            context.startActivity(
                Intent(context, AlarmActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .putExtra("alarmId", id)
                    .putExtra("alarmTitle", title)
                    .putExtra("alarmBody", body)
                    .putExtra("alarmStopLabel", stopLabel)
                    .putExtra("alarmSnoozeLabel", snoozeLabel)
            )
        }
    }
}

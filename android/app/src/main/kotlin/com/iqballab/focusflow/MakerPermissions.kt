package com.iqballab.focusflow

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log

/**
 * What Android itself cannot tell us about showing an alarm or a reminder on
 * the lock screen.
 *
 * Xiaomi / Redmi / POCO (MIUI, HyperOS — the Chinese ROMs in particular) add
 * two per-app permissions on top of Android's: **Show on lock screen** and
 * **Display pop-up windows while running in the background**. Both default to
 * "denied", and while they are denied the system quietly drops the
 * full-screen intent, refuses to start the alarm screen from the background
 * (even with "Display over other apps") and may keep the notification off the
 * lock screen — with every standard permission granted. They are app-ops
 * numbered by MIUI, readable with the (hidden) `checkOpNoThrow(int, …)`; on a
 * phone where that is refused the answer is "unknown" and the app still
 * points the user at the page.
 *
 * Separately, any phone: the user can switch a notification channel's
 * "Lock screen" row to *Don't show* (or block the channel) in system
 * settings, and nothing in the app notices — [blockedChannels] does.
 *
 * Plain framework calls and string reflection on framework classes only:
 * nothing here depends on app class names, so R8 cannot break it.
 */
object MakerPermissions {
    private const val TAG = "MakerPermissions"

    /** MIUI app-op: "Show on lock screen". */
    private const val OP_SHOW_WHEN_LOCKED = 10020

    /** MIUI app-op: "Display pop-up windows while running in the background". */
    private const val OP_BACKGROUND_START = 10021

    private val XIAOMI_MAKERS = setOf("xiaomi", "redmi", "poco", "blackshark")

    fun isXiaomi(): Boolean =
        Build.MANUFACTURER.lowercase() in XIAOMI_MAKERS ||
            Build.BRAND.lowercase() in XIAOMI_MAKERS

    /** True / false, or null when this phone does not answer. */
    private fun opAllowed(context: Context, op: Int): Boolean? = try {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val check = AppOpsManager::class.java.getMethod(
            "checkOpNoThrow",
            Int::class.javaPrimitiveType,
            Int::class.javaPrimitiveType,
            String::class.java
        )
        (check.invoke(ops, op, Process.myUid(), context.packageName) as Int) ==
            AppOpsManager.MODE_ALLOWED
    } catch (t: Throwable) {
        Log.w(TAG, "App-op $op unreadable: ${t.javaClass.simpleName}")
        null
    }

    /** Channels in [ids] the user turned off or hid from the lock screen. */
    private fun blockedChannels(context: Context, ids: List<String>): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return emptyList()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return ids.filter { id ->
            val c: NotificationChannel = nm.getNotificationChannel(id) ?: return@filter false
            c.importance == NotificationManager.IMPORTANCE_NONE ||
                c.lockscreenVisibility == android.app.Notification.VISIBILITY_SECRET
        }
    }

    /**
     * The answer for the Dart side: `xiaomi`, `showOnLockScreen` and
     * `backgroundPopup` (null = unknown), `blockedChannels`.
     */
    fun status(context: Context, channelIds: List<String>): Map<String, Any?> {
        val xiaomi = isXiaomi()
        return mapOf(
            "xiaomi" to xiaomi,
            "showOnLockScreen" to if (xiaomi) opAllowed(context, OP_SHOW_WHEN_LOCKED) else true,
            "backgroundPopup" to if (xiaomi) opAllowed(context, OP_BACKGROUND_START) else true,
            "blockedChannels" to blockedChannels(context, channelIds)
        )
    }

    /**
     * Opens the page that fixes [status]: MIUI's own permission editor for
     * the app (Other permissions) on a Xiaomi phone, otherwise the settings of
     * the first blocked channel, otherwise the app's notification settings.
     */
    fun openSettings(context: Context, channelId: String?): Boolean {
        val pkg = context.packageName
        val candidates = mutableListOf<Intent>()
        if (isXiaomi()) {
            for (cls in listOf(
                "com.miui.permcenter.permissions.PermissionsEditorActivity",
                "com.miui.permcenter.permissions.AppPermissionsEditorActivity"
            )) {
                candidates += Intent("miui.intent.action.APP_PERM_EDITOR")
                    .setClassName("com.miui.securitycenter", cls)
                    .putExtra("extra_pkgname", pkg)
            }
            candidates += Intent("miui.intent.action.APP_PERM_EDITOR")
                .setPackage("com.miui.securitycenter")
                .putExtra("extra_pkgname", pkg)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (channelId != null) {
                candidates += Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
            }
            candidates += Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
        }
        candidates += Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$pkg")
        )
        for (intent in candidates) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: Exception) {
                // Not this phone (not installed / not exported): try the next.
            }
        }
        return false
    }
}

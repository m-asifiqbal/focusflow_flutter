package com.iqballab.focusflow

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
import android.view.WindowManager
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import org.json.JSONObject

/**
 * FlutterFragmentActivity (not FlutterActivity) because local_auth's
 * BiometricPrompt needs a FragmentActivity.
 *
 * Hosts the `focusflow/text_scanner` channel: on-device OCR for Quick Scan
 * with ML Kit (Play-services model). iOS implements the same channel with
 * Apple Vision — see ios/Runner/TextScannerPlugin.swift.
 *
 * Alarm-style reminders (full-screen intent): the manifest deliberately does
 * NOT declare showWhenLocked / turnScreenOn (that would let any notification
 * tap open the app over the keyguard). They are switched on here only when
 * the activity is launched by an alarm-style notification
 * (flutter_local_notifications' SELECT_NOTIFICATION intent whose payload
 * category is "alarm"), and switched off again when the screen turns off,
 * the user unlocks, or the activity is opened any other way.
 *
 * Also hosts `focusflow/notifications` (canUseFullScreenIntent, Android 14+).
 */
class MainActivity : FlutterFragmentActivity() {
    private var overLockScreen = false
    private var lockReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenPolicy(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        applyLockScreenPolicy(intent)
    }

    override fun onDestroy() {
        setOverLockScreen(false)
        super.onDestroy()
    }

    /** True for the launch intent of an alarm-style notification. */
    private fun isAlarmLaunch(intent: Intent?): Boolean {
        if (intent?.action != "SELECT_NOTIFICATION") return false
        val payload = intent.getStringExtra("payload") ?: return false
        return try {
            JSONObject(payload).optString("c") == "alarm"
        } catch (e: Exception) {
            false
        }
    }

    private fun applyLockScreenPolicy(intent: Intent?) {
        setOverLockScreen(isAlarmLaunch(intent))
    }

    private fun setOverLockScreen(on: Boolean) {
        if (on == overLockScreen) return
        overLockScreen = on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
        if (on) {
            // Off again as soon as the screen goes off (next wake shows the
            // keyguard) or the user unlocks (normal app from then on).
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    setOverLockScreen(false)
                }
            }
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            lockReceiver = receiver
            val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (!keyguard.isKeyguardLocked) {
                // Already unlocked: nothing to show over.
                setOverLockScreen(false)
            }
        } else {
            lockReceiver?.let {
                try {
                    unregisterReceiver(it)
                } catch (e: IllegalArgumentException) {
                    // Already unregistered.
                }
            }
            lockReceiver = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureSecureClipboard(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusflow/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            result.success(nm.canUseFullScreenIntent())
                        } else {
                            result.success(true)
                        }
                    }
                    "openAutostartSettings" -> result.success(openAutostartSettings())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusflow/text_scanner")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeText" -> {
                        val path = call.argument<String>("path")
                        if (path == null || !File(path).exists()) {
                            result.error("bad_path", "Image not found", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                            TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                                .process(image)
                                .addOnSuccessListener { text -> result.success(text.text) }
                                .addOnFailureListener { e -> result.error("ocr_failed", e.message, null) }
                        } catch (e: Exception) {
                            result.error("ocr_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens the phone maker's "auto-start / background activity" page, the
     * switch that decides whether Android's alarms survive swiping the app
     * away on Xiaomi, Oppo, Vivo, Huawei, Samsung and friends (they treat
     * the swipe like a force-stop, which drops every scheduled alarm).
     * There is no public API for it, so each maker's own screen is tried
     * in turn (each package is declared in the manifest's `<queries>`).
     * Returns false when none exists; Dart then opens the app's info page.
     */
    private fun openAutostartSettings(): Boolean {
        for ((pkg, cls) in OEM_AUTOSTART_SCREENS) {
            try {
                startActivity(
                    Intent().setComponent(ComponentName(pkg, cls))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return true
            } catch (e: Exception) {
                // Not this phone (not installed / not exported): try the next.
            }
        }
        return false
    }

    private companion object {
        val OEM_AUTOSTART_SCREENS = listOf(
            // Xiaomi / Redmi / POCO (MIUI, HyperOS)
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            // Oppo / Realme / OnePlus (ColorOS, Realme UI)
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            // Vivo / iQOO (Funtouch, OriginOS)
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            // Huawei / Honor
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            // Samsung (Device care › Battery › Background usage limits)
            "com.samsung.android.lool" to "com.samsung.android.sm.ui.battery.BatteryActivity",
            "com.samsung.android.sm_cn" to "com.samsung.android.sm.ui.battery.BatteryActivity",
            // Asus, Letv, Nokia, Transsion (Tecno / Infinix / itel)
            "com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity",
            "com.letv.android.letvsafe" to "com.letv.android.letvsafe.AutobootManageActivity",
            "com.evenwell.powersaving.g3" to "com.evenwell.powersaving.g3.exception.PowerSaverExceptionActivity",
            "com.transsion.phonemaster" to "com.itel.autobootmanager.activity.AutoBootMgrActivity",
        )
    }

    /**
     * `focusflow/secure_clipboard` (Dart: core/crypto/secure_clipboard.dart).
     * Copied secrets are flagged sensitive so Android 13+ hides them in the
     * clipboard preview / keyboard suggestions; "clear" only wipes the clip
     * if it still holds what the vault copied (matched by SHA-256), so a
     * newer copy by the user is never erased.
     */
    private fun configureSecureClipboard(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusflow/secure_clipboard")
            .setMethodCallHandler { call, result ->
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                when (call.method) {
                    "setSensitive" -> {
                        val text = call.argument<String>("text") ?: ""
                        val clip = ClipData.newPlainText("FocusFlow", text)
                        val extras = PersistableBundle()
                        if (Build.VERSION.SDK_INT >= 33) {
                            extras.putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                        } else {
                            extras.putBoolean("android.content.extra.IS_SENSITIVE", true)
                        }
                        clip.description.extras = extras
                        clipboard.setPrimaryClip(clip)
                        result.success(null)
                    }
                    "clear" -> {
                        val expected = call.argument<String>("sha256")
                        val current = clipboard.primaryClip
                            ?.takeIf { it.itemCount > 0 }
                            ?.getItemAt(0)?.coerceToText(this)?.toString()
                        val matches = expected == null ||
                            (current != null && sha256Hex(current) == expected)
                        if (matches) {
                            if (Build.VERSION.SDK_INT >= 28) {
                                clipboard.clearPrimaryClip()
                            } else {
                                clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sha256Hex(text: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}

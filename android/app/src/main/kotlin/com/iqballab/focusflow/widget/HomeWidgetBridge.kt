package com.iqballab.focusflow.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Channel `focusflow/home_widgets` (Dart: lib/core/home_widgets/
 * home_widget_channel.dart): `push` a snapshot, `requestPin` a widget,
 * `counts` of placed widgets per kind. Every call is answered once.
 */
class HomeWidgetBridge(private val context: Context) {

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "push" -> {
                    val ok = WidgetStore.save(context, call.arguments as? String ?: "")
                    if (ok) WidgetRenderer.updateAll(context)
                    result.success(ok)
                }
                "requestPin" -> result.success(requestPin(call.arguments as? String))
                "counts" -> {
                    val mgr = AppWidgetManager.getInstance(context)
                    result.success(
                        WidgetKind.values().associate {
                            it.key to mgr.getAppWidgetIds(
                                ComponentName(context, WidgetRenderer.kindClass(it)),
                            ).size
                        },
                    )
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("error", e.javaClass.simpleName, null)
        }
    }

    /** Asks the launcher to add a widget; false when it cannot. */
    private fun requestPin(key: String?): Boolean {
        val kind = WidgetKind.of(key) ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val mgr = AppWidgetManager.getInstance(context)
        if (!mgr.isRequestPinAppWidgetSupported) return false
        return mgr.requestPinAppWidget(
            ComponentName(context, WidgetRenderer.kindClass(kind)), null, null,
        )
    }

    companion object {
        const val CHANNEL = "focusflow/home_widgets"
    }
}

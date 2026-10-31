package com.iqballab.focusflow.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.iqballab.focusflow.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** The colours of one widget, resolved from theme + background style. */
class WidgetPalette(
    val dark: Boolean,
    val bg: Int,
    val ink: Int,
    val muted: Int,
    val chip: Int,
    val accent: Int,
    val danger: Int,
    val success: Int,
)

/**
 * Builds the RemoteViews of a widget from the stored snapshot and the
 * widget's own settings. Two layouts: the full one (header, optional tabs,
 * a scrolling list) and a compact one (a big count and the next item) for
 * widgets resized below roughly 2 × 2 cells.
 */
object WidgetRenderer {
    const val EXTRA_KIND = "ff.kind"
    const val ACTION_TAB = "com.iqballab.focusflow.widget.TAB"
    const val EXTRA_TAB = "ff.tab"

    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    // ── theme ───────────────────────────────────────────────────

    fun palette(c: Context, snap: JSONObject?, cfg: WidgetConfig): WidgetPalette {
        val prefs = snap?.optJSONObject("prefs")
        val systemDark =
            (c.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        // widget → app-wide widget theme → the app's own theme → the system.
        fun fromApp(): Boolean = when (prefs?.optString("appTheme")) {
            "dark" -> true
            "light" -> false
            else -> systemDark
        }
        val dark = when (cfg.theme) {
            "dark" -> true
            "light" -> false
            else -> when (prefs?.optString("theme")) {
                "dark" -> true
                "light" -> false
                else -> fromApp()
            }
        }
        val alpha = when (cfg.background) {
            "clear" -> 0x99
            "soft" -> 0xDD
            else -> 0xFF
        }
        val base = if (dark) 0x16211D else 0xFFFFFF
        return WidgetPalette(
            dark = dark,
            bg = (alpha shl 24) or base,
            ink = if (dark) 0xFFECFDF5.toInt() else 0xFF0F2A24.toInt(),
            muted = if (dark) 0xFF9FB3AB.toInt() else 0xFF64748B.toInt(),
            chip = if (dark) 0xFF263832.toInt() else 0xFFEEF5F2.toInt(),
            accent = color(prefs?.optString("accent"), 0xFF059669.toInt()),
            danger = if (dark) 0xFFF87171.toInt() else 0xFFDC2626.toInt(),
            success = if (dark) 0xFF34D399.toInt() else 0xFF059669.toInt(),
        )
    }

    fun color(hex: String?, fallback: Int): Int = try {
        if (hex.isNullOrEmpty()) fallback else Color.parseColor(hex)
    } catch (e: Exception) {
        fallback
    }

    fun kindColor(snap: JSONObject?, section: String, p: WidgetPalette): Int =
        color(snap?.optJSONObject("colors")?.optString(section), p.accent)

    fun iconOf(section: String): Int = when (section) {
        "tasks" -> R.drawable.ic_ffw_tasks
        "habits" -> R.drawable.ic_ffw_habits
        "medicines" -> R.drawable.ic_ffw_medicines
        "reminders" -> R.drawable.ic_ffw_reminders
        "notes" -> R.drawable.ic_ffw_notes
        else -> R.drawable.ic_ffw_all
    }

    // ── header numbers ──────────────────────────────────────────

    private fun pending(snap: JSONObject?, section: String): Int =
        snap?.optJSONObject(section)?.optInt("n", 0) ?: 0

    /** Things still to do across [sections] (notes are not "to do"). */
    fun pendingCount(snap: JSONObject?, sections: List<String>): Int =
        sections.filter { it != "notes" }.sumOf { pending(snap, it) }

    fun subtitle(snap: JSONObject?, section: String?, sections: List<String>): String {
        if (snap == null) return ""
        if (section == "notes") return ""
        val n = if (section == null) pendingCount(snap, sections) else pending(snap, section)
        val any = if (section == null) {
            sections.any { WidgetStore.items(snap, it).isNotEmpty() }
        } else {
            WidgetStore.items(snap, section).isNotEmpty()
        }
        return if (n == 0) {
            if (any) WidgetStore.label(snap, "allDone", "All done") else ""
        } else {
            WidgetStore.label(snap, "left", "{n} left").replace("{n}", n.toString())
        }
    }

    // ── intents ─────────────────────────────────────────────────

    private val immutable
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    fun openIntent(c: Context, route: String?): Intent =
        Intent(c, WidgetActionActivity::class.java)
            .setAction(WidgetActionActivity.ACTION_OPEN)
            .putExtra(WidgetActionActivity.EXTRA_ROUTE, route)

    fun openPending(c: Context, request: Int, route: String?): PendingIntent =
        PendingIntent.getActivity(
            c, request,
            // A distinct data URI keeps the PendingIntents of different routes apart.
            openIntent(c, route).setData(Uri.parse("ffwidget://open/${Uri.encode(route ?: "")}")),
            PendingIntent.FLAG_UPDATE_CURRENT or immutable,
        )

    /** The template every list row's fill-in intent completes (mutable on purpose). */
    fun listTemplate(c: Context, id: Int): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getActivity(
            c, id,
            Intent(c, WidgetActionActivity::class.java)
                .setData(Uri.parse("ffwidget://list/$id")),
            flags,
        )
    }

    private fun tabPending(c: Context, id: Int, kind: WidgetKind, tab: String): PendingIntent =
        PendingIntent.getBroadcast(
            c, (id * 31 + tab.hashCode()),
            Intent(c, kindClass(kind)).setAction(ACTION_TAB)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                .putExtra(EXTRA_TAB, tab)
                .setData(Uri.parse("ffwidget://tab/$id/$tab")),
            PendingIntent.FLAG_UPDATE_CURRENT or immutable,
        )

    fun kindClass(kind: WidgetKind): Class<*> = when (kind) {
        WidgetKind.TODAY -> TodayWidgetProvider::class.java
        WidgetKind.TASKS -> TasksWidgetProvider::class.java
        WidgetKind.HABITS -> HabitsWidgetProvider::class.java
        WidgetKind.MEDICINES -> MedicinesWidgetProvider::class.java
        WidgetKind.REMINDERS -> RemindersWidgetProvider::class.java
        WidgetKind.NOTES -> NotesWidgetProvider::class.java
    }

    // ── build ───────────────────────────────────────────────────

    /** Compact below about 2 × 2 cells. */
    fun isCompact(options: Bundle?): Boolean {
        val w = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250) ?: 250
        val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 250) ?: 250
        return w < 150 || h < 105
    }

    fun build(c: Context, id: Int, kind: WidgetKind, options: Bundle?): RemoteViews {
        val snap = WidgetStore.snapshot(c)
        val cfg = WidgetStore.config(c, id)
        val p = palette(c, snap, cfg)
        val sections = if (kind.isCombined) {
            cfg.sections.filter { s -> WidgetKind.SECTIONS.any { it.key == s } }
                .ifEmpty { WidgetKind.SECTIONS.map { it.key } }
        } else {
            listOf(kind.key)
        }
        return if (isCompact(options)) {
            compact(c, id, kind, snap, p, sections)
        } else {
            full(c, id, kind, snap, cfg, p, sections)
        }
    }

    private fun full(
        c: Context, id: Int, kind: WidgetKind, snap: JSONObject?,
        cfg: WidgetConfig, p: WidgetPalette, sections: List<String>,
    ): RemoteViews {
        val v = RemoteViews(c.packageName, R.layout.ffw_widget)
        v.setInt(R.id.bg, "setColorFilter", p.bg)
        val section = if (kind.isCombined) null else kind.key
        val tint = if (section == null) p.accent else kindColor(snap, section, p)

        // header
        v.setInt(R.id.badge, "setColorFilter", tint)
        v.setImageViewResource(R.id.icon, iconOf(section ?: "all"))
        v.setTextViewText(
            R.id.title,
            WidgetStore.label(snap, section ?: "today", kind.key.replaceFirstChar { it.uppercase() }),
        )
        v.setTextColor(R.id.title, p.ink)
        v.setTextViewText(R.id.subtitle, subtitle(snap, section, sections))
        v.setTextColor(R.id.subtitle, p.muted)
        v.setInt(R.id.addBg, "setColorFilter", p.chip)
        v.setInt(R.id.addIcon, "setColorFilter", tint)
        val addKey = "add:${section ?: "today"}"
        v.setOnClickPendingIntent(
            R.id.add,
            openPending(c, id * 7 + 1, snap?.optJSONObject("routes")?.optString(addKey)),
        )
        v.setContentDescription(R.id.add, WidgetStore.label(snap, "add", "Add"))
        v.setOnClickPendingIntent(
            R.id.titleBox,
            openPending(c, id * 7 + 2, snap?.optJSONObject("routes")?.optString(section ?: "home")),
        )

        // tabs (combined widget only)
        val tabIds = intArrayOf(R.id.tab0, R.id.tab1, R.id.tab2, R.id.tab3, R.id.tab4, R.id.tab5)
        val tabBg = intArrayOf(R.id.tab0bg, R.id.tab1bg, R.id.tab2bg, R.id.tab3bg, R.id.tab4bg, R.id.tab5bg)
        val tabIcon = intArrayOf(R.id.tab0i, R.id.tab1i, R.id.tab2i, R.id.tab3i, R.id.tab4i, R.id.tab5i)
        val tabs = if (kind.isCombined) listOf("all") + sections else emptyList()
        val current = if (cfg.tab in tabs) cfg.tab else "all"
        v.setViewVisibility(R.id.tabs, if (tabs.size > 1) View.VISIBLE else View.GONE)
        for (i in tabIds.indices) {
            val key = tabs.getOrNull(i)
            if (key == null || tabs.size <= 1) {
                v.setViewVisibility(tabIds[i], View.GONE)
                continue
            }
            v.setViewVisibility(tabIds[i], View.VISIBLE)
            val on = key == current
            val col = if (key == "all") p.accent else kindColor(snap, key, p)
            v.setInt(tabBg[i], "setColorFilter", if (on) col else p.chip)
            v.setImageViewResource(tabIcon[i], iconOf(key))
            v.setInt(tabIcon[i], "setColorFilter", if (on) 0xFFFFFFFF.toInt() else p.muted)
            v.setOnClickPendingIntent(tabIds[i], tabPending(c, id, kind, key))
        }

        // list
        val svc = Intent(c, WidgetListService::class.java)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            .putExtra(EXTRA_KIND, kind.key)
            .setData(Uri.parse("ffwidget://list/$id/${kind.key}"))
        @Suppress("DEPRECATION")
        v.setRemoteAdapter(R.id.list, svc)
        v.setEmptyView(R.id.list, R.id.empty)
        v.setPendingIntentTemplate(R.id.list, listTemplate(c, id))
        val emptyKey = if (kind.isCombined && current == "all") "empty.all"
        else "empty.${if (kind.isCombined) current else kind.key}"
        v.setTextViewText(
            R.id.empty,
            if (snap == null) WidgetStore.label(snap, "noData", "Open FocusFlow to set up this widget")
            else WidgetStore.label(snap, emptyKey, ""),
        )
        v.setTextColor(R.id.empty, p.muted)
        return v
    }

    private fun compact(
        c: Context, id: Int, kind: WidgetKind, snap: JSONObject?,
        p: WidgetPalette, sections: List<String>,
    ): RemoteViews {
        val v = RemoteViews(c.packageName, R.layout.ffw_widget_small)
        v.setInt(R.id.bg, "setColorFilter", p.bg)
        val section = if (kind.isCombined) null else kind.key
        val tint = if (section == null) p.accent else kindColor(snap, section, p)
        v.setInt(R.id.badge, "setColorFilter", tint)
        v.setImageViewResource(R.id.icon, iconOf(section ?: "all"))
        val n = if (section == "notes") (snap?.optJSONObject("notes")?.optInt("n", 0) ?: 0)
        else if (section == null) pendingCount(snap, sections)
        else pending(snap, section)
        v.setTextViewText(R.id.count, if (snap == null) "–" else n.toString())
        v.setTextColor(R.id.count, p.ink)
        v.setTextViewText(
            R.id.label,
            WidgetStore.label(snap, section ?: "today", kind.key.replaceFirstChar { it.uppercase() }),
        )
        v.setTextColor(R.id.label, p.muted)
        // The next thing to do.
        val firstSection = section ?: sections.firstOrNull { s ->
            s != "notes" && WidgetStore.items(snap, s).any { !isDone(it, s) }
        } ?: "tasks"
        val next = WidgetStore.items(snap, firstSection).firstOrNull { !isDone(it, firstSection) }
        v.setTextViewText(R.id.next, next?.optString("t").orEmpty())
        v.setTextColor(R.id.next, p.ink)
        v.setInt(R.id.addBg, "setColorFilter", p.chip)
        v.setInt(R.id.addIcon, "setColorFilter", tint)
        v.setOnClickPendingIntent(
            R.id.add,
            openPending(c, id * 7 + 1, snap?.optJSONObject("routes")?.optString("add:${section ?: "today"}")),
        )
        v.setContentDescription(R.id.add, WidgetStore.label(snap, "add", "Add"))
        v.setOnClickPendingIntent(
            R.id.root,
            openPending(c, id * 7 + 2, snap?.optJSONObject("routes")?.optString(section ?: "home")),
        )
        return v
    }

    fun isDone(item: JSONObject, section: String): Boolean =
        if (section == "medicines") item.optString("st") == "taken" || item.optString("st") == "skipped"
        else item.optBoolean("done", false)

    // ── refresh ─────────────────────────────────────────────────

    fun update(c: Context, mgr: AppWidgetManager, id: Int, kind: WidgetKind) {
        try {
            mgr.updateAppWidget(id, build(c, id, kind, mgr.getAppWidgetOptions(id)))
            mgr.notifyAppWidgetViewDataChanged(id, R.id.list)
        } catch (e: Exception) {
            android.util.Log.w("FFWidget", "Could not update widget $id: ${e.message}")
        }
    }

    fun updateAll(c: Context) {
        val mgr = AppWidgetManager.getInstance(c)
        for (kind in WidgetKind.values()) {
            for (id in mgr.getAppWidgetIds(ComponentName(c, kindClass(kind)))) {
                update(c, mgr, id, kind)
            }
        }
    }
}


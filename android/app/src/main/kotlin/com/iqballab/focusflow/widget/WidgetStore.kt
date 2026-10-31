package com.iqballab.focusflow.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** The widget kinds: one AppWidgetProvider each (see FocusWidgetProviders.kt). */
enum class WidgetKind(val key: String) {
    TODAY("today"),
    TASKS("tasks"),
    HABITS("habits"),
    MEDICINES("medicines"),
    REMINDERS("reminders"),
    NOTES("notes");

    /** The data sections a single-section widget shows; null for the combined one. */
    val isCombined get() = this == TODAY

    companion object {
        /** Sections in display order (the combined widget's tabs). */
        val SECTIONS = listOf(TASKS, HABITS, MEDICINES, REMINDERS, NOTES)

        fun of(key: String?): WidgetKind? = values().firstOrNull { it.key == key }
    }
}

/** One widget's own settings (the config screen), stored per appWidgetId. */
data class WidgetConfig(
    /** "app" · "light" · "dark". */
    val theme: String = "app",
    /** "solid" · "soft" · "clear". */
    val background: String = "solid",
    /** Sections of the combined widget (keys), in display order. */
    val sections: List<String> = WidgetKind.SECTIONS.map { it.key },
    /** The tab showing now ("all" or a section key) for the combined widget. */
    val tab: String = "all",
)

/**
 * Everything the widgets know: the last snapshot Dart pushed (JSON, see
 * lib/core/home_widgets/widget_snapshot_builder.dart) and each widget's own
 * configuration. SharedPreferences only — the encrypted database is never
 * touched from here.
 */
object WidgetStore {
    private const val PREFS = "ff_home_widgets"
    private const val SNAPSHOT = "snapshot"
    private const val VERSION = 1

    private fun prefs(c: Context): SharedPreferences =
        c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Stores [json] when it is a snapshot version this code understands. */
    fun save(c: Context, json: String): Boolean {
        val o = try {
            JSONObject(json)
        } catch (e: Exception) {
            return false
        }
        if (o.optInt("v", 0) != VERSION) return false
        prefs(c).edit().putString(SNAPSHOT, json).apply()
        return true
    }

    fun snapshot(c: Context): JSONObject? = try {
        prefs(c).getString(SNAPSHOT, null)?.let { JSONObject(it) }
    } catch (e: Exception) {
        null
    }

    /**
     * Marks an item done in the stored snapshot right away (the optimistic
     * half of a widget tap; Dart replaces the snapshot a moment later).
     * Habits count one more check-in, doses become "taken".
     */
    fun markDone(c: Context, section: String, id: String, dayKey: String?, minutes: Int) {
        val snap = snapshot(c) ?: return
        val sec = snap.optJSONObject(section) ?: return
        val items = sec.optJSONArray("items") ?: return
        for (i in 0 until items.length()) {
            val it = items.optJSONObject(i) ?: continue
            if (it.optString("id") != id) continue
            if (section == "medicines" &&
                (it.optString("day") != dayKey || it.optInt("min", -1) != minutes)
            ) continue
            when (section) {
                "habits" -> {
                    val count = it.optInt("c", 0) + 1
                    it.put("c", count)
                    if (count >= it.optInt("g", 1)) it.put("done", true)
                }
                "medicines" -> it.put("st", "taken")
                else -> it.put("done", true)
            }
        }
        // Counts shown in headers.
        val left = (0 until items.length()).count { idx ->
            val x = items.optJSONObject(idx)
            if (section == "medicines") x?.optString("st") != "taken"
            else x?.optBoolean("done") != true
        }
        sec.put("n", left)
        prefs(c).edit().putString(SNAPSHOT, snap.toString()).apply()
    }

    // ── per-widget config ──

    fun config(c: Context, id: Int): WidgetConfig {
        val p = prefs(c)
        val d = WidgetConfig()
        return WidgetConfig(
            theme = p.getString("w$id.theme", d.theme) ?: d.theme,
            background = p.getString("w$id.bg", d.background) ?: d.background,
            sections = p.getString("w$id.sections", null)
                ?.split(',')?.filter { it.isNotBlank() } ?: d.sections,
            tab = p.getString("w$id.tab", d.tab) ?: d.tab,
        )
    }

    fun saveConfig(c: Context, id: Int, cfg: WidgetConfig) {
        prefs(c).edit()
            .putString("w$id.theme", cfg.theme)
            .putString("w$id.bg", cfg.background)
            .putString("w$id.sections", cfg.sections.joinToString(","))
            .putString("w$id.tab", cfg.tab)
            .apply()
    }

    fun setTab(c: Context, id: Int, tab: String) {
        prefs(c).edit().putString("w$id.tab", tab).apply()
    }

    fun forget(c: Context, ids: IntArray) {
        val e = prefs(c).edit()
        for (id in ids) {
            e.remove("w$id.theme").remove("w$id.bg").remove("w$id.sections").remove("w$id.tab")
        }
        e.apply()
    }

    // ── small readers ──

    fun label(snap: JSONObject?, key: String, fallback: String): String =
        snap?.optJSONObject("labels")?.optString(key)?.takeIf { it.isNotEmpty() } ?: fallback

    fun items(snap: JSONObject?, section: String): List<JSONObject> {
        val arr: JSONArray = snap?.optJSONObject(section)?.optJSONArray("items") ?: return emptyList()
        return (0 until arr.length()).mapNotNull { arr.optJSONObject(it) }
    }

    /** The day the snapshot was made for no longer matches today's date. */
    fun isStale(snap: JSONObject?, today: String): Boolean =
        snap != null && snap.optString("day") != today
}

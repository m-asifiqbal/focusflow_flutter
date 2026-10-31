package com.iqballab.focusflow.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.iqballab.focusflow.R
import org.json.JSONObject

/** The scrolling list of a widget (tasks, doses, notes …). */
class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WidgetListFactory(
            applicationContext,
            intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 0),
            WidgetKind.of(intent.getStringExtra(WidgetRenderer.EXTRA_KIND)) ?: WidgetKind.TASKS,
        )
}

private sealed class Row {
    class Header(val section: String, val title: String, val count: Int, val color: Int) : Row()
    class Item(val section: String, val data: JSONObject) : Row()
}

private class WidgetListFactory(
    private val ctx: Context,
    private val id: Int,
    private val kind: WidgetKind,
) : RemoteViewsService.RemoteViewsFactory {
    private var rows: List<Row> = emptyList()
    private var snap: JSONObject? = null
    private lateinit var palette: WidgetPalette

    override fun onCreate() {}
    override fun onDestroy() {}

    /** Runs on a binder thread whenever the widget data changed. */
    override fun onDataSetChanged() {
        val s = WidgetStore.snapshot(ctx)
        val cfg = WidgetStore.config(ctx, id)
        snap = s
        palette = WidgetRenderer.palette(ctx, s, cfg)
        val showDone = s?.optJSONObject("prefs")?.optBoolean("done", true) ?: true
        rows = if (!kind.isCombined) {
            items(kind.key, showDone, Int.MAX_VALUE)
        } else {
            val sections = cfg.sections.filter { k -> WidgetKind.SECTIONS.any { it.key == k } }
                .ifEmpty { WidgetKind.SECTIONS.map { it.key } }
            val tab = if (cfg.tab == "all" || cfg.tab !in sections) "all" else cfg.tab
            if (tab != "all") {
                items(tab, showDone, Int.MAX_VALUE)
            } else {
                // "All together": a few of each section under its own header.
                sections.flatMap { sec ->
                    val list = items(sec, showDone = false, limit = PER_SECTION)
                    if (list.isEmpty()) emptyList()
                    else listOf<Row>(
                        Row.Header(
                            sec,
                            WidgetStore.label(s, sec, sec),
                            s?.optJSONObject(sec)?.optInt("n", 0) ?: 0,
                            WidgetRenderer.kindColor(s, sec, palette),
                        ),
                    ) + list
                }
            }
        }
    }

    private fun items(section: String, showDone: Boolean, limit: Int): List<Row> =
        WidgetStore.items(snap, section)
            .filter { showDone || !WidgetRenderer.isDone(it, section) }
            .take(limit)
            .map { Row.Item(section, it) }

    override fun getCount() = rows.size
    override fun getViewTypeCount() = 2
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val row = rows.getOrNull(position)
            ?: return RemoteViews(ctx.packageName, R.layout.ffw_section)
        return when (row) {
            is Row.Header -> header(row)
            is Row.Item -> item(row)
        }
    }

    private fun header(h: Row.Header): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.ffw_section)
        v.setTextViewText(R.id.sectionTitle, h.title.uppercase())
        v.setTextColor(R.id.sectionTitle, h.color)
        v.setTextViewText(R.id.sectionCount, if (h.count > 0) h.count.toString() else "")
        v.setTextColor(R.id.sectionCount, palette.muted)
        val fill = Intent().putExtra(WidgetActionActivity.EXTRA_OP, WidgetActionActivity.OP_OPEN)
            .putExtra(WidgetActionActivity.EXTRA_ROUTE, snap?.optJSONObject("routes")?.optString(h.section))
        v.setOnClickFillInIntent(R.id.sectionRoot, fill)
        return v
    }

    private fun item(r: Row.Item): RemoteViews {
        val o = r.data
        val sec = r.section
        val v = RemoteViews(ctx.packageName, R.layout.ffw_item)
        val done = WidgetRenderer.isDone(o, sec)
        val tint = WidgetRenderer.kindColor(snap, sec, palette)

        // title (struck through when done)
        val title = o.optString("t")
        val text: CharSequence = if (done && sec != "medicines") {
            SpannableString(title).apply {
                setSpan(StrikethroughSpan(), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        } else title
        v.setTextViewText(R.id.itemTitle, text)
        v.setTextColor(R.id.itemTitle, if (done) palette.muted else palette.ink)

        // sub line + its colour
        val state = o.optString("st")
        val sub = o.optString("sub")
        v.setTextViewText(R.id.itemSub, sub)
        v.setViewVisibility(R.id.itemSub, if (sub.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
        val alarm = o.optBoolean("od", false) || state == "missed"
        v.setTextColor(R.id.itemSub, if (alarm && !done) palette.danger else palette.muted)

        // leading circle
        when (sec) {
            "notes" -> {
                v.setImageViewResource(R.id.itemCheck, if (o.optBoolean("lock")) R.drawable.ic_ffw_lock
                else R.drawable.ic_ffw_notes)
                v.setInt(R.id.itemCheck, "setColorFilter", tint)
            }
            else -> {
                v.setImageViewResource(R.id.itemCheck, if (done) R.drawable.ic_ffw_check_on else R.drawable.ic_ffw_check_off)
                v.setInt(
                    R.id.itemCheck, "setColorFilter",
                    when {
                        done -> if (state == "skipped") palette.muted else palette.success
                        alarm -> palette.danger
                        else -> tint
                    },
                )
            }
        }

        // trailing: a habit's streak, a pinned note
        val trail = when {
            sec == "habits" && o.optInt("streak", 0) > 1 -> "🔥${o.optInt("streak")}"
            sec == "notes" && o.optBoolean("pin") -> "📌"
            else -> ""
        }
        v.setTextViewText(R.id.itemTrail, trail)
        v.setTextColor(R.id.itemTrail, palette.muted)

        // open the item
        val open = Intent()
            .putExtra(WidgetActionActivity.EXTRA_OP, WidgetActionActivity.OP_OPEN)
            .putExtra(WidgetActionActivity.EXTRA_ROUTE, o.optString("r"))
        v.setOnClickFillInIntent(R.id.itemRoot, open)

        // complete it from the circle
        val canDo = sec != "notes" && !done && !(sec == "medicines" && state == "skipped")
        if (canDo) {
            val doIt = Intent()
                .putExtra(WidgetActionActivity.EXTRA_OP, WidgetActionActivity.OP_DO)
                .putExtra(WidgetActionActivity.EXTRA_SECTION, sec)
                .putExtra(WidgetActionActivity.EXTRA_ID, o.optString("id"))
                .putExtra(WidgetActionActivity.EXTRA_DAY, o.optString("day"))
                .putExtra(WidgetActionActivity.EXTRA_MIN, o.optInt("min", -1))
                .putExtra(WidgetActionActivity.EXTRA_ROUTE, o.optString("r"))
            v.setOnClickFillInIntent(R.id.itemCheck, doIt)
        } else {
            v.setOnClickFillInIntent(R.id.itemCheck, open)
        }
        return v
    }

    companion object {
        /** Rows per section on the "All together" tab. */
        private const val PER_SECTION = 3
    }
}

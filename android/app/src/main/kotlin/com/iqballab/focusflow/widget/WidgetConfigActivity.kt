package com.iqballab.focusflow.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView

/**
 * One widget's own settings, shown when it is placed (and, on launchers that
 * support it, when it is reconfigured): its theme, its background and — for
 * the all-together widget — which sections it holds. Words come from the
 * app's last snapshot, so they follow the app's language; the English
 * fallbacks only show before the app ever ran.
 */
class WidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val info = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)
        val kind = WidgetKind.values().firstOrNull {
            WidgetRenderer.kindClass(it).name == info?.provider?.className
        } ?: WidgetKind.TASKS
        val snap = WidgetStore.snapshot(this)
        val cfg = WidgetStore.config(this, widgetId)
        fun t(key: String, fallback: String) = WidgetStore.label(snap, key, fallback)
        val accent = WidgetRenderer.color(snap?.optJSONObject("prefs")?.optString("accent"), 0xFF059669.toInt())

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(32), dp(24), dp(24))
        }
        root.addView(title(t("config.title", "Widget settings"), 22f))
        root.addView(
            title(
                t(if (kind.isCombined) "today" else kind.key, kind.key.replaceFirstChar { it.uppercase() }),
                15f, Color.GRAY,
            ),
        )

        // theme
        root.addView(heading(t("config.theme", "Theme")))
        val themeGroup = radios(
            listOf(
                "app" to t("config.themeApp", "Follow the app"),
                "light" to t("config.themeLight", "Light"),
                "dark" to t("config.themeDark", "Dark"),
            ),
            cfg.theme,
        )
        root.addView(themeGroup)

        // background
        root.addView(heading(t("config.background", "Background")))
        val bgGroup = radios(
            listOf(
                "solid" to t("config.bgSolid", "Solid"),
                "soft" to t("config.bgSoft", "Soft"),
                "clear" to t("config.bgClear", "Clear"),
            ),
            cfg.background,
        )
        root.addView(bgGroup)

        // sections (all-together widget)
        val boxes = LinkedHashMap<String, CheckBox>()
        if (kind.isCombined) {
            root.addView(heading(t("config.sections", "Sections")))
            for (s in WidgetKind.SECTIONS) {
                val box = CheckBox(this).apply {
                    text = t(s.key, s.key.replaceFirstChar { it.uppercase() })
                    isChecked = s.key in cfg.sections
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    buttonTintList = android.content.res.ColorStateList.valueOf(accent)
                }
                boxes[s.key] = box
                root.addView(box)
            }
        }

        val save = Button(this).apply {
            text = t("config.save", "Save")
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                cornerRadius = dp(28).toFloat()
                setColor(accent)
            }
            setOnClickListener {
                val sections = boxes.filter { it.value.isChecked }.keys.toList()
                    .ifEmpty { WidgetKind.SECTIONS.map { it.key } }
                WidgetStore.saveConfig(
                    this@WidgetConfigActivity, widgetId,
                    cfg.copy(
                        theme = checked(themeGroup),
                        background = checked(bgGroup),
                        sections = sections,
                        tab = if (cfg.tab == "all" || cfg.tab in sections) cfg.tab else "all",
                    ),
                )
                // The widget draws now; the system needs RESULT_OK to keep it.
                WidgetRenderer.update(
                    this@WidgetConfigActivity,
                    AppWidgetManager.getInstance(this@WidgetConfigActivity), widgetId, kind,
                )
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                finish()
            }
        }
        root.addView(
            save,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(56))
                .apply { topMargin = dp(28) },
        )
        setContentView(ScrollView(this).apply { addView(root) })
    }

    private fun title(text: String, sp: Float, color: Int = Color.BLACK) = TextView(this).apply {
        this.text = text
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(color)
        typeface = Typeface.DEFAULT_BOLD
    }

    private fun heading(text: String) = TextView(this).apply {
        this.text = text.uppercase()
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
        setTextColor(Color.GRAY)
        typeface = Typeface.DEFAULT_BOLD
        letterSpacing = 0.08f
        setPadding(0, dp(24), 0, dp(6))
    }

    private fun radios(options: List<Pair<String, String>>, selected: String) =
        RadioGroup(this).apply {
            orientation = LinearLayout.VERTICAL
            for ((key, label) in options) {
                addView(
                    RadioButton(this@WidgetConfigActivity).apply {
                        text = label
                        tag = key
                        id = View.generateViewId()
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                        isChecked = key == selected
                    },
                )
            }
            gravity = Gravity.START
        }

    private fun checked(group: RadioGroup): String =
        group.findViewById<View>(group.checkedRadioButtonId)?.tag as? String ?: ""

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics,
    ).toInt()
}

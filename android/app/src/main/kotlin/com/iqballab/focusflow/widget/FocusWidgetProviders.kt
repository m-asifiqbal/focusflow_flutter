package com.iqballab.focusflow.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * The six home-screen widgets. One base class does everything; a subclass
 * only says which [WidgetKind] it is (the manifest needs one receiver per
 * widget).
 *
 * The widgets draw from the snapshot the app pushed (WidgetStore) — no
 * database, no network. Besides the system's own updates (every 30 minutes
 * at most) they refresh when the app pushes new data, when a tab is tapped,
 * and when the date, time zone or language changes.
 */
abstract class FocusWidgetProvider(private val kind: WidgetKind) : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) WidgetRenderer.update(context, mgr, id, kind)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, mgr: AppWidgetManager, id: Int, newOptions: Bundle,
    ) {
        // Resized: the compact / full layout may change.
        WidgetRenderer.update(context, mgr, id, kind)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetStore.forget(context, ids)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WidgetRenderer.ACTION_TAB -> {
                val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 0)
                val tab = intent.getStringExtra(WidgetRenderer.EXTRA_TAB)
                if (id != 0 && tab != null) {
                    WidgetStore.setTab(context, id, tab)
                    WidgetRenderer.update(context, AppWidgetManager.getInstance(context), id, kind)
                }
            }
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> WidgetRenderer.updateAll(context)
            else -> super.onReceive(context, intent)
        }
    }
}

class TodayWidgetProvider : FocusWidgetProvider(WidgetKind.TODAY)
class TasksWidgetProvider : FocusWidgetProvider(WidgetKind.TASKS)
class HabitsWidgetProvider : FocusWidgetProvider(WidgetKind.HABITS)
class MedicinesWidgetProvider : FocusWidgetProvider(WidgetKind.MEDICINES)
class RemindersWidgetProvider : FocusWidgetProvider(WidgetKind.REMINDERS)
class NotesWidgetProvider : FocusWidgetProvider(WidgetKind.NOTES)

package com.westviewhs.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget provider for the "Current period" widget.
 *
 * Extends [HomeWidgetProvider] so data saved from Flutter via
 * `HomeWidget.saveWidgetData(...)` is available in `widgetData` (the
 * schedule is also read directly through `HomeWidgetPlugin.getData` in
 * [ScheduleWidgetRenderer] so the alarm receiver can access it too).
 */
class ScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        ScheduleWidgetRenderer.renderAll(context)
    }

    override fun onEnabled(context: Context) {
        // First widget placed — start scheduling transitions so the countdown
        // stays in sync even without the app being opened.
        ScheduleNotificationManager.ensureChannel(context)
        ScheduleWidgetRenderer.renderAll(context)
    }

    override fun onDisabled(context: Context) {
        // Last widget instance was removed: stop the transition alarms.
        ScheduleWidgetRenderer.cancelAlarm(context)
    }
}

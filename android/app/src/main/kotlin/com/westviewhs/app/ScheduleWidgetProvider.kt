package com.westviewhs.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget provider. Extends HomeWidgetProvider so data written
 * from Flutter via HomeWidget.saveWidgetData(...) is available here.
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

    override fun onDisabled(context: Context) {
        ScheduleWidgetRenderer.cancelAlarm(context)
    }
}

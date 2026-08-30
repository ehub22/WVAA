package com.westviewhs.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-renders the widget and notification when a period-transition alarm fires,
 * the device reboots, or the system time/date/timezone changes.
 */
class ScheduleWidgetAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ScheduleWidgetRenderer.ACTION_PERIOD_TICK,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            -> ScheduleWidgetRenderer.renderAll(context)
        }
    }
}

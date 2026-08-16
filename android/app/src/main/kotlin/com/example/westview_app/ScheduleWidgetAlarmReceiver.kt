package com.example.westview_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-renders the "Current period" widget when:
 *  - a precise period-transition alarm fires ([ScheduleWidgetRenderer.ACTION_PERIOD_TICK]),
 *  - the device reboots, or
 *  - the system time, time zone, or date changes (all of which invalidate
 *    the displayed countdown).
 */
class ScheduleWidgetAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        when (action) {
            ScheduleWidgetRenderer.ACTION_PERIOD_TICK,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            -> ScheduleWidgetRenderer.renderAll(context)
        }
    }
}

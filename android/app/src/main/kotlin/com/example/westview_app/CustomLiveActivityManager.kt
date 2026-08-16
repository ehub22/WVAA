package com.example.westview_app

import android.app.Notification
import android.content.Context
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.example.live_activities.LiveActivityManager

class CustomLiveActivityManager(private val context: Context) : LiveActivityManager(context) {

    override suspend fun buildNotification(
        notification: Notification.Builder,
        event: String,
        data: Map<String, Any>
    ): Notification {
        
        // Link to the live_activity.xml layout
        val remoteViews = RemoteViews(context.packageName, R.layout.live_activity)

        // 1. Extract the name data sent from Dart and bind it to the TextView.
        // Dart already resolved any custom class name the student configured
        // in settings (e.g. "Human Body Systems" instead of "Period 1").
        val periodName = data["periodName"] as? String ?: "Period"
        remoteViews.setTextViewText(R.id.period_name, periodName)

        // 1b. Optional teacher / room line ("Mr. Smith · Rm 402"), only shown
        // when the student entered it and enabled it in settings.
        val periodDetail = (data["periodDetail"] as? String).orEmpty()
        if (periodDetail.isBlank()) {
            remoteViews.setViewVisibility(R.id.period_detail, View.GONE)
        } else {
            remoteViews.setTextViewText(R.id.period_detail, periodDetail)
            remoteViews.setViewVisibility(R.id.period_detail, View.VISIBLE)
        }

        // 2. Extract the Unix timestamp, convert it to Android elapsedRealtime for the Chronometer
        val endTimeMillisStr = data["endTime"] as? String
        if (endTimeMillisStr != null) {
            val endTimeMillis = endTimeMillisStr.toLongOrNull() ?: 0L
            
            // Android Chronometer uses 'elapsedRealtime' (time since boot) rather than standard UNIX time.
            val diff = endTimeMillis - System.currentTimeMillis()
            val baseTime = SystemClock.elapsedRealtime() + diff

            // Set the countdown and start it
            remoteViews.setChronometer(
                R.id.period_countdown,
                baseTime,
                "%s", // Display format
                true  // isStarted
            )
        }

        // Apply custom layout back to the notification channel builder
        notification.setCustomContentView(remoteViews)
        notification.setCustomBigContentView(remoteViews)

        return notification.setSmallIcon(R.mipmap.launcher_icon).setOngoing(true).build()
    }
}
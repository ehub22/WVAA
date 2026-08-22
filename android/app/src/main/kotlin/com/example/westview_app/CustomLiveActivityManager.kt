package com.example.westview_app

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.example.live_activities.LiveActivityManager
import java.time.LocalDateTime

class CustomLiveActivityManager(private val context: Context) : LiveActivityManager(context) {

    override suspend fun buildNotification(
        notification: Notification.Builder,
        event: String,
        data: Map<String, Any>
    ): Notification {
        
        // Ensure channels allow lockscreen display
        ScheduleNotificationManager.ensureChannel(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channels = notificationManager.notificationChannels
            for (channel in channels) {
                if (channel.lockscreenVisibility != Notification.VISIBILITY_PUBLIC) {
                    channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    channel.setShowBadge(true)
                    notificationManager.createNotificationChannel(channel)
                }
            }
        }

        // Link to the live_activity.xml layout
        val remoteViews = RemoteViews(context.packageName, R.layout.live_activity)

        // 1. Extract the name data sent from Dart and bind it to the TextView.
        // Dart already resolved any custom class name configured in settings.
        val periodName = data["periodName"] as? String ?: "Period"
        remoteViews.setTextViewText(R.id.period_name, periodName)

        // 1b. Optional teacher / room line ("Mr. Smith · Rm 402"), only shown
        // when entered and enabled in settings.
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
            val diff = endTimeMillis - System.currentTimeMillis()
            val baseTime = SystemClock.elapsedRealtime() + diff.coerceAtLeast(0L)

            // Set the countdown and start it
            remoteViews.setChronometer(
                R.id.period_countdown,
                baseTime,
                "%s", // Display format
                true  // isStarted
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                remoteViews.setChronometerCountDown(R.id.period_countdown, true)
            }
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val clickPendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Apply custom layout back to the notification channel builder
        notification.setCustomContentView(remoteViews)
        notification.setCustomBigContentView(remoteViews)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            notification.setCustomHeadsUpContentView(remoteViews)
        }

        // Use the transparent monochrome Wolverine icon for small icon and launcher icon for large icon
        notification.setSmallIcon(R.drawable.ic_notification)
        notification.setLargeIcon(BitmapFactory.decodeResource(context.resources, R.mipmap.launcher_icon))
        notification.setContentIntent(clickPendingIntent)

        // Ensure full visibility on lockscreen and ongoing status
        notification.setVisibility(Notification.VISIBILITY_PUBLIC)
        notification.setOngoing(true)
        notification.setShowWhen(false)
        notification.setCategory(Notification.CATEGORY_STATUS)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            notification.setPriority(Notification.PRIORITY_HIGH)
        }

        // Set public version fallback for secure lockscreens
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val publicBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, ScheduleNotificationManager.CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            publicBuilder
                .setSmallIcon(R.drawable.ic_notification)
                .setLargeIcon(BitmapFactory.decodeResource(context.resources, R.mipmap.launcher_icon))
                .setContentTitle(periodName)
                .setContentText(if (periodDetail.isNotBlank()) periodDetail else "In progress")
                .setContentIntent(clickPendingIntent)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
            notification.setPublicVersion(publicBuilder.build())
        }

        // Prime the background AlarmManager so the next notification automatically
        // starts as soon as this period ends, even when the phone is locked.
        ScheduleWidgetRenderer.scheduleNextTransition(context, LocalDateTime.now())

        return notification.build()
    }
}

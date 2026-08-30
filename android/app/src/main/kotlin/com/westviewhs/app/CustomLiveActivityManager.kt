package com.westviewhs.app

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
        // Route the live-activity notification through our own channel, which is
        // guaranteed to have lockscreen visibility set to PUBLIC.
        ScheduleNotificationManager.ensureChannel(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notification.setChannelId(ScheduleNotificationManager.CHANNEL_ID)
        }

        val remoteViews = RemoteViews(context.packageName, R.layout.live_activity)

        val periodName = data["periodName"] as? String ?: "Period"
        remoteViews.setTextViewText(R.id.period_name, periodName)

        val periodDetail = (data["periodDetail"] as? String).orEmpty()
        if (periodDetail.isBlank()) {
            remoteViews.setViewVisibility(R.id.period_detail, View.GONE)
        } else {
            remoteViews.setTextViewText(R.id.period_detail, periodDetail)
            remoteViews.setViewVisibility(R.id.period_detail, View.VISIBLE)
        }

        val endTimeMillisStr = data["endTime"] as? String
        if (endTimeMillisStr != null) {
            val endTimeMillis = endTimeMillisStr.toLongOrNull() ?: 0L
            val diff = endTimeMillis - System.currentTimeMillis()
            val baseTime = SystemClock.elapsedRealtime() + diff.coerceAtLeast(0L)

            remoteViews.setChronometer(
                R.id.period_countdown,
                baseTime,
                "%s",
                true
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

        notification.setCustomContentView(remoteViews)
        notification.setCustomBigContentView(remoteViews)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            notification.setCustomHeadsUpContentView(remoteViews)
        }

        notification.setSmallIcon(R.drawable.ic_notification)
        notification.setLargeIcon(BitmapFactory.decodeResource(context.resources, R.mipmap.launcher_icon))
        notification.setContentIntent(clickPendingIntent)

        notification.setVisibility(Notification.VISIBILITY_PUBLIC)
        notification.setOngoing(true)
        notification.setShowWhen(false)
        notification.setCategory(Notification.CATEGORY_PROGRESS)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            notification.setPriority(Notification.PRIORITY_HIGH)
        }

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

        // Schedule the next period-transition alarm so the native side can
        // refresh the notification even while the app is in the background.
        ScheduleWidgetRenderer.scheduleNextTransition(context, LocalDateTime.now())

        return notification.build()
    }
}

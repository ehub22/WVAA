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
        data: Map<String, Any>,
    ): Notification {
        // Ensure the countdown channel exists with the right importance/visibility
        // so the live activity shows on the lock screen.
        ScheduleNotificationManager.ensureChannel(context)

        val remoteViews = RemoteViews(context.packageName, R.layout.live_activity)

        // Dart already resolved any custom class name configured in settings.
        val periodName = data["periodName"] as? String ?: "Period"
        remoteViews.setTextViewText(R.id.period_name, periodName)

        // Optional teacher / room line ("Mr. Smith · Rm 402"), only shown when
        // entered and enabled in settings.
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
                true,
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
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        notification.setCustomContentView(remoteViews)
        notification.setCustomBigContentView(remoteViews)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            notification.setCustomHeadsUpContentView(remoteViews)
        }

        notification.setSmallIcon(R.drawable.ic_notification)
        notification.setLargeIcon(
            BitmapFactory.decodeResource(context.resources, R.mipmap.launcher_icon),
        )
        notification.setContentIntent(clickPendingIntent)

        notification.setVisibility(Notification.VISIBILITY_PUBLIC)
        notification.setOngoing(true)
        notification.setShowWhen(false)
        notification.setCategory(Notification.CATEGORY_STATUS)
        notification.setOnlyAlertOnce(true)
        notification.setLocalOnly(true)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            notification.setPriority(Notification.PRIORITY_DEFAULT)
        }

        // Public-version fallback for secure lock screens that hide private content.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val publicBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, ScheduleNotificationManager.CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            publicBuilder
                .setSmallIcon(R.drawable.ic_notification)
                .setLargeIcon(
                    BitmapFactory.decodeResource(
                        context.resources,
                        R.mipmap.launcher_icon,
                    ),
                )
                .setContentTitle(periodName)
                .setContentText(if (periodDetail.isNotBlank()) periodDetail else "In progress")
                .setContentIntent(clickPendingIntent)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_STATUS)
            notification.setPublicVersion(publicBuilder.build())
        }

        // Repair any pre-existing channels whose visibility/importance was set
        // incorrectly by previous versions of the app.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            for (channel in notificationManager.notificationChannels) {
                var changed = false
                if (channel.lockscreenVisibility != Notification.VISIBILITY_PUBLIC) {
                    channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    changed = true
                }
                if (channel.importance < NotificationManager.IMPORTANCE_LOW) {
                    // Don't raise arbitrary channels, but do ensure the live
                    // activity plugin's own channel is at least LOW so it
                    // actually renders.
                    if (channel.id == ScheduleNotificationManager.CHANNEL_ID ||
                        channel.id.contains("live_activity", ignoreCase = true)
                    ) {
                        channel.setImportance(NotificationManager.IMPORTANCE_DEFAULT)
                        changed = true
                    }
                }
                if (changed) {
                    channel.setShowBadge(true)
                    notificationManager.createNotificationChannel(channel)
                }
            }
        }

        // Prime the AlarmManager so the next notification starts as soon as
        // this period ends, even when the phone is locked.
        ScheduleWidgetRenderer.scheduleNextTransition(context, LocalDateTime.now())

        return notification.build()
    }
}

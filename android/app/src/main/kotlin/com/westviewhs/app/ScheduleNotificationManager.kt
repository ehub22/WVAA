package com.westviewhs.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Manages the ongoing school period countdown notification on Android.
 *
 * The notification uses a transparent monochrome Wolverine small icon
 * ([R.drawable.ic_notification]), a large launcher icon, and a live
 * Chronometer countdown. The channel is created with IMPORTANCE_DEFAULT
 * so it is visible on the lock screen (LOW/HIGH/MAX produce either hidden
 * or noisy behaviour depending on the OEM skin).
 *
 * When each period ends, AlarmManager wakes [ScheduleWidgetAlarmReceiver]
 * so the next period's notification starts automatically, even when the
 * phone is locked and the app is in the background.
 */
object ScheduleNotificationManager {

    const val CHANNEL_ID = "schedule_countdown_channel"
    const val NOTIFICATION_ID = 4202

    /** Bumped whenever the channel parameters change so existing installs
     *  pick up the new importance/visibility settings. */
    private const val CHANNEL_VERSION_KEY = "schedule_channel_version"
    private const val CURRENT_CHANNEL_VERSION = 2

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val prefs = context.getSharedPreferences("westview_app_state", Context.MODE_PRIVATE)
            val installedVersion = prefs.getInt(CHANNEL_VERSION_KEY, 0)

            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing == null || installedVersion < CURRENT_CHANNEL_VERSION) {
                // Delete a stale channel so the new importance is honoured
                // (Android does not let you raise importance on an existing
                // channel without deleting and recreating it).
                if (existing != null) {
                    notificationManager.deleteNotificationChannel(CHANNEL_ID)
                }

                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Schedule Countdown",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    // IMPORTANCE_LOW is the right level for an ongoing
                    // silent countdown (no sound, no heads-up, but visible on
                    // the lock screen when visibility is PUBLIC).
                    description = "Westview HS ongoing period countdown notification"
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setShowBadge(true)
                    enableVibration(false)
                    enableLights(false)
                }
                notificationManager.createNotificationChannel(channel)
                prefs.edit().putInt(CHANNEL_VERSION_KEY, CURRENT_CHANNEL_VERSION).apply()
            } else if (existing.lockscreenVisibility != Notification.VISIBILITY_PUBLIC) {
                existing.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                existing.setShowBadge(true)
                notificationManager.createNotificationChannel(existing)
            }
        }
    }

    fun isNotificationEnabled(context: Context): Boolean {
        return try {
            val prefs = HomeWidgetPlugin.getData(context)
            val notifEnabled = prefs.getBoolean("notifications_enabled", true)
            val liveEnabled = prefs.getBoolean("live_activity_enabled", true)
            notifEnabled && liveEnabled
        } catch (_: Exception) {
            true
        }
    }

    fun updateNotification(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (!isNotificationEnabled(context)) {
            notificationManager.cancel(NOTIFICATION_ID)
            return
        }

        val now = LocalDateTime.now()
        val today = now.toLocalDate()
        val periods = ScheduleWidgetRenderer.scheduleFor(context, today)

        val currentPeriod = periods?.firstOrNull {
            now >= it.startsAt(today) && now < it.endsAt(today)
        }

        if (currentPeriod == null) {
            // No active period right now (school's out or before first period).
            notificationManager.cancel(NOTIFICATION_ID)
            return
        }

        ensureChannel(context)

        val remoteViews = RemoteViews(context.packageName, R.layout.live_activity)
        remoteViews.setTextViewText(R.id.period_name, currentPeriod.name)

        if (currentPeriod.detail.isBlank()) {
            remoteViews.setViewVisibility(R.id.period_detail, View.GONE)
        } else {
            remoteViews.setTextViewText(R.id.period_detail, currentPeriod.detail)
            remoteViews.setViewVisibility(R.id.period_detail, View.VISIBLE)
        }

        val endTimeMillis =
            currentPeriod.endsAt(today).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
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

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(BitmapFactory.decodeResource(context.resources, R.mipmap.launcher_icon))
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS)
            .setOnlyAlertOnce(true)
            .setLocalOnly(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setCustomHeadsUpContentView(remoteViews)

            val publicBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
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
                .setContentTitle(currentPeriod.name)
                .setContentText(
                    if (currentPeriod.detail.isNotBlank()) {
                        currentPeriod.detail
                    } else {
                        "In progress"
                    },
                )
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_STATUS)
            builder.setPublicVersion(publicBuilder.build())
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_LOW)
        }

        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    fun cancelNotification(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}

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
 * The notification shows a monochrome Wolverine status icon
 * ([R.drawable.ic_notification]), the launcher icon, and a live `Chronometer`
 * countdown. The channel uses `IMPORTANCE_LOW` so period transitions stay
 * silent during class, and `VISIBILITY_SECRET` so your class schedule doesn't
 * show up on a locked screen.
 *
 * When each period ends, `AlarmManager` wakes [ScheduleWidgetAlarmReceiver] so
 * the next period's countdown starts automatically even while the phone is
 * locked or the app is closed.
 */
object ScheduleNotificationManager {

    const val CHANNEL_ID = "schedule_countdown_channel"
    const val NOTIFICATION_ID = 4202

    /** Bumped whenever channel settings change so existing installs recreate
     *  the channel with the updated importance and lock-screen visibility. */
    private const val CHANNEL_VERSION_KEY = "schedule_channel_version"
    private const val CURRENT_CHANNEL_VERSION = 3

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val prefs = context.getSharedPreferences("westview_app_state", Context.MODE_PRIVATE)
            val installedVersion = prefs.getInt(CHANNEL_VERSION_KEY, 0)

            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing == null || installedVersion < CURRENT_CHANNEL_VERSION) {
                // Delete the old channel first because Android ignores changes
                // to channel importance unless the channel is recreated.
                if (existing != null) {
                    notificationManager.deleteNotificationChannel(CHANNEL_ID)
                }

                val channel = NotificationChannel(
                    CHANNEL_ID,
                    context.getString(R.string.notification_channel_name),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    // IMPORTANCE_LOW keeps the ongoing timer silent without
                    // sounds, vibration, or heads-up popups during class.
                    description = "Westview HS ongoing period countdown notification"
                    // Keep the countdown hidden on a locked screen so someone
                    // walking past your phone can't read your class schedule,
                    // teacher, or room number; details only show after unlock.
                    lockscreenVisibility = Notification.VISIBILITY_SECRET
                    setShowBadge(true)
                    enableVibration(false)
                    enableLights(false)
                }
                notificationManager.createNotificationChannel(channel)
                prefs.edit().putInt(CHANNEL_VERSION_KEY, CURRENT_CHANNEL_VERSION).apply()
            } else if (existing.lockscreenVisibility != Notification.VISIBILITY_SECRET) {
                existing.lockscreenVisibility = Notification.VISIBILITY_SECRET
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
            // SECRET: nothing about the schedule is visible until unlock.
            .setVisibility(Notification.VISIBILITY_SECRET)
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
                // Public (lock-screen / redacted) version: period name only.
                // Teacher, room and course name stay behind the lock screen.
                .setContentTitle(currentPeriod.name)
                .setContentText(context.getString(R.string.widget_in_progress))
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

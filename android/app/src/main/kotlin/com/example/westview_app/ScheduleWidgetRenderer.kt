package com.example.westview_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

/**
 * Shared rendering + scheduling logic for the "Current period" home screen widget.
 *
 * The widget shows the current school period and a live countdown (a RemoteViews
 * [android.widget.Chronometer] that ticks every second inside the launcher without
 * waking the device). Precise [AlarmManager] alarms re-render the widget right
 * after each period transition so the next period is picked up immediately,
 * even when the app is closed.
 *
 * Schedule data is written by the Flutter app (see lib/widget_sync.dart) into
 * the SharedPreferences provided by the home_widget plugin; until the app has
 * run once, built-in defaults (kept in sync with lib/data.dart) are used.
 */
object ScheduleWidgetRenderer {

    /** Action broadcast by the AlarmManager when a period transition happens. */
    const val ACTION_PERIOD_TICK = "com.example.westview_app.action.WIDGET_PERIOD_TICK"

    private const val ALARM_REQUEST_CODE = 4201

    // SharedPreferences keys used by the Flutter side (lib/widget_sync.dart).
    private const val KEY_MON_FRI = "schedule_monfri"
    private const val KEY_TUE_THU = "schedule_tuethu"
    private const val KEY_WED = "schedule_wed"

    /**
     * A single period of the school day, times in minutes since midnight.
     *
     * [name] is the name the student sees (a custom class name such as
     * "Human Body Systems" when one was set in the app's settings) and
     * [detail] is the optional teacher / room line ("Mr. Smith · Rm 402").
     */
    data class Period(
        val name: String,
        val startMinutes: Int,
        val endMinutes: Int,
        val detail: String = "",
    ) {
        fun startsAt(day: LocalDate): LocalDateTime = day.atTime(startMinutes / 60, startMinutes % 60)
        fun endsAt(day: LocalDate): LocalDateTime = day.atTime(endMinutes / 60, endMinutes % 60)
    }

    /** What the widget should currently display. */
    sealed class WidgetState {
        /** A period is running right now; countdown to [targetMillis]. */
        data class Current(val period: Period, val next: Period?, val targetMillis: Long) : WidgetState()

        /** No period is running; countdown to the start of [period]. */
        data class Upcoming(val period: Period, val targetMillis: Long) : WidgetState()

        /** School day is over. */
        data class Done(val nextSchoolDay: LocalDate) : WidgetState()

        /** Weekend / no schedule today. */
        data class NoSchool(val nextSchoolDay: LocalDate, val firstPeriod: Period) : WidgetState()
    }

    // Default schedules, used until the Flutter app has synced its data once.
    // Keep these in sync with lib/data.dart.
    private val defaultMonFri = listOf(
        Period("Period 1", 8 * 60 + 35, 10 * 60),
        Period("Passing", 10 * 60, 10 * 60 + 6),
        Period("The DEN", 10 * 60 + 6, 10 * 60 + 27),
        Period("Passing", 10 * 60 + 27, 10 * 60 + 33),
        Period("Period 2", 10 * 60 + 33, 11 * 60 + 58),
        Period("Lunch", 11 * 60 + 58, 12 * 60 + 33),
        Period("Passing", 12 * 60 + 33, 12 * 60 + 39),
        Period("Period 3", 12 * 60 + 39, 14 * 60 + 4),
        Period("Passing", 14 * 60 + 4, 14 * 60 + 10),
        Period("Period 4", 14 * 60 + 10, 15 * 60 + 35),
    )

    private val defaultTueThu = listOf(
        Period("Period 1", 8 * 60 + 35, 9 * 60 + 56),
        Period("Wolverine Time", 9 * 60 + 56, 10 * 60 + 26),
        Period("Passing", 10 * 60 + 26, 10 * 60 + 32),
        Period("Period 2", 10 * 60 + 32, 11 * 60 + 53),
        Period("Lunch", 11 * 60 + 53, 12 * 60 + 28),
        Period("Passing", 12 * 60 + 28, 12 * 60 + 34),
        Period("SSH", 12 * 60 + 34, 12 * 60 + 47),
        Period("Period 3", 12 * 60 + 47, 14 * 60 + 8),
        Period("Passing", 14 * 60 + 8, 14 * 60 + 14),
        Period("Period 4", 14 * 60 + 14, 15 * 60 + 35),
    )

    private val defaultWed = listOf(
        Period("Period 1", 9 * 60 + 35, 10 * 60 + 44),
        Period("Passing", 10 * 60 + 44, 10 * 60 + 50),
        Period("Period 2", 10 * 60 + 50, 11 * 60 + 59),
        Period("Lunch", 11 * 60 + 59, 12 * 60 + 34),
        Period("Passing", 12 * 60 + 34, 12 * 60 + 40),
        Period("Period 3", 12 * 60 + 40, 13 * 60 + 49),
        Period("Wolverine Time", 13 * 60 + 49, 14 * 60 + 20),
        Period("Passing", 14 * 60 + 20, 14 * 60 + 26),
        Period("Period 4", 14 * 60 + 26, 15 * 60 + 35),
    )

    /** Re-renders every installed widget instance and schedules the next transition alarm. */
    fun renderAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleWidgetProvider::class.java))
        if (ids.isEmpty()) {
            // No widgets on any home screen; nothing to keep alive.
            cancelAlarm(context)
            return
        }

        val state = computeState(context, LocalDateTime.now())
        val views = buildViews(context, state)
        ids.forEach { manager.updateAppWidget(it, views) }
        scheduleNextTransition(context, LocalDateTime.now())
    }

    fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(tickPendingIntent(context))
    }

    // ------------------------------------------------------------------ data

    private fun scheduleKeyFor(day: DayOfWeek): String? = when (day) {
        DayOfWeek.MONDAY, DayOfWeek.FRIDAY -> KEY_MON_FRI
        DayOfWeek.TUESDAY, DayOfWeek.THURSDAY -> KEY_TUE_THU
        DayOfWeek.WEDNESDAY -> KEY_WED
        else -> null
    }

    /** Returns the schedule for [day], or null on weekends. */
    private fun scheduleFor(context: Context, day: LocalDate): List<Period>? {
        val key = scheduleKeyFor(day.dayOfWeek) ?: return null
        val json = HomeWidgetPlugin.getData(context).getString(key, null)
        parsePeriods(json)?.let { return it }
        return when (key) {
            KEY_MON_FRI -> defaultMonFri
            KEY_TUE_THU -> defaultTueThu
            else -> defaultWed
        }
    }

    private fun parsePeriods(json: String?): List<Period>? {
        if (json.isNullOrBlank()) return null
        return try {
            val array = JSONArray(json)
            buildList {
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val name = obj.optString("name")
                    val detail = obj.optString("detail")
                    val start = obj.optInt("start", -1)
                    val end = obj.optInt("end", -1)
                    if (name.isNotBlank() && start >= 0 && end > start) {
                        add(Period(name, start, end, detail))
                    }
                }
            }.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    private fun nextSchoolDayAfter(today: LocalDate): LocalDate {
        var day = today.plusDays(1)
        while (scheduleKeyFor(day.dayOfWeek) == null) {
            day = day.plusDays(1)
        }
        return day
    }

    // ----------------------------------------------------------------- state

    private fun computeState(context: Context, now: LocalDateTime): WidgetState {
        val today = now.toLocalDate()
        val periods = scheduleFor(context, today)

        if (periods == null) {
            val nextSchoolDay = nextSchoolDayAfter(today)
            return WidgetState.NoSchool(
                nextSchoolDay,
                scheduleFor(context, nextSchoolDay)!!.first(),
            )
        }

        val current = periods.firstOrNull { now >= it.startsAt(today) && now < it.endsAt(today) }
        if (current != null) {
            val next = periods.firstOrNull { it.startMinutes > current.startMinutes }
            return WidgetState.Current(current, next, toEpochMillis(current.endsAt(today)))
        }

        val upcoming = periods.firstOrNull { now < it.startsAt(today) }
        if (upcoming != null) {
            return WidgetState.Upcoming(upcoming, toEpochMillis(upcoming.startsAt(today)))
        }

        return WidgetState.Done(nextSchoolDayAfter(today))
    }

    private fun toEpochMillis(dateTime: LocalDateTime): Long =
        dateTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

    // ---------------------------------------------------------------- render

    private fun buildViews(context: Context, state: WidgetState): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget)

        // Tapping anywhere on the widget opens the app.
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )

        when (state) {
            is WidgetState.Current -> {
                views.setTextViewText(R.id.widget_period, state.period.name)
                showDetail(views, state.period.detail)
                views.setTextViewText(R.id.widget_timer_label, "Ends in")
                showCountdown(views, state.targetMillis)
                views.setTextViewText(
                    R.id.widget_subtitle,
                    state.next?.let { "Next: ${it.name} · ${formatTime(it.startMinutes)}" }
                        ?: "Last period of the day",
                )
            }

            is WidgetState.Upcoming -> {
                views.setTextViewText(R.id.widget_period, state.period.name)
                showDetail(views, state.period.detail)
                views.setTextViewText(R.id.widget_timer_label, "Starts in")
                showCountdown(views, state.targetMillis)
                views.setTextViewText(
                    R.id.widget_subtitle,
                    "School starts at ${formatTime(state.period.startMinutes)}",
                )
            }

            is WidgetState.Done -> {
                views.setTextViewText(R.id.widget_period, "School's out")
                showDetail(views, "")
                hideCountdown(views)
                views.setTextViewText(
                    R.id.widget_subtitle,
                    "See you ${dayName(state.nextSchoolDay)}",
                )
            }

            is WidgetState.NoSchool -> {
                views.setTextViewText(R.id.widget_period, "No school today")
                showDetail(views, "")
                hideCountdown(views)
                views.setTextViewText(
                    R.id.widget_subtitle,
                    "${dayName(state.nextSchoolDay)} · ${state.firstPeriod.name} at " +
                        formatTime(state.firstPeriod.startMinutes),
                )
            }
        }

        return views
    }

    /** Shows the teacher / room line, or hides it when there is nothing to show. */
    private fun showDetail(views: RemoteViews, detail: String) {
        if (detail.isBlank()) {
            views.setViewVisibility(R.id.widget_detail, View.GONE)
        } else {
            views.setTextViewText(R.id.widget_detail, detail)
            views.setViewVisibility(R.id.widget_detail, View.VISIBLE)
        }
    }

    private fun showCountdown(views: RemoteViews, targetMillis: Long) {
        views.setViewVisibility(R.id.widget_timer_label, View.VISIBLE)
        views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val remaining = targetMillis - System.currentTimeMillis()
            val base = SystemClock.elapsedRealtime() + remaining.coerceAtLeast(0L)
            // "%s" makes the Chronometer render H:MM:SS (or MM:SS); it ticks
            // every second in the launcher process without any wakeups.
            views.setChronometer(R.id.widget_countdown, base, "%s", true)
            views.setChronometerCountDown(R.id.widget_countdown, true)
        } else {
            // Pre-API 24 fallback (unreachable with minSdk 24): static text.
            val minutesLeft = ((targetMillis - System.currentTimeMillis()).coerceAtLeast(0L) / 60_000) + 1
            views.setTextViewText(R.id.widget_countdown, "$minutesLeft min")
        }
    }

    private fun hideCountdown(views: RemoteViews) {
        views.setViewVisibility(R.id.widget_timer_label, View.GONE)
        views.setViewVisibility(R.id.widget_countdown, View.GONE)
    }

    // ---------------------------------------------------------------- alarms

    private fun tickPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ScheduleWidgetAlarmReceiver::class.java)
            .setAction(ACTION_PERIOD_TICK)
        return PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Schedules a single exact alarm for the next moment the widget content
     * changes: the next period start/end today, or the next school day.
     */
    private fun scheduleNextTransition(context: Context, now: LocalDateTime) {
        val today = now.toLocalDate()
        val candidates = mutableListOf<LocalDateTime>()

        scheduleFor(context, today)?.let { periods ->
            periods.forEach {
                candidates += it.startsAt(today)
                candidates += it.endsAt(today)
            }
        }

        val nextSchoolDay = nextSchoolDayAfter(today)
        candidates += nextSchoolDay.atTime(0, 5) // re-render when the new day begins
        scheduleFor(context, nextSchoolDay)?.let { periods ->
            periods.forEach {
                candidates += it.startsAt(nextSchoolDay)
                candidates += it.endsAt(nextSchoolDay)
            }
        }

        val next = candidates.filter { it.isAfter(now) }.minOrNull()
        val alarmAt = if (next != null) {
            toEpochMillis(next) + 1_500
        } else {
            // Should not happen (a next school day always exists), but keep a
            // daily fallback so the widget can never go permanently stale.
            toEpochMillis(now.plusDays(1))
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = tickPendingIntent(context)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarmAt, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, alarmAt, pendingIntent)
            }
        } catch (_: SecurityException) {
            // SCHEDULE_EXACT_ALARM not granted (Android 12+): fall back to an
            // inexact alarm; updates may then lag by a few minutes.
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarmAt, pendingIntent)
        }
    }

    // --------------------------------------------------------------- helpers

    /** Formats minutes-since-midnight as e.g. "8:35 AM". */
    private fun formatTime(minutes: Int): String {
        val hour24 = minutes / 60
        val minute = minutes % 60
        val suffix = if (hour24 < 12) "AM" else "PM"
        val hour12 = when {
            hour24 == 0 -> 12
            hour24 > 12 -> hour24 - 12
            else -> hour24
        }
        return "$hour12:${minute.toString().padStart(2, '0')} $suffix"
    }

    /** e.g. "Monday". */
    private fun dayName(day: LocalDate): String =
        day.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
}

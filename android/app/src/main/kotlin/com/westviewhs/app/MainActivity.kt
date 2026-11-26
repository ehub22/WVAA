package com.westviewhs.app

import android.content.res.Configuration
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.live_activities.LiveActivityManagerHolder
import cl.puntito.simple_pip_mode.PipCallbackHelper

class MainActivity : FlutterActivity() {
    private val pipCallbackHelper = PipCallbackHelper()

    /// Student-safety controls exposed to Dart through `safety.dart`.
    private val safetyChannel = "com.westviewhs.app/safety"

    /// Whether the app's content should be hidden in the recents thumbnail.
    private var hideRecents = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Wire up PiP callbacks so Dart receives PiP enter/exit events.
        pipCallbackHelper.configureFlutterEngine(flutterEngine)

        // Wire the live_activities plugin to our custom notification renderer.
        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)

        // Create the countdown notification channel with proper lockscreen
        // visibility before any notification is ever posted.
        ScheduleNotificationManager.ensureChannel(this)

        // Safety channel: quick exit + recents privacy. Both are best-effort
        // and never throw into Dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, safetyChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "moveTaskToBack" -> {
                            // Return to whatever was on screen before the app
                            // (usually the launcher) without killing the task,
                            // so nothing is lost and nothing lingers on screen.
                            moveTaskToBack(true)
                            result.success(true)
                        }
                        "setRecentsPrivacy" -> {
                            hideRecents = call.argument<Boolean>("hide") ?: true
                            applyRecentsPrivacy()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Throwable) {
                    // Never surface a platform failure to the student: they may
                    // be leaving the app in a hurry.
                    if (call.method == "moveTaskToBack") result.success(false) else result.success(null)
                }
            }

        applyRecentsPrivacy()
    }

    /// Hides the app's content from the recents/app-switcher preview when the
    /// student asked for it.
    ///
    /// Android only offers one mechanism for blanking the system snapshot
    /// (`FLAG_SECURE`), and it also blocks screenshots — so the flag is set
    /// only while the app is in the background (this is called from onPause
    /// and when the setting changes), and always cleared on resume. Net
    /// effect: your own timetable still screenshots fine; the thumbnail in the
    /// app switcher is blank.
    private fun applyRecentsPrivacy() {
        try {
            if (hideRecents) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        } catch (_: Throwable) {
            // Some OEM builds reject flag changes; ignore.
        }
    }

    /// Set the privacy flag as the app leaves the foreground, so the snapshot
    /// the system captures for recents is blank (see applyRecentsPrivacy).
    override fun onPause() {
        if (hideRecents) applyRecentsPrivacy()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        try {
            // Forward: while the app is visible, screenshots/screen recording
            // of the student's own timetable must keep working.
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } catch (_: Throwable) {
        }
        // Re-assert channel settings every resume: if the channel's lockscreen
        // visibility was loosened (by the user or an OEM) so that class details
        // could leak onto a locked phone, repair it back to SECRET.
        ScheduleNotificationManager.ensureChannel(this)
    }
}

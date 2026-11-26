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

    /// Blanks out the app's preview in Android's recent-apps switcher when
    /// enabled in Settings.
    ///
    /// Android's `FLAG_SECURE` blanks the recent-apps snapshot, though it also
    /// blocks screenshots while set. To avoid breaking normal screenshots, I
    /// only set `FLAG_SECURE` when the app pauses into the background and clear
    /// it again in `onResume()`, so you can still screenshot your own class
    /// schedule while the app-switcher preview stays blank.
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

    /// Turn `FLAG_SECURE` on as the activity leaves the foreground so Android's
    /// recent-apps snapshot comes out blank.
    override fun onPause() {
        if (hideRecents) applyRecentsPrivacy()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        try {
            // Clear `FLAG_SECURE` while the app is open in front of you so
            // taking screenshots of your own class schedule still works.
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } catch (_: Throwable) {
        }
        // Re-check notification channel settings on every resume so if the
        // lock-screen visibility got loosened in system settings, it resets
        // back to `VISIBILITY_SECRET`.
        ScheduleNotificationManager.ensureChannel(this)
    }
}

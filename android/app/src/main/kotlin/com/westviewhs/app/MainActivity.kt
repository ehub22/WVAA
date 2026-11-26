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

    /// True while the activity is the picture-in-picture window.
    ///
    /// `FLAG_SECURE` is inherited by the PiP window, and Android draws a secure
    /// window as a blank rectangle inside PiP. So the flag has to come off the
    /// moment the activity shrinks, or a student who leaves the app mid-video
    /// gets a black box where the video should be.
    private var inPictureInPicture = false

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
            // Never secure the PiP window: it would blank the video.
            if (hideRecents && !inPictureInPicture) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        } catch (_: Throwable) {
            // Some OEM builds reject flag changes; ignore.
        }
    }

    /// Keeps the recents-privacy flag from blanking the PiP window, and turns
    /// it back on once the app returns to its normal full-screen size.
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        inPictureInPicture = isInPictureInPictureMode
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        applyRecentsPrivacy()
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

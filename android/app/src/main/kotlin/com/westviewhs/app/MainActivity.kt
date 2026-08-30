package com.westviewhs.app

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.live_activities.LiveActivityManagerHolder
import cl.puntito.simple_pip_mode.PipCallbackHelper

class MainActivity : FlutterActivity() {
    private val pipCallbackHelper = PipCallbackHelper()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Wire up PiP callbacks so Dart receives PiP enter/exit events.
        pipCallbackHelper.configureFlutterEngine(flutterEngine)

        // Wire the live_activities plugin to our custom notification renderer.
        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)

        // Create the countdown notification channel with proper lockscreen
        // visibility before any notification is ever posted.
        ScheduleNotificationManager.ensureChannel(this)
    }

    override fun onResume() {
        super.onResume()
        // Re-assert channel settings every resume — if the user changed the
        // channel's lockscreen visibility or importance from system settings
        // between launches, we repair it back to the expected defaults (the
        // countdown must be visible over the lock screen to be useful).
        ScheduleNotificationManager.ensureChannel(this)
    }

    override fun onPictureInPictureModeChanged(
        active: Boolean,
        newConfig: Configuration?,
    ) {
        super.onPictureInPictureModeChanged(active, newConfig)
        pipCallbackHelper.onPictureInPictureModeChanged(active)
    }
}

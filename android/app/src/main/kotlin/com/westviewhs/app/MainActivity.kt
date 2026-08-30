package com.westviewhs.app

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.live_activities.LiveActivityManagerHolder
import cl.puntito.simple_pip_mode.PipCallbackHelper

class MainActivity: FlutterActivity() {
    private val pipCallbackHelper = PipCallbackHelper()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipCallbackHelper.configureFlutterEngine(flutterEngine)
        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)
        ScheduleNotificationManager.ensureChannel(this)
    }

    override fun onPictureInPictureModeChanged(
        active: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(active, newConfig)
        pipCallbackHelper.onPictureInPictureModeChanged(active)
    }
}

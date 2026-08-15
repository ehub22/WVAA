package com.example.westview_app

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.live_activities.LiveActivityManagerHolder
import cl.puntito.simple_pip_mode.PipCallbackHelper

class MainActivity: FlutterActivity() {
    private val pipCallbackHelper = PipCallbackHelper()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up PiP callback helper so Dart can receive PiP events
        pipCallbackHelper.configureFlutterEngine(flutterEngine)

        // Let the live_activities package know you have a custom manager configured
        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)
    }

    override fun onPictureInPictureModeChanged(
        active: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(active, newConfig)
        pipCallbackHelper.onPictureInPictureModeChanged(active)
    }
}
package com.example.westview_app

import io.flutter.embedding.engine.FlutterEngine
import com.example.live_activities.LiveActivityManagerHolder
import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper

class MainActivity: PipCallbackHelperActivityWrapper() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Let the live_activities package know you have a custom manager configured
        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)
    }
}
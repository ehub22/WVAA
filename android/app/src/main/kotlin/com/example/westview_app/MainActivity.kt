package com.example.westview_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.live_activities.LiveActivityManagerHolder

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Let the live_activities package know you have a custom manager configured
        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)
    }
}
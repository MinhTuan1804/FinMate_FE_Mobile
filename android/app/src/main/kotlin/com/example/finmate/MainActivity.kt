package com.example.finmate

import com.example.finmate.notifications.NotificationChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationChannelHandler(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}

package com.finmate.app.bubble

import android.content.Context
import com.finmate.app.notifications.NotificationChannelHandler
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Nội dung cửa sổ nổi khi bấm bong bóng FinMate AI. Chạy FlutterEngine riêng ở entrypoint
 * `assistantBubbleMain` (lib/assistant_bubble_main.dart): cùng FinMateApp nhưng mở thẳng màn trợ lý.
 * Engine riêng nên phiên chat ở đây độc lập với phiên chat trong app chính.
 */
open class AssistantBubbleActivity : FlutterActivity() {
    private lateinit var bubbleChannel: AssistantBubbleChannel

    // Tự tạo engine và chạy đúng entrypoint (cùng lý do như WidgetConfigActivity).
    override fun provideFlutterEngine(context: Context): FlutterEngine = createAssistantEngine(context)

    companion object {
        fun createAssistantEngine(context: Context, entrypoint: String = "assistantBubbleMain"): FlutterEngine {
            val engine = FlutterEngine(context)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "package:finmate/assistant_bubble_main.dart",
                    entrypoint,
                ),
            )
            return engine
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // FinMateApp có NotificationCaptureScope gọi kênh này: thiếu thì Dart nhận MissingPluginException.
        NotificationChannelHandler(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        bubbleChannel = AssistantBubbleChannel(this).also { it.register(flutterEngine.dartExecutor.binaryMessenger) }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (!bubbleChannel.onRequestPermissionsResult(requestCode, grantResults)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}

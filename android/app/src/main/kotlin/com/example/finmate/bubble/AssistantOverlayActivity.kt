package com.example.finmate.bubble

import android.content.Context
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine

/**
 * Khung chat mở khi chạm bong bóng vẽ đè ([AssistantOverlayService]), dáng Messenger: cửa sổ TRONG SUỐT toàn
 * màn hình, Flutter tự vẽ khung chat bo góc ngay dưới bong bóng kèm mũi nhọn chỉ lên bong bóng
 * (lib/features/assistant/presentation/widgets/assistant_overlay_frame.dart); vùng trống phía trên vẫn thấy
 * app đang dùng, chạm vào đó để thu khung lại.
 * Giữ FlutterEngine sống giữa các lần mở để không khởi động lại và không mất cuộc chat; huỷ khi tắt bong bóng.
 */
class AssistantOverlayActivity : AssistantBubbleActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        engine ?: createAssistantEngine(context.applicationContext, "assistantOverlayMain").also { engine = it }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    // Trong suốt để thấy app phía sau ở vùng trên khung chat.
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onResume() {
        super.onResume()
        current = this
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
        // Đóng bằng back/chạm ra ngoài/nút phóng to: báo service đưa bong bóng về chỗ cũ.
        if (isFinishing) AssistantOverlayService.onPanelClosed()
    }

    companion object {
        private var engine: FlutterEngine? = null

        /** Khung đang mở (để service thu lại khi chạm bong bóng lần nữa). */
        var current: AssistantOverlayActivity? = null
            private set

        fun releaseEngine() {
            engine?.destroy()
            engine = null
        }
    }
}

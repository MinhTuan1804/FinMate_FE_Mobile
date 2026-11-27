package com.finmate.app.notifications

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationChannelHandler(private val context: Context) {
    private val runtime get() = NotificationRuntime.get(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(::onCall)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openNotificationAccessSettings" -> try {
                context.startActivity(
                    Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(null)
            } catch (e: Exception) {
                result.error("native_error", e.javaClass.simpleName, null)
            }
            // Còn lại đều đụng tới kho mã hóa/mạng nên chạy ngoài luồng chính, trả kết quả về luồng chính.
            else -> NotificationRuntime.ioExecutor.execute {
                try {
                    val value = handleOffMain(call)
                    mainHandler.post {
                        if (value === NOT_IMPLEMENTED) result.notImplemented() else result.success(value)
                    }
                } catch (e: Exception) {
                    // Chỉ trả tên lỗi, không trả message vì có thể chứa dữ liệu nhạy cảm.
                    mainHandler.post { result.error("native_error", e.javaClass.simpleName, null) }
                }
            }
        }
    }

    private fun handleOffMain(call: MethodCall): Any? {
        val rt = runtime
        return when (call.method) {
            "setSession" -> {
                val baseUrl = call.argument<String>("baseUrl")
                val access = call.argument<String>("accessToken")
                val refresh = call.argument<String>("refreshToken")
                require(baseUrl != null && access != null && refresh != null)
                // writeLock: một refresh đang bay không được ghi đè phiên mới này (xem TokenRefresher).
                synchronized(rt.refresher.writeLock) {
                    rt.store.baseUrl = baseUrl
                    rt.store.saveTokens(access, refresh)
                    rt.store.sessionExpired = false
                }
                // Có phiên thì mới có ai để báo trạng thái listener thay.
                ListenerStatusScheduler.schedule(context)
                null
            }
            "clearSession" -> {
                // Cùng khóa với việc thêm vào hàng đợi của service. Xóa gói theo dõi và token TRƯỚC khi xóa hàng đợi
                // để sau khi hàng đợi rỗng không còn gì mới lọt vào.
                synchronized(rt) {
                    rt.monitored.clear()
                    synchronized(rt.refresher.writeLock) {
                        rt.store.clearTokens()
                        rt.store.baseUrl = null
                        rt.store.sessionExpired = false
                    }
                    rt.queue.clear()
                }
                ListenerStatusScheduler.cancel(context)
                // Người dùng sau phải báo lại từ đầu, không kế thừa "đã báo" của tài khoản trước.
                rt.statusStore.lastReportKey = null
                null
            }
            "flushQueue" -> {
                rt.drainAsync()
                null
            }
            "getAccessToken" -> rt.store.accessToken
            "getRefreshToken" -> rt.store.refreshToken
            "refreshSession" -> when (val r = rt.refresher.refresh(call.argument<String>("staleAccessToken"))) {
                is RefreshResult.Ok -> mapOf("status" to "ok", "accessToken" to r.accessToken)
                RefreshResult.Expired -> mapOf("status" to "expired")
                RefreshResult.Network -> mapOf("status" to "network")
            }
            "setMonitoredPackages" -> {
                val list = call.argument<List<*>>("packages")?.filterIsInstance<String>() ?: emptyList()
                rt.monitored.set(list)
                null
            }
            "isNotificationAccessEnabled" -> isNotificationAccessEnabled(context)
            // Quyền có thể vừa đổi trong Cài đặt: Flutter gọi mỗi lần app mở lại; chỉ gửi khi trạng thái đổi hoặc đã lâu chưa báo.
            "reportListenerStatus" -> rt.listenerStatus.report(force = false).name.lowercase()
            "consumeSessionExpired" -> rt.store.sessionExpired.also { if (it) rt.store.sessionExpired = false }
            else -> NOT_IMPLEMENTED
        }
    }

    private companion object {
        const val CHANNEL = "com.finmate.app/notifications"
        val NOT_IMPLEMENTED = Any()
    }
}

package com.example.finmate.notifications

import android.app.Notification
import android.content.ComponentName
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.UUID

/** Không gọi Log với tiêu đề/nội dung/token ở bất cứ đâu trong lớp này. */
class NotificationCaptureService : NotificationListenerService() {
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            if (sbn == null) return
            val runtime = NotificationRuntime.get(applicationContext)
            if (!runtime.monitored.contains(sbn.packageName)) return

            val extras = sbn.notification?.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            val body = if (!big.isNullOrBlank()) big else extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
            if (title.isBlank() && body.isBlank()) return

            // Cùng khóa với clearSession: kiểm tra phiên và thêm vào hàng đợi phải liền nhau, nếu không một thông báo
            // của tài khoản vừa đăng xuất có thể lọt vào hàng đợi sau khi đã xóa và bị gửi bằng tài khoản đăng nhập sau.
            // Chưa đăng nhập thì bỏ luôn, không giữ nội dung.
            synchronized(runtime) {
                if (runtime.store.refreshToken == null) return
                runtime.queue.add(
                    QueuedNotification(UUID.randomUUID().toString(), sbn.packageName, title, body, System.currentTimeMillis())
                )
            }
            runtime.drainAsync()
        } catch (e: Exception) {
            // Service không được crash vì một thông báo lỗi; không log vì có thể chứa nội dung.
        }
    }

    override fun onListenerConnected() {
        unregisterNetworkCallback()
        try {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            val cb = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    // Chạy trên luồng của ConnectivityManager: exception ở đây (vd. Keystore hỏng khi dựng runtime) sẽ làm sập cả app.
                    try {
                        NotificationRuntime.get(applicationContext).drainAsync()
                    } catch (e: Exception) {
                        // Bỏ qua im lặng; không log.
                    }
                }
            }
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            cm.registerNetworkCallback(request, cb)
            networkCallback = cb
        } catch (e: Exception) {
            // Không đăng ký được thì vẫn còn đường thử lại khi có thông báo mới hoặc khi mở app.
        }
    }

    override fun onListenerDisconnected() {
        unregisterNetworkCallback()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, javaClass))
        }
    }

    override fun onDestroy() {
        unregisterNetworkCallback()
        super.onDestroy()
    }

    private fun unregisterNetworkCallback() {
        val cb = networkCallback ?: return
        networkCallback = null
        try {
            (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(cb)
        } catch (e: Exception) {
            // Đã hủy rồi hoặc chưa đăng ký: bỏ qua.
        }
    }
}

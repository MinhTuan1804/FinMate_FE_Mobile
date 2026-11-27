package com.finmate.app.notifications

import android.content.Context
import android.os.Build
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Gom các thành phần dùng chung giữa service và channel Flutter (cùng một tiến trình, cùng một khóa refresh). */
class NotificationRuntime private constructor(context: Context) {
    // noBackupFilesDir: nội dung thông báo ngân hàng không được sao lưu lên Google Drive rồi phát lại sau khi khôi phục.
    val queue = NotificationQueue(File(context.noBackupFilesDir, QUEUE_FILE)).also {
        // Bản cũ nằm trong filesDir (được sao lưu): xóa một lần, kèm file tạm nếu còn.
        File(context.filesDir, QUEUE_FILE).delete()
        File(context.filesDir, "$QUEUE_FILE.tmp").delete()
    }
    val store: SessionStore = EncryptedSessionStore(context)
    val monitored = MonitoredPackages(context)
    val refresher = TokenRefresher(store, UrlConnectionRefreshHttp())
    private val sender = NotificationSender(queue, store, refresher, UrlConnectionAnalyzeHttp())
    val statusStore: ListenerStatusStore = SharedPrefsListenerStatusStore(context)
    val listenerStatus = ListenerStatusReporter(
        session = store,
        refresher = refresher,
        monitoredPackages = { monitored.all() },
        statusStore = statusStore,
        http = UrlConnectionListenerStatusHttp(),
        device = {
            DeviceFacts(
                permissionGranted = isNotificationAccessEnabled(context),
                appVersion = try {
                    context.packageManager.getPackageInfo(context.packageName, 0).versionName
                } catch (e: Exception) {
                    null
                },
                manufacturer = Build.MANUFACTURER,
            )
        },
    )

    // Đơn luồng: drain đã @Synchronized nên chạy song song cũng chỉ xếp hàng chờ.
    private val drainExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    fun drainAsync() {
        drainExecutor.execute {
            try {
                sender.drain()
            } catch (e: Exception) {
                // Không log: lỗi có thể chứa nội dung thông báo. Mục còn trong hàng đợi, lần sau thử lại.
            }
        }
    }

    /** Báo trạng thái listener ngoài luồng gọi (service nối/ngắt chạy trên luồng chính). Lỗi bị nuốt: lần báo hằng ngày sẽ bù. */
    fun reportListenerStatusAsync(force: Boolean = false) {
        ioExecutor.execute {
            try {
                listenerStatus.report(force)
            } catch (e: Exception) {
                // Không log.
            }
        }
    }

    companion object {
        private const val QUEUE_FILE = "notification_queue.json"

        @Volatile private var instance: NotificationRuntime? = null

        /**
         * Luồng cho việc của channel (kho mã hóa, refresh qua mạng), tách khỏi drainExecutor để không kẹt sau một lượt drain dài.
         * Nằm ở companion để luồng chính không phải dựng runtime (mở Keystore) chỉ để lấy executor.
         */
        val ioExecutor: ExecutorService = Executors.newCachedThreadPool()

        fun get(context: Context): NotificationRuntime = instance ?: synchronized(this) {
            instance ?: NotificationRuntime(context.applicationContext).also { instance = it }
        }
    }
}

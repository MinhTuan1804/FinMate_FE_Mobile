package com.finmate.app.notifications

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/** Mỗi ngày một lần báo trạng thái dịch vụ đọc thông báo (BR-LH-01), chạy cả khi app đã bị kill. */
class ListenerStatusWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = try {
        when (NotificationRuntime.get(applicationContext).listenerStatus.report(force = true)) {
            ReportResult.Retry -> Result.retry()
            // Chưa đăng nhập hoặc bị từ chối: không có gì để thử lại; ngày mai chạy tiếp.
            ReportResult.Sent, ReportResult.Skipped, ReportResult.NoSession -> Result.success()
        }
    } catch (e: Exception) {
        // Không log: payload gắn với danh sách ví của người dùng.
        Result.retry()
    }
}

object ListenerStatusScheduler {
    private const val WORK_NAME = "listener_status_daily"

    /** Gọi khi có phiên đăng nhập (setSession); KEEP nên gọi nhiều lần không đặt lại giờ chạy. */
    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<ListenerStatusWorker>(24, TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    /** Gọi khi đăng xuất: không còn tài khoản để báo thay. */
    fun cancel(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(WORK_NAME)
    }
}

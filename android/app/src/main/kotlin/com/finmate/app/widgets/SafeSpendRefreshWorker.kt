package com.finmate.app.widgets

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.glance.appwidget.updateAll
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Làm mới dữ liệu W1 ở nền — chạy cả khi app FinMate đã bị kill hẳn (không phụ thuộc Flutter
 * engine, xem SafeSpendSync). */
class SafeSpendRefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val ok = SafeSpendSync.refresh(applicationContext)
        SafeSpendWidget().updateAll(applicationContext)
        if (ok) Result.success() else Result.retry()
    }

    companion object {
        private const val PERIODIC_WORK_NAME = "w1_safe_spend_periodic_sync"
        private const val ONE_OFF_WORK_NAME = "w1_safe_spend_one_off_sync"

        /** Gọi khi widget đầu tiên được ghim (onEnabled) — giữ nguyên nếu đã có lịch chạy rồi
         * (ExistingPeriodicWorkPolicy.KEEP), không reset lại chu kỳ mỗi lần Android gọi lại onUpdate. */
        fun schedulePeriodic(context: Context) {
            val request = PeriodicWorkRequestBuilder<SafeSpendRefreshWorker>(30, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(PERIODIC_WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        fun cancelPeriodic(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(PERIODIC_WORK_NAME)
        }

        /** Đồng bộ ngay 1 lần — gọi khi vừa thêm widget mới hoặc vừa sửa cấu hình, không chờ tới
         * chu kỳ 30 phút kế tiếp. `setExpedited` xin chạy ngay (không bị Doze/App Standby hoãn tới lúc
         * app được foreground) — RUN_AS_NON_EXPEDITED_WORK_REQUEST tự rơi về work thường nếu hết quota
         * expedited, không bao giờ crash. */
        fun syncNow(context: Context) {
            val request = OneTimeWorkRequestBuilder<SafeSpendRefreshWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(ONE_OFF_WORK_NAME, ExistingWorkPolicy.REPLACE, request)
        }
    }
}

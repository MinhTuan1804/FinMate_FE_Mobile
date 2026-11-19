package com.example.finmate.widgets

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

/** Làm mới dữ liệu W2 ở nền — cùng mẫu với SafeSpendRefreshWorker (W1), chạy cả khi app đã bị kill. */
class OverviewRefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val ok = OverviewSync.refresh(applicationContext)
        OverviewWidget().updateAll(applicationContext)
        if (ok) Result.success() else Result.retry()
    }

    companion object {
        private const val PERIODIC_WORK_NAME = "w2_overview_periodic_sync"
        private const val ONE_OFF_WORK_NAME = "w2_overview_one_off_sync"
        private const val DEFAULT_MINUTES = 30L
        private const val BATTERY_SAVER_MINUTES = 120L

        /** Gọi khi widget đầu tiên được ghim (onEnabled) — chu kỳ theo đúng "refreshMode" đã lưu
         * trong màn cấu hình (xem WidgetConfig.refreshMode), mặc định 30 phút nếu chưa cấu hình gì. */
        fun schedulePeriodic(context: Context) {
            val minutes = if (isBatterySaver(context)) BATTERY_SAVER_MINUTES else DEFAULT_MINUTES
            val request = PeriodicWorkRequestBuilder<OverviewRefreshWorker>(minutes, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(PERIODIC_WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
        }

        fun cancelPeriodic(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(PERIODIC_WORK_NAME)
        }

        /** Đồng bộ ngay 1 lần — gọi khi vừa ghim widget mới hoặc vừa sửa cấu hình. `setExpedited` xin
         * chạy ngay (không bị Doze/App Standby hoãn tới lúc app được foreground), xem
         * SafeSpendRefreshWorker.syncNow để biết lý do/cách rơi về work thường an toàn. */
        fun syncNow(context: Context) {
            val request = OneTimeWorkRequestBuilder<OverviewRefreshWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(ONE_OFF_WORK_NAME, ExistingWorkPolicy.REPLACE, request)
        }

        /** `getGlanceIds` là suspend, nhưng gọi từ [schedulePeriodic] — tới từ `onEnabled` (không
         * suspend, override của Android) — nên phải chặn bằng `runBlocking` ở đúng 1 điểm gọi nhanh
         * (đọc SharedPreferences, không I/O mạng) thay vì đổi chữ ký `schedulePeriodic`/`onEnabled`. */
        private fun isBatterySaver(context: Context): Boolean = runBlocking {
            try {
                val manager = GlanceAppWidgetManager(context)
                val ids = manager.getGlanceIds(OverviewWidget::class.java)
                if (ids.isEmpty()) return@runBlocking false
                val widgetId = manager.getAppWidgetId(ids.first())
                context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
                    .getString("refreshMode_$widgetId", null) == "batterySaver"
            } catch (e: Exception) {
                false
            }
        }
    }
}

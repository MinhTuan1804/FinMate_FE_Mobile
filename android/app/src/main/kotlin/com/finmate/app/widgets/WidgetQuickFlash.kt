package com.finmate.app.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import com.finmate.app.R
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.abs

/**
 * Thử nghiệm (2026-11-17): đẩy thẳng 1 bản RemoteViews CỔ ĐIỂN (không qua Glance — không có
 * Session/SessionWorker) ngay sau khi *Sync.refresh() xong, bằng đúng
 * `AppWidgetManager.updateAppWidget()` — API cũ, đồng bộ, không qua WorkManager. Mục đích: xem có
 * tránh được độ trễ của Glance session hay không (đã đo thật: dữ liệu mới đã nằm ở hệ thống
 * `dumpsys appwidget` nhưng launcher không vẽ lại ngay cho tới khi mở lại app).
 *
 * Nếu cách này KHÔNG cải thiện độ trễ, hoặc gây giật/không nhất quán giữa bản thô sơ này và bản
 * đẹp (vòng tròn %, màu trạng thái...) Glance vẽ sau đó — bỏ hẳn: xoá lời gọi `flashXxx()` ở
 * MainActivity.kt, xoá file này + widget_quick_flash.xml, giữ nguyên `*Widget().updateAll()`.
 */
object WidgetQuickFlash {
    private fun formatVnd(cents: Long): String {
        val formatter = NumberFormat.getNumberInstance(Locale.forLanguageTag("vi-VN"))
        formatter.maximumFractionDigits = 0
        return "${formatter.format(cents)} đ"
    }

    private fun push(context: Context, receiverClass: Class<*>, title: String, amount: String, subtitle: String) {
        val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, receiverClass))
        if (ids.isEmpty()) return
        val views = RemoteViews(context.packageName, R.layout.widget_quick_flash).apply {
            setTextViewText(R.id.quick_title, title)
            setTextViewText(R.id.quick_amount, amount)
            setTextViewText(R.id.quick_subtitle, subtitle)
        }
        AppWidgetManager.getInstance(context).updateAppWidget(ids, views)
    }

    fun flashW1(context: Context, data: SafeSpendPrefs.Data) {
        val over = data.percentUsed >= 100f
        push(
            context,
            SafeSpendWidgetReceiver::class.java,
            "FinMate",
            if (over) "Vượt ${formatVnd(abs(data.perDayCents))}" else formatVnd(data.perDayCents),
            "${data.percentUsed.toInt()}% ngân sách tháng",
        )
    }

    fun flashW2(context: Context, data: OverviewPrefs.Data) {
        push(
            context,
            OverviewWidgetReceiver::class.java,
            "SỐ DƯ KHẢ DỤNG",
            formatVnd(data.balanceCents),
            if (data.hasBudget) "Đã dùng ${data.percentUsed.toInt()}% ngân sách tháng" else "Chưa đặt ngân sách",
        )
    }

    fun flashDetail(context: Context, data: DetailPrefs.Data) {
        push(
            context,
            DetailWidgetReceiver::class.java,
            "SỐ DƯ KHẢ DỤNG",
            formatVnd(data.balanceCents),
            "Đã ghi ${data.transactionsTodayCount} giao dịch hôm nay",
        )
    }
}

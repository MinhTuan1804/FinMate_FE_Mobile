package com.finmate.app.widgets

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.finmate.app.MainActivity
import com.finmate.app.R
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * W1 "Hôm nay" (2×1) — nội dung thật (đợt build riêng cho W1, xem kế hoạch chia nhỏ Luồng 9):
 * đọc dữ liệu đã đồng bộ sẵn bởi [SafeSpendRefreshWorker] (WorkManager nền, 30 phút/lần, không phụ
 * thuộc Flutter engine đang chạy hay không) qua [SafeSpendPrefs]. Theo đúng
 * `design_reference/W_widgets/w1_states.png`: đang đồng bộ lần đầu / an toàn &lt;80% / lưu ý
 * 80-100% / vượt &gt;100% (+ nhánh phụ "chưa đặt ngân sách" khi BE chưa có `spendableCents`).
 */
class SafeSpendWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = SafeSpendPrefs.read(context)
        // Trạng thái vượt ngân sách: mở /planning qua ActionCallback thật (không qua Intent) — Intent
        // extra đã bị nghi rơi mất qua lớp Background-Activity-Launch-workaround của Glance, cùng gốc
        // với bug trampoline "Page Not Found" trước đó.
        // Chạm vào thẻ = ghi một khoản chi ngay (việc làm nhiều nhất trong ngày); chưa có số liệu thì chỉ mở app.
        val openAppAction = if (data != null && data.hasBudget) {
            actionRunCallback<OpenQuickAddCallback>()
        } else {
            actionStartActivity(Intent(context, MainActivity::class.java))
        }

        provideContent {
            GlanceTheme {
                Box(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .cornerRadius(20.dp)
                        .background(SafeSpendColors.cardBg)
                        .clickable(openAppAction)
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                ) {
                    when {
                        data == null -> SyncingContent()
                        !data.hasBudget -> NoBudgetContent()
                        else -> SpendableContent(data)
                    }
                }
            }
        }
    }
}

/** Ghi "pendingRoute" vào đúng file SharedPreferences mà `home_widget` dùng rồi mở app — Dart đọc lại
 * qua `HomeWidget.getWidgetData` (đã dùng ổn định để đọc dữ liệu W1), không cần MethodChannel/Intent.
 * internal (không private): W2 (OverviewWidget.kt) dùng lại đúng cơ chế này, không viết lại. */
internal fun openAppAtRoute(context: Context, route: String) {
    context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE).edit()
        .putString("pendingRoute", route).apply()
    context.startActivity(
        Intent(context, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK },
    )
}

class OpenPlanningCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        openAppAtRoute(context, "/planning")
    }
}

/** Chạm vào header (icon + "FinMate • ...") ở cả 4 trạng thái — mở màn cấu hình widget (Cài đặt →
 * "Widget trên màn hình chính"), tách riêng khỏi vùng chạm còn lại của card (mở app/Bù đắp ngân sách). */
class OpenWidgetSettingsCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        openAppAtRoute(context, "/widget-settings?kind=w1")
    }
}

@Composable
private fun SyncingContent() {
    Column(
        modifier = GlanceModifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "FinMate",
            style = TextStyle(color = SafeSpendColors.textPrimary, fontWeight = FontWeight.Bold),
        )
        Text(text = "Đang đồng bộ…", style = TextStyle(color = SafeSpendColors.textSecondary))
    }
}

/** Một hàng: nhãn nhỏ (có biểu tượng) và số tiền lớn bên dưới; không còn khoảng trống trên dưới như bản 2×2.
 * Số lớn là "hôm nay còn chi được bao nhiêu"; tháng đã vượt thì "Vượt X" (rút gọn: "10,9 tr"). Chạm vào thẻ = ghi một khoản chi. */
@Composable
private fun SpendableContent(data: SafeSpendPrefs.Data) {
    val over = data.over
    val caution = !over && data.percentUsed >= 80f
    val remaining = (data.perDayCents - data.spentTodayCents).coerceAtLeast(0L)
    val bigText = when {
        data.overMonth -> if (data.monthOverCents > 0) "Vượt ${formatVndShort(data.monthOverCents)}" else "Hết mức"
        else -> formatVndShort(remaining)
    }
    val label = when {
        data.overMonth -> "Vượt mức tháng này"
        over -> "Quá mức an toàn hôm nay"
        else -> "Hôm nay · đã dùng ${data.percentUsed.toInt()}%"
    } + if (data.syncError) " · dữ liệu cũ" else ""
    val bigColor = when {
        over -> ColorProvider(Color(SafeSpendColors.OVER))
        caution -> ColorProvider(Color(SafeSpendColors.CAUTION))
        else -> SafeSpendColors.textPrimary
    }
    Column(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                provider = ImageProvider(if (over) R.drawable.ic_alert_triangle else R.drawable.ic_shield_check),
                contentDescription = null,
                modifier = GlanceModifier.size(12.dp),
                colorFilter = androidx.glance.ColorFilter.tint(SafeSpendColors.textSecondary),
            )
            Spacer(modifier = GlanceModifier.width(4.dp))
            Text(
                text = label,
                style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                maxLines = 1,
            )
        }
        Text(
            text = bigText,
            style = TextStyle(fontSize = 24.sp, fontWeight = FontWeight.Bold, color = bigColor),
            maxLines = 1,
        )
    }
}

@Composable
private fun NoBudgetContent() {
    Column(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = "Chưa đặt ngân sách",
            style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
            maxLines = 1,
        )
        Text(
            text = "Đặt hạn mức để biết mỗi ngày chi bao nhiêu",
            style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
            maxLines = 1,
        )
    }
}

private fun withAlpha(colorInt: Int, alpha: Int): Int =
    android.graphics.Color.argb(alpha, android.graphics.Color.red(colorInt), android.graphics.Color.green(colorInt), android.graphics.Color.blue(colorInt))

private fun formatVnd(cents: Long): String {
    val formatter = NumberFormat.getNumberInstance(Locale.forLanguageTag("vi-VN"))
    formatter.maximumFractionDigits = 0
    return "${formatter.format(cents)} đ"
}

/** Số tiền rút gọn cho ô hẹp: từ 1 triệu trở lên ghi "10,9 tr" / "2,3 tỷ", dưới đó ghi đủ ("850.000 đ"). */
private fun formatVndShort(cents: Long): String {
    val abs = kotlin.math.abs(cents)
    fun oneDecimal(value: Double): String {
        val text = String.format(Locale.US, "%.1f", value)
        return (if (text.endsWith(".0")) text.dropLast(2) else text).replace('.', ',')
    }
    return when {
        abs >= 1_000_000_000L -> "${oneDecimal(cents / 1_000_000_000.0)} tỷ"
        abs >= 1_000_000L -> "${oneDecimal(cents / 1_000_000.0)} tr"
        else -> formatVnd(cents)
    }
}

private fun formatTime(millis: Long): String =
    SimpleDateFormat("HH:mm", Locale.forLanguageTag("vi-VN")).format(java.util.Date(millis))

class SafeSpendWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = SafeSpendWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        SafeSpendRefreshWorker.schedulePeriodic(context)
        SafeSpendRefreshWorker.syncNow(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        SafeSpendRefreshWorker.cancelPeriodic(context)
    }
}

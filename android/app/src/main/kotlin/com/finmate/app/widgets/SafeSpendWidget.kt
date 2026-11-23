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
import kotlin.math.abs
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * W1 "Chi an toàn" (2×2) — nội dung thật (đợt build riêng cho W1, xem kế hoạch chia nhỏ Luồng 9):
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
        val over = data?.let { it.hasBudget && it.percentUsed >= 100f } ?: false
        val openAppAction = if (over) {
            actionRunCallback<OpenPlanningCallback>()
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
                        .padding(14.dp),
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

@Composable
private fun CardHeader(iconRes: Int, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = GlanceModifier.fillMaxWidth().clickable(actionRunCallback<OpenWidgetSettingsCallback>()),
    ) {
        Image(
            provider = ImageProvider(iconRes),
            contentDescription = null,
            modifier = GlanceModifier.size(14.dp),
            colorFilter = androidx.glance.ColorFilter.tint(SafeSpendColors.textSecondary),
        )
        Spacer(modifier = GlanceModifier.width(6.dp))
        Text(
            text = "FinMate • $label",
            style = TextStyle(fontSize = 11.sp, color = SafeSpendColors.textSecondary),
        )
    }
}

@Composable
private fun CardFooter(updatedAtMillis: Long, actionLabel: String) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Cập nhật ${formatTime(updatedAtMillis)}",
            style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
            modifier = GlanceModifier.defaultWeight(),
        )
        Text(
            text = actionLabel,
            style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textPrimary, fontWeight = FontWeight.Medium),
        )
    }
}

@Composable
private fun SpendableContent(data: SafeSpendPrefs.Data) {
    val over = data.percentUsed >= 100f
    val caution = !over && data.percentUsed >= 80f
    val ringColor = when {
        over -> SafeSpendColors.OVER
        caution -> SafeSpendColors.CAUTION
        else -> SafeSpendColors.SAFE
    }
    Column(modifier = GlanceModifier.fillMaxSize()) {
        CardHeader(
            iconRes = if (over) R.drawable.ic_alert_triangle else R.drawable.ic_shield_check,
            label = if (over) "Cần điều chỉnh" else "Chi an toàn",
        )
        Spacer(modifier = GlanceModifier.height(8.dp))
        Row(modifier = GlanceModifier.fillMaxWidth().defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = if (over) "Vượt ${formatVnd(abs(data.perDayCents))}" else formatVnd(data.perDayCents),
                    style = TextStyle(
                        fontSize = if (over) 14.sp else 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (over) ColorProvider(Color(SafeSpendColors.OVER)) else SafeSpendColors.textPrimary,
                    ),
                    maxLines = 1,
                )
                Text(
                    text = if (over) "Nên tạm hoãn các khoản phát sinh" else "Hôm nay có thể chi tiêu an toàn",
                    style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                    maxLines = 2,
                )
            }
            Spacer(modifier = GlanceModifier.width(6.dp))
            Image(
                provider = ImageProvider(
                    ProgressRing.draw(
                        sizePx = 160,
                        strokeWidthPx = 14f,
                        percent = data.percentUsed,
                        trackColor = withAlpha(ringColor, 40),
                        progressColor = ringColor,
                        percentText = "${data.percentUsed.toInt()}%",
                        subLabel = "tháng",
                        subLabelColor = SafeSpendColors.secondaryInt(androidx.glance.LocalContext.current),
                    ),
                ),
                contentDescription = "${data.percentUsed.toInt()}% ngân sách tháng đã dùng",
                modifier = GlanceModifier.size(56.dp),
            )
        }
        Spacer(modifier = GlanceModifier.height(6.dp))
        CardFooter(
            updatedAtMillis = data.lastSyncAtMillis,
            actionLabel = if (over) "Bù đắp ngân sách →" else "Mở FinMate →",
        )
        if (data.syncError) {
            Text(
                text = "Dữ liệu cũ — mất kết nối lần đồng bộ gần nhất",
                style = TextStyle(fontSize = 9.sp, color = ColorProvider(Color(SafeSpendColors.CAUTION))),
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun NoBudgetContent() {
    Column(modifier = GlanceModifier.fillMaxSize()) {
        CardHeader(iconRes = R.drawable.ic_sparkles, label = "Gợi ý thông minh")
        Spacer(modifier = GlanceModifier.height(8.dp))
        Column(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
            Text(
                text = "Chưa đặt ngân sách",
                style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
            )
            Text(
                text = "Đặt ngân sách tháng để kích hoạt hạn mức an toàn mỗi ngày.",
                style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                maxLines = 3,
            )
        }
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "Chỉ mất 30 giây thiết lập",
                style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                modifier = GlanceModifier.defaultWeight(),
            )
            Text(
                text = "Đặt ngay +",
                style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textPrimary, fontWeight = FontWeight.Bold),
            )
        }
    }
}

private fun withAlpha(colorInt: Int, alpha: Int): Int =
    android.graphics.Color.argb(alpha, android.graphics.Color.red(colorInt), android.graphics.Color.green(colorInt), android.graphics.Color.blue(colorInt))

private fun formatVnd(cents: Long): String {
    val formatter = NumberFormat.getNumberInstance(Locale.forLanguageTag("vi-VN"))
    formatter.maximumFractionDigits = 0
    return "${formatter.format(cents)} đ"
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

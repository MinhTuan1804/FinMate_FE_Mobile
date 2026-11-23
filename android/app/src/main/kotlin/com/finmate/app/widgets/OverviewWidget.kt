package com.finmate.app.widgets

import android.content.Context
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
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
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
import com.finmate.app.R
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * W2 "Tổng quan" (4×2) — nội dung thật (đợt build riêng cho W2, xem kế hoạch chia nhỏ Luồng 9):
 * số dư khả dụng (tổng hoặc theo "Nguồn tiền" đã chọn trong màn cấu hình) + % ngân sách tháng đã
 * dùng + 2 nút hành động "Ghi chép"/"Quét QR". KHÔNG có chế độ ẩn số dư (đã chốt bỏ hẳn tính năng
 * này cho cả 3 widget, 2026-11-17) — số dư luôn hiện rõ khi đã đồng bộ.
 */
class OverviewWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = OverviewPrefs.read(context)
        val aiSuggestionsEnabled = readAiSuggestionsEnabled(context, id)

        provideContent {
            GlanceTheme {
                Box(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .cornerRadius(20.dp)
                        .background(SafeSpendColors.cardBg)
                        .clickable(actionRunCallback<OpenOverviewAppCallback>())
                        .padding(14.dp),
                ) {
                    if (data == null) SyncingContent() else OverviewContent(data, aiSuggestionsEnabled)
                }
            }
        }
    }

    private fun readAiSuggestionsEnabled(context: Context, id: GlanceId): Boolean {
        return try {
            val widgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
            context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
                .getBoolean("aiSuggestionsEnabled_$widgetId", true)
        } catch (e: Exception) {
            true
        }
    }
}

class OpenOverviewAppCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        openAppAtRoute(context, "/home")
    }
}

class OpenOverviewSettingsCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        openAppAtRoute(context, "/widget-settings?kind=w2")
    }
}

/** "Ghi chép": mở thẳng CreateTransactionBottomSheet (cùng sheet dùng ở Trang chủ/D1), không phải
 * 1 route điều hướng thật — notification_capture_scope.dart xử lý riêng route ảo "/quick-create". */
class OpenQuickCreateCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        openAppAtRoute(context, "/quick-create")
    }
}

class OpenQrScanCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        openAppAtRoute(context, "/qr-transfers/scan")
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
private fun OverviewContent(data: OverviewPrefs.Data, aiSuggestionsEnabled: Boolean) {
    val over = data.hasBudget && data.percentUsed >= 100f
    val caution = data.hasBudget && !over && data.percentUsed >= 80f
    Column(modifier = GlanceModifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = GlanceModifier.fillMaxWidth().clickable(actionRunCallback<OpenOverviewSettingsCallback>()),
        ) {
            Image(
                provider = ImageProvider(R.drawable.ic_sparkles),
                contentDescription = null,
                modifier = GlanceModifier.size(14.dp),
                colorFilter = androidx.glance.ColorFilter.tint(SafeSpendColors.textSecondary),
            )
            Spacer(modifier = GlanceModifier.width(6.dp))
            Text(
                text = "FinMate • ${data.accountLabel}",
                style = TextStyle(fontSize = 11.sp, color = SafeSpendColors.textSecondary),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.height(6.dp))
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = "SỐ DƯ KHẢ DỤNG",
                    style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                )
                Text(
                    text = formatVnd(data.balanceCents),
                    style = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
                    maxLines = 1,
                )
                if (data.hasBudget) {
                    Text(
                        text = "Đã chi tháng này: ${formatVnd(data.spentCents)}",
                        style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                        maxLines = 1,
                    )
                    Text(
                        text = "Chi an toàn: ${formatVnd(data.perDayCents)}/ngày",
                        style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                        maxLines = 1,
                    )
                }
            }
            if (aiSuggestionsEnabled && data.hasBudget) {
                val ringColor = when {
                    over -> SafeSpendColors.OVER
                    caution -> SafeSpendColors.CAUTION
                    else -> SafeSpendColors.SAFE
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
                            subLabel = "ngân sách",
                            subLabelColor = SafeSpendColors.secondaryInt(androidx.glance.LocalContext.current),
                        ),
                    ),
                    contentDescription = "${data.percentUsed.toInt()}% ngân sách tháng đã dùng",
                    modifier = GlanceModifier.size(56.dp),
                )
            }
        }
        Spacer(modifier = GlanceModifier.height(4.dp))
        if (aiSuggestionsEnabled && !data.hasBudget) {
            Text(
                text = "Chưa đặt ngân sách tháng",
                style = TextStyle(fontSize = 11.sp, color = SafeSpendColors.textSecondary),
                maxLines = 1,
            )
        }
        if (data.syncError) {
            Text(
                text = "Dữ liệu cũ — mất kết nối lần đồng bộ gần nhất",
                style = TextStyle(fontSize = 9.sp, color = ColorProvider(Color(SafeSpendColors.CAUTION))),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.defaultWeight())
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            ActionButton(label = "Ghi chép", filled = false, modifier = GlanceModifier.defaultWeight())
            Spacer(modifier = GlanceModifier.width(8.dp))
            ActionButtonQr(modifier = GlanceModifier.defaultWeight())
        }
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = "Cập nhật ${formatTime(data.lastSyncAtMillis)}",
            style = TextStyle(fontSize = 9.sp, color = SafeSpendColors.textSecondary),
        )
    }
}

@Composable
private fun ActionButton(label: String, filled: Boolean, modifier: GlanceModifier) {
    Box(
        modifier = modifier
            .cornerRadius(10.dp)
            .background(if (filled) SafeSpendColors.textPrimary else SafeSpendColors.chipBg)
            .clickable(actionRunCallback<OpenQuickCreateCallback>())
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = TextStyle(
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = if (filled) SafeSpendColors.onPrimary else SafeSpendColors.textPrimary,
            ),
        )
    }
}

@Composable
private fun ActionButtonQr(modifier: GlanceModifier) {
    Box(
        modifier = modifier
            .cornerRadius(10.dp)
            .background(SafeSpendColors.textPrimary)
            .clickable(actionRunCallback<OpenQrScanCallback>())
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Quét QR",
            style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, color = SafeSpendColors.onPrimary),
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

private fun formatTime(millis: Long): String =
    SimpleDateFormat("HH:mm", Locale.forLanguageTag("vi-VN")).format(java.util.Date(millis))

class OverviewWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = OverviewWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        OverviewRefreshWorker.schedulePeriodic(context)
        OverviewRefreshWorker.syncNow(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        OverviewRefreshWorker.cancelPeriodic(context)
    }
}

package com.example.finmate.widgets

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
import com.example.finmate.R
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Widget "Chi tiết" (4×4) — nội dung thật (2026-11-17): số dư khả dụng (tổng hoặc theo "Nguồn tiền"
 * đã chọn trong màn cấu hình, cùng cách OverviewWidget đọc) + dự báo cuối tháng (CHỈ 1 con số —
 * `GET /forecast/cashflow` → `endBalanceCents`) + vòng tròn % ngân sách tháng (chỉ hiện khi đã đặt
 * ngân sách — cùng `ProgressRing`/công thức `percentUsed` với W1, `GET /me/spendable`) + dòng "Đã
 * chi: X / Ngân sách: Y" + dòng tổng "Đã ghi N giao dịch hôm nay" + tối đa 4 dòng "GIAO DỊCH VỪA GHI
 * NHẬN" (tên/hạng mục/giờ + số tiền tô xanh/đỏ — quyết định 2026-11-17: đảo ngược lần nữa quyết định
 * thu gọn trước đó, người dùng đã xác nhận chấp nhận đánh đổi lộ thói quen chi tiêu trên widget
 * không khoá) + 2 nút hành động "Ghi chép"/"Quét QR" (tái dùng callback đã có ở W2, OverviewWidget.kt).
 */
class DetailWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = DetailPrefs.read(context)

        provideContent {
            GlanceTheme {
                Box(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .cornerRadius(20.dp)
                        .background(SafeSpendColors.cardBg)
                        .clickable(actionRunCallback<OpenOverviewAppCallback>())
                        .padding(16.dp),
                ) {
                    if (data == null) SyncingContent() else DetailContent(data)
                }
            }
        }
    }
}

class OpenDetailSettingsCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        openAppAtRoute(context, "/widget-settings?kind=w4x4")
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

/** Glance giới hạn CỨNG 1 Column tối đa 10 phần tử con trực tiếp — vượt quá, Android âm thầm cắt bỏ
 * phần tử thứ 11 trở đi (không báo lỗi lên UI, chỉ log `IllegalArgumentException` nội bộ). Bản trước
 * có 14 phần tử phẳng trong đúng 1 Column (xác nhận thật bằng `adb logcat`: "Truncated Column
 * container from 14 to 10 elements"), nên 2 nút + danh sách giao dịch (nằm ở vị trí 11+) biến mất.
 * Fix: gom theo nhóm vào các Column con riêng — Column cha giờ chỉ còn 5 phần tử con. */
@Composable
private fun DetailContent(data: DetailPrefs.Data) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
        BalanceSection(data)
        ActionsSection(data)
        if (data.recentTransactions.isNotEmpty()) RecentTransactionsSection(data.recentTransactions)
        Spacer(modifier = GlanceModifier.defaultWeight())
        Text(
            text = "Cập nhật ${formatTime(data.lastSyncAtMillis)}",
            style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
        )
    }
}

/** Nhóm 1 (tối đa 4 phần tử con): header + hàng số dư/dự báo/vòng tròn + dòng ngân sách. */
@Composable
private fun BalanceSection(data: DetailPrefs.Data) {
    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = GlanceModifier.fillMaxWidth().clickable(actionRunCallback<OpenDetailSettingsCallback>()),
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
                style = TextStyle(fontSize = 12.sp, color = SafeSpendColors.textSecondary),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.height(10.dp))
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            // fontSize giảm so với bản trước (26sp/22sp -> 19sp/15sp): khi có ring (56dp cố định) ở
            // cuối Row, 2 Column defaultWeight() chỉ còn chia nhau phần còn lại sau khi trừ ring +
            // spacer — ở khung 4x4 thật trên máy, 26sp "36.010.000 đ" (12 ký tự) bị tràn/"..." (xem
            // ảnh user gửi). Glance Text không có autosize nên phải tự giảm cỡ chữ tay.
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = "SỐ DƯ KHẢ DỤNG",
                    style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                    maxLines = 1,
                )
                Text(
                    text = formatVnd(data.balanceCents),
                    style = TextStyle(fontSize = 19.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
                    maxLines = 1,
                )
            }
            Spacer(modifier = GlanceModifier.width(8.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = "DỰ BÁO CUỐI THÁNG",
                    style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                    maxLines = 1,
                )
                Text(
                    text = formatVnd(data.forecastEndBalanceCents),
                    style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
                    maxLines = 1,
                )
            }
            if (data.hasBudget) {
                val over = data.percentUsed >= 100f
                val caution = !over && data.percentUsed >= 80f
                val ringColor = when {
                    over -> SafeSpendColors.OVER
                    caution -> SafeSpendColors.CAUTION
                    else -> SafeSpendColors.SAFE
                }
                Spacer(modifier = GlanceModifier.width(8.dp))
                Image(
                    provider = ImageProvider(
                        ProgressRing.draw(
                            sizePx = 160,
                            strokeWidthPx = 14f,
                            percent = data.percentUsed,
                            trackColor = withAlpha(ringColor, 40),
                            progressColor = ringColor,
                            percentText = "${data.percentUsed.toInt()}%",
                            subLabel = "hạn mức",
                            subLabelColor = SafeSpendColors.secondaryInt(androidx.glance.LocalContext.current),
                        ),
                    ),
                    contentDescription = "${data.percentUsed.toInt()}% ngân sách tháng đã dùng",
                    modifier = GlanceModifier.size(56.dp),
                )
            }
        }
        if (data.hasBudget) {
            Text(
                text = "Đã chi: ${formatVnd(data.spentCents)} / Ngân sách: ${formatVnd(data.incomeCents)}",
                style = TextStyle(fontSize = 12.sp, color = SafeSpendColors.textSecondary),
                maxLines = 1,
            )
        }
    }
}

/** Nhóm 2 (tối đa 5 phần tử con): 2 nút hành động + dòng đếm giao dịch + dòng lỗi đồng bộ (nếu có).
 * Đặt NGAY SAU [BalanceSection] — nội dung quan trọng nhất (số dư, 2 nút) phải luôn nằm trong vùng
 * hiển thị; danh sách giao dịch ở [RecentTransactionsSection] bên dưới ưu tiên thấp hơn. */
@Composable
private fun ActionsSection(data: DetailPrefs.Data) {
    Column {
        Spacer(modifier = GlanceModifier.height(8.dp))
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            ActionButton(label = "Ghi chép", modifier = GlanceModifier.defaultWeight())
            Spacer(modifier = GlanceModifier.width(8.dp))
            ActionButtonQr(modifier = GlanceModifier.defaultWeight())
        }
        Spacer(modifier = GlanceModifier.height(8.dp))
        Text(
            text = "Đã ghi ${data.transactionsTodayCount} giao dịch hôm nay",
            style = TextStyle(fontSize = 12.sp, color = SafeSpendColors.textSecondary),
            maxLines = 1,
        )
        if (data.syncError) {
            Text(
                text = "Dữ liệu cũ — mất kết nối lần đồng bộ gần nhất",
                style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color(SafeSpendColors.CAUTION))),
                maxLines = 1,
            )
        }
    }
}

/** Nhóm 3 (tối đa 4 phần tử con: spacer + tiêu đề + 2 dòng giao dịch): chỉ gọi khi danh sách không
 * rỗng, Column riêng để không cộng dồn vào giới hạn 10 của Column cha. */
@Composable
private fun RecentTransactionsSection(recentTransactions: List<DetailPrefs.RecentTxn>) {
    Column {
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = "GIAO DỊCH VỪA GHI NHẬN",
            style = TextStyle(fontSize = 9.sp, color = SafeSpendColors.textSecondary),
        )
        recentTransactions.forEach { txn -> RecentTxnRow(txn) }
    }
}

/** 1 dòng "GIAO DỊCH VỪA GHI NHẬN" — chấm tròn chữ cái đầu (không có icon theo hạng mục, giữ đơn
 * giản đúng yêu cầu "don't invent new drawables") + mô tả/hạng mục • giờ + số tiền tô xanh (thu)/đỏ
 * (chi), có dấu +/-. */
@Composable
private fun RecentTxnRow(txn: DetailPrefs.RecentTxn) {
    val amountColor = if (txn.isIncome) SafeSpendColors.SAFE else SafeSpendColors.OVER
    Row(
        modifier = GlanceModifier.fillMaxWidth().padding(vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = GlanceModifier.size(20.dp).cornerRadius(10.dp).background(Color(withAlpha(amountColor, 30))),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = txn.description.trim().take(1).uppercase().ifEmpty { "?" },
                style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color(amountColor))),
            )
        }
        Spacer(modifier = GlanceModifier.width(8.dp))
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(
                text = txn.description,
                style = TextStyle(fontSize = 11.sp, color = SafeSpendColors.textPrimary),
                maxLines = 1,
            )
            Text(
                text = "${txn.categoryLabel} • ${formatTime(txn.timeMillis)}",
                style = TextStyle(fontSize = 9.sp, color = SafeSpendColors.textSecondary),
                maxLines = 1,
            )
        }
        Text(
            text = "${if (txn.isIncome) "+" else "-"}${formatVnd(txn.amountCents)}",
            style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium, color = ColorProvider(Color(amountColor))),
            maxLines = 1,
        )
    }
}

@Composable
private fun ActionButton(label: String, modifier: GlanceModifier) {
    Box(
        modifier = modifier
            .cornerRadius(10.dp)
            .background(SafeSpendColors.chipBg)
            .clickable(actionRunCallback<OpenQuickCreateCallback>())
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium, color = SafeSpendColors.textPrimary),
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
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Quét QR",
            style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium, color = SafeSpendColors.onPrimary),
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

class DetailWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DetailWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        DetailRefreshWorker.schedulePeriodic(context)
        DetailRefreshWorker.syncNow(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        DetailRefreshWorker.cancelPeriodic(context)
    }
}

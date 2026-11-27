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
import androidx.glance.LocalContext
import androidx.glance.ImageProvider
import androidx.glance.action.Action
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
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.finmate.app.R
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Widget "Tổng quan" (4×4) — một trang, theo ảnh mẫu thiết kế:
 *  - Tiêu đề: logo + "FinMate" + nguồn tiền, chip giờ cập nhật (đổi thành "Dữ liệu cũ" khi mất kết nối).
 *  - Thẻ số dư các ví, chip "còn chi được hôm nay" (hoặc "Vượt X tháng này") và vòng tròn % mức chi an toàn hôm nay.
 *  - Dòng đã chi tháng này / thu nhập dự kiến.
 *  - Thẻ dự báo cuối tháng: số tiền, độ tin cậy và đường biểu đồ số dư dự kiến.
 *  - Giao dịch gần nhất (thẻ nhỏ, không chỉ của hôm nay) và các khoản định kỳ sắp đến hạn.
 *  - Thanh dưới: "Hỏi FinMate", mic, camera đọc hóa đơn, quét QR (không có nút "Ghi chép" theo yêu cầu).
 *
 * Glance giới hạn CỨNG 1 Column tối đa 10 phần tử con trực tiếp: Column cha ở đây có tối đa 8.
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
                        .padding(horizontal = 14.dp, vertical = 12.dp),
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

@Composable
private fun DetailContent(data: DetailPrefs.Data) {
    // Có khoản sắp đến hạn thì bớt còn 2 giao dịch để vừa khung 4×4.
    val upcoming = data.upcomingItems.take(2)
    val recentCount = if (upcoming.isEmpty()) 3 else 2
    Column(modifier = GlanceModifier.fillMaxSize()) {
        HeaderBar(data)
        BalanceCard(data)
        SpentLine(data)
        ForecastCard(data)
        TransactionsSection(data.recentTransactions.take(recentCount))
        if (upcoming.isNotEmpty()) UpcomingSection(upcoming)
        Spacer(modifier = GlanceModifier.defaultWeight())
        BottomBar()
    }
}

/** Logo + tên + nguồn tiền (chạm mở cấu hình widget) và chip giờ cập nhật. */
@Composable
private fun HeaderBar(data: DetailPrefs.Data) {
    Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Row(
            modifier = GlanceModifier.defaultWeight().clickable(actionRunCallback<OpenDetailSettingsCallback>()),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = GlanceModifier.size(28.dp).cornerRadius(14.dp).background(SafeSpendColors.textPrimary),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_wallet),
                    contentDescription = null,
                    modifier = GlanceModifier.size(15.dp),
                    colorFilter = androidx.glance.ColorFilter.tint(SafeSpendColors.onPrimary),
                )
            }
            Spacer(modifier = GlanceModifier.width(8.dp))
            Column {
                Text(
                    text = "FinMate",
                    style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
                    maxLines = 1,
                )
                Text(
                    text = data.accountLabel,
                    style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
                    maxLines = 1,
                )
            }
        }
        Box(
            modifier = GlanceModifier.cornerRadius(12.dp).background(SafeSpendColors.softBg).padding(horizontal = 8.dp, vertical = 4.dp),
        ) {
            Text(
                text = if (data.syncError) "Dữ liệu cũ" else formatTime(data.lastSyncAtMillis),
                style = TextStyle(
                    fontSize = 10.sp,
                    color = if (data.syncError) ColorProvider(Color(SafeSpendColors.CAUTION)) else SafeSpendColors.textSecondary,
                ),
                maxLines = 1,
            )
        }
    }
}

/** Thẻ số dư: nhãn, số lớn, chip trạng thái hôm nay; bên phải là vòng tròn % mức chi an toàn hôm nay. */
@Composable
private fun BalanceCard(data: DetailPrefs.Data) {
    val remaining = (data.safeTodayCents - data.spentTodayCents).coerceAtLeast(0L)
    val chipText: String? = when {
        !data.hasBudget -> null
        data.overMonth -> if (data.monthOverCents > 0) "Vượt ${formatVnd(data.monthOverCents)} tháng này" else "Hết mức hôm nay"
        data.over -> "Hôm nay đã quá mức an toàn"
        else -> "Còn chi được ${formatVnd(remaining)} hôm nay"
    }
    val chipBg = if (data.over) SafeSpendColors.chipRedBg else SafeSpendColors.chipGreenBg
    val chipFg = ColorProvider(Color(if (data.over) 0xFFB91C1C.toInt() else 0xFF15803D.toInt()))
    val ringColor = when {
        data.over -> SafeSpendColors.OVER
        data.percentUsed >= 80f -> SafeSpendColors.CAUTION
        else -> SafeSpendColors.SAFE
    }
    val secondary = SafeSpendColors.secondaryInt(LocalContext.current)
    Box(modifier = GlanceModifier.fillMaxWidth().padding(top = 8.dp)) {
        Box(modifier = GlanceModifier.fillMaxWidth().cornerRadius(14.dp).background(SafeSpendColors.softBg).padding(10.dp)) {
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Text(
                        text = "TỔNG SỐ DƯ CÁC VÍ",
                        style = TextStyle(fontSize = 9.sp, color = SafeSpendColors.textSecondary),
                        maxLines = 1,
                    )
                    Text(
                        text = formatVnd(data.balanceCents),
                        style = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
                        maxLines = 1,
                    )
                    if (chipText != null) {
                        Box(modifier = GlanceModifier.padding(top = 3.dp)) {
                            Box(modifier = GlanceModifier.cornerRadius(8.dp).background(chipBg).padding(horizontal = 6.dp, vertical = 2.dp)) {
                                Text(
                                    text = chipText,
                                    style = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Medium, color = chipFg),
                                    maxLines = 1,
                                )
                            }
                        }
                    }
                }
                if (data.hasBudget) {
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Image(
                        provider = ImageProvider(
                            ProgressRing.draw(
                                sizePx = 180,
                                strokeWidthPx = 16f,
                                percent = data.percentUsed,
                                trackColor = withAlpha(ringColor, 40),
                                progressColor = ringColor,
                                percentText = "${data.percentUsed.toInt()}%",
                                subLabel = "hôm nay",
                                subLabelColor = secondary,
                            ),
                        ),
                        contentDescription = "${data.percentUsed.toInt()}% mức chi an toàn hôm nay đã dùng",
                        modifier = GlanceModifier.size(54.dp),
                    )
                }
            }
        }
    }
}

/** "Đã chi tháng này" và "Thu nhập dự kiến". */
@Composable
private fun SpentLine(data: DetailPrefs.Data) {
    Row(modifier = GlanceModifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = "Đã chi tháng này: ${formatVnd(data.spentCents)}",
            style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary),
            maxLines = 1,
            modifier = GlanceModifier.defaultWeight(),
        )
        if (data.incomeCents > 0) {
            Text(
                text = "Thu nhập: ${formatVnd(data.incomeCents)}",
                style = TextStyle(fontSize = 10.sp, color = SafeSpendColors.textSecondary, textAlign = TextAlign.End),
                maxLines = 1,
            )
        }
    }
}

/** Thẻ dự báo cuối tháng: số tiền, nhãn độ tin cậy và đường biểu đồ nhỏ. */
@Composable
private fun ForecastCard(data: DetailPrefs.Data) {
    val confidence: Triple<String, androidx.glance.unit.ColorProvider, Int> = when (data.forecastConfidence.lowercase()) {
        "high" -> Triple("Tin cậy: Cao", SafeSpendColors.chipGreenBg, 0xFF15803D.toInt())
        "medium", "normal" -> Triple("Tin cậy: Vừa", SafeSpendColors.chipAmberBg, 0xFFB45309.toInt())
        "low" -> Triple("Tin cậy: Thấp", SafeSpendColors.chipRedBg, 0xFFB91C1C.toInt())
        else -> Triple("", SafeSpendColors.chipGreenBg, 0xFF15803D.toInt())
    }
    Box(modifier = GlanceModifier.fillMaxWidth().padding(top = 6.dp)) {
        Box(modifier = GlanceModifier.fillMaxWidth().cornerRadius(14.dp).background(SafeSpendColors.softBg).padding(horizontal = 10.dp, vertical = 8.dp)) {
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "DỰ BÁO CUỐI THÁNG",
                            style = TextStyle(fontSize = 9.sp, color = SafeSpendColors.textSecondary),
                            maxLines = 1,
                        )
                        if (confidence.first.isNotEmpty()) {
                            Spacer(modifier = GlanceModifier.width(6.dp))
                            Box(modifier = GlanceModifier.cornerRadius(8.dp).background(confidence.second).padding(horizontal = 5.dp, vertical = 1.dp)) {
                                Text(
                                    text = confidence.first,
                                    style = TextStyle(fontSize = 8.sp, fontWeight = FontWeight.Medium, color = ColorProvider(Color(confidence.third))),
                                    maxLines = 1,
                                )
                            }
                        }
                    }
                    Text(
                        text = formatVnd(data.forecastEndBalanceCents),
                        style = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Bold, color = SafeSpendColors.textPrimary),
                        maxLines = 1,
                    )
                }
                Spacer(modifier = GlanceModifier.width(6.dp))
                Image(
                    provider = ImageProvider(Sparkline.draw(data.forecastSeries, widthPx = 252, heightPx = 90, lineColor = 0xFF4F6FA8.toInt())),
                    contentDescription = "Biểu đồ số dư dự kiến đến cuối tháng",
                    modifier = GlanceModifier.size(84.dp, 30.dp),
                )
            }
        }
    }
}

/** "GIAO DỊCH VỪA GHI NHẬN" kèm "Chi tiết" và vài giao dịch gần nhất (mới nhất trước, bất kể ngày). */
@Composable
private fun TransactionsSection(transactions: List<DetailPrefs.RecentTxn>) {
    Column {
        Row(modifier = GlanceModifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "GIAO DỊCH VỪA GHI NHẬN",
                style = TextStyle(fontSize = 9.sp, color = SafeSpendColors.textSecondary),
                maxLines = 1,
                modifier = GlanceModifier.defaultWeight(),
            )
            Text(
                text = "Chi tiết",
                style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Medium, color = SafeSpendColors.textPrimary),
                modifier = GlanceModifier.clickable(actionRunCallback<OpenTransactionsCallback>()),
            )
        }
        transactions.forEach { txn -> TxnCard(txn) }
    }
}

/** Một giao dịch dạng thẻ nhỏ: chấm chữ cái đầu, tên, "hạng mục • thời điểm" và số tiền xanh (thu) / đỏ (chi). */
@Composable
private fun TxnCard(txn: DetailPrefs.RecentTxn) {
    val amountColor = if (txn.isIncome) SafeSpendColors.SAFE else SafeSpendColors.OVER
    Box(modifier = GlanceModifier.fillMaxWidth().padding(top = 3.dp)) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().cornerRadius(10.dp).background(SafeSpendColors.softBg).padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = GlanceModifier.size(24.dp).cornerRadius(12.dp).background(Color(withAlpha(amountColor, 30))),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = txn.description.trim().take(1).uppercase().ifEmpty { "?" },
                    style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color(amountColor))),
                )
            }
            Spacer(modifier = GlanceModifier.width(8.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = txn.description,
                    style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium, color = SafeSpendColors.textPrimary),
                    maxLines = 1,
                )
                Text(
                    text = "${txn.categoryLabel} • ${formatWhen(txn.timeMillis)}",
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
}

/** Các khoản chi định kỳ sắp đến hạn (tối đa 2, gần nhất trước). Khoản trong vòng 3 ngày tô cam. */
@Composable
private fun UpcomingSection(items: List<DetailPrefs.Upcoming>) {
    Column {
        Text(
            text = "SẮP ĐẾN HẠN",
            style = TextStyle(fontSize = 9.sp, color = SafeSpendColors.textSecondary),
            modifier = GlanceModifier.padding(top = 6.dp),
        )
        items.forEach { item ->
            val days = daysUntil(item.dueDate)
            val color = if (days in 0..3) ColorProvider(Color(SafeSpendColors.CAUTION)) else SafeSpendColors.textPrimary
            Row(modifier = GlanceModifier.fillMaxWidth().padding(vertical = 1.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "${item.name} • ${dueLabel(item.dueDate, days)}",
                    style = TextStyle(fontSize = 10.sp, color = color),
                    maxLines = 1,
                    modifier = GlanceModifier.defaultWeight(),
                )
                Text(
                    text = formatVnd(item.amountCents),
                    style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Medium, color = color),
                    maxLines = 1,
                )
            }
        }
    }
}

/** Thanh dưới cùng: "Hỏi FinMate" (nút lớn), mic, camera đọc hóa đơn, quét QR. */
@Composable
private fun BottomBar() {
    Row(modifier = GlanceModifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = GlanceModifier
                .defaultWeight()
                .cornerRadius(18.dp)
                .background(SafeSpendColors.textPrimary)
                .clickable(actionRunCallback<OpenChatCallback>())
                .padding(vertical = 9.dp),
            contentAlignment = Alignment.Center,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(
                    provider = ImageProvider(R.drawable.ic_sparkles),
                    contentDescription = null,
                    modifier = GlanceModifier.size(14.dp),
                    colorFilter = androidx.glance.ColorFilter.tint(SafeSpendColors.onPrimary),
                )
                Spacer(modifier = GlanceModifier.width(6.dp))
                Text(
                    text = "Hỏi FinMate",
                    style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, color = SafeSpendColors.onPrimary),
                    maxLines = 1,
                )
            }
        }
        Spacer(modifier = GlanceModifier.width(6.dp))
        RoundIconButton(R.drawable.ic_mic, "Nói để ghi chép", actionRunCallback<OpenVoiceCallback>())
        Spacer(modifier = GlanceModifier.width(6.dp))
        RoundIconButton(R.drawable.ic_camera, "Đọc hóa đơn", actionRunCallback<OpenReceiptScanCallback>())
        Spacer(modifier = GlanceModifier.width(6.dp))
        RoundIconButton(R.drawable.ic_qr_code, "Quét QR", actionRunCallback<OpenQrScanCallback>())
    }
}

@Composable
private fun RoundIconButton(iconRes: Int, description: String, action: Action) {
    Box(
        modifier = GlanceModifier.size(34.dp).cornerRadius(17.dp).background(SafeSpendColors.chipBg).clickable(action),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            provider = ImageProvider(iconRes),
            contentDescription = description,
            modifier = GlanceModifier.size(16.dp),
            colorFilter = androidx.glance.ColorFilter.tint(SafeSpendColors.textPrimary),
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

/** Giờ ("12:40") cho giao dịch hôm nay, "Hôm qua", còn lại ngày "26/11". */
private fun formatWhen(millis: Long): String {
    val day = SimpleDateFormat("yyyyMMdd", Locale.US)
    val date = java.util.Date(millis)
    val now = java.util.Date()
    return when {
        day.format(date) == day.format(now) -> formatTime(millis)
        day.format(date) == day.format(java.util.Date(now.time - 86_400_000L)) -> "Hôm qua"
        else -> SimpleDateFormat("dd/MM", Locale.forLanguageTag("vi-VN")).format(date)
    }
}

/** "2026-12-17" -> "17/12". */
private fun formatDueDate(iso: String): String =
    if (iso.length >= 10) "${iso.substring(8, 10)}/${iso.substring(5, 7)}" else iso

/** Số ngày từ hôm nay (giờ máy) đến ngày hạn "yyyy-MM-dd"; không đọc được thì -1. */
private fun daysUntil(iso: String): Int = try {
    val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    val today = fmt.parse(fmt.format(java.util.Date()))!!.time
    val due = fmt.parse(iso.take(10))!!.time
    ((due - today) / 86_400_000L).toInt()
} catch (e: Exception) {
    -1
}

/** Gần hạn thì nói bằng chữ ("Hôm nay", "Ngày mai", "Còn 3 ngày"), xa hơn thì ghi ngày "17/12". */
private fun dueLabel(iso: String, days: Int): String = when {
    days == 0 -> "Hôm nay"
    days == 1 -> "Ngày mai"
    days in 2..7 -> "Còn $days ngày"
    else -> formatDueDate(iso)
}

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

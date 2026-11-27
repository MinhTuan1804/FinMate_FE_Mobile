package com.finmate.app.widgets

import org.json.JSONObject

/**
 * Số "Chi an toàn hôm nay" của cả 3 widget (W1 2×2, W2 4×2, 4×4) — MỘT công thức, giống hệt thẻ "Chi an toàn hôm nay" ở
 * Trang chủ (`_buildSafeToSpendCard`, home_screen.dart): mức an toàn hôm nay do SERVER tính (`safeTodayCents`: phần còn lại của tháng
 * tính đến đầu ngày ÷ số ngày còn lại), vòng tròn = đã chi HÔM NAY ÷ mức đó, sang ngày mới về 0. Tháng đã chi vượt mức
 * (`safeTodayCents <= 0`) thì mức hôm nay là 0 và vòng tròn đầy 100%.
 *
 * Trước đây widget tự tính `chi cả tháng ÷ thu nhập dự kiến` (ra 209%) và `spendableCents ÷ số ngày còn lại` (ra "Vượt 2.734.500 đ"),
 * lệch với Trang chủ sau khi Trang chủ chuyển sang tính theo ngày; widget phải đọc cùng nguồn.
 */
internal data class DailySafeSpend(
    val hasBudget: Boolean,
    /** Mức chi an toàn hôm nay, không âm (0 khi tháng đã vượt). */
    val safeTodayCents: Long,
    val spentTodayCents: Long,
    /** Tháng này đã chi vượt mức (không còn gì để chi an toàn). */
    val overMonth: Boolean,
    /** Đã chi hôm nay ÷ mức an toàn hôm nay (0–100+), 100 khi [overMonth]. */
    val percentUsed: Float,
    /** Số tiền tháng này đang vượt (spendable âm), 0 khi chưa vượt. Để widget nói "Vượt X đ" thay vì chỉ "0 đ". */
    val monthOverCents: Long = 0L,
) {
    /** Đáng báo đỏ: tháng đã vượt, hoặc riêng hôm nay đã chi quá mức an toàn. */
    val over: Boolean get() = hasBudget && (overMonth || percentUsed >= 100f)

    companion object {
        fun from(spendable: JSONObject): DailySafeSpend {
            val spendableCents = spendable.longOrNull("spendableCents")
            val safeToday = spendable.longOrNull("safeTodayCents")
            val spentToday = spendable.optLong("spentTodayCents", 0L)
            // Cùng điều kiện ẩn thẻ ở Trang chủ: chưa biết thu nhập (spendable null) hoặc server chưa gửi mức hôm nay.
            if (spendableCents == null || safeToday == null) return DailySafeSpend(false, 0L, spentToday, false, 0f)
            val overMonth = safeToday <= 0L
            val percent = if (overMonth) 100f else spentToday.toFloat() / safeToday.toFloat() * 100f
            return DailySafeSpend(true, if (overMonth) 0L else safeToday, spentToday, overMonth, percent, if (spendableCents < 0L) -spendableCents else 0L)
        }

        private fun JSONObject.longOrNull(key: String): Long? =
            if (isNull(key) || !has(key)) null else optLong(key)
    }
}

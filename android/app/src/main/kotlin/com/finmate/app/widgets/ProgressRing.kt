package com.finmate.app.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF

/** Glance (RemoteViews) không có API vẽ cung tròn (Canvas) trực tiếp trong Composable — vẽ sẵn 1
 * bitmap vòng tròn % rồi hiển thị bằng `Image`, đúng cách làm chuẩn cho progress-ring trên Glance. */
object ProgressRing {
    /** [percent] 0..100+ (giá trị >100 bị kẹp về 100 — vòng tròn đầy, chỉ đổi màu để báo vượt).
     * [percentText]/[subLabel] vẽ thẳng lên cùng bitmap (Glance/RemoteViews không ghép được Text đè
     * lên Image), theo đúng `design_reference/W_widgets/w1_states.png` — chữ % giữa vòng tròn. */
    fun draw(
        sizePx: Int,
        strokeWidthPx: Float,
        percent: Float,
        trackColor: Int,
        progressColor: Int,
        percentText: String? = null,
        subLabel: String? = null,
        subLabelColor: Int = SafeSpendColors.TEXT_SECONDARY,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val inset = strokeWidthPx / 2f
        val rect = RectF(inset, inset, sizePx - inset, sizePx - inset)

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = strokeWidthPx
            strokeCap = Paint.Cap.ROUND
            color = trackColor
        }
        canvas.drawArc(rect, 0f, 360f, false, trackPaint)

        val clamped = percent.coerceIn(0f, 100f)
        if (clamped > 0f) {
            val progressPaint = Paint(trackPaint).apply { color = progressColor }
            canvas.drawArc(rect, -90f, clamped / 100f * 360f, false, progressPaint)
        }

        if (percentText != null) {
            val centerX = sizePx / 2f
            val percentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = progressColor
                textAlign = Paint.Align.CENTER
                textSize = sizePx * 0.22f
                typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
            }
            val hasSubLabel = subLabel != null
            val percentBaselineY = if (hasSubLabel) {
                sizePx / 2f - (percentPaint.descent() + percentPaint.ascent()) / 2f - sizePx * 0.08f
            } else {
                sizePx / 2f - (percentPaint.descent() + percentPaint.ascent()) / 2f
            }
            canvas.drawText(percentText, centerX, percentBaselineY, percentPaint)

            if (subLabel != null) {
                val subPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = subLabelColor
                    textAlign = Paint.Align.CENTER
                    textSize = sizePx * 0.11f
                }
                val subBaselineY = sizePx / 2f - (subPaint.descent() + subPaint.ascent()) / 2f + sizePx * 0.16f
                canvas.drawText(subLabel, centerX, subBaselineY, subPaint)
            }
        }

        return bitmap
    }
}

/** Màu trạng thái dùng chung giữa Widget và tài liệu quy chuẩn Stitch (xem w1_states.png):
 * xanh &lt;80% an toàn · cam 80-100% lưu ý · đỏ &gt;100% vượt. */
object SafeSpendColors {
    val SAFE = Color.parseColor("#16A34A") // green-600
    val CAUTION = Color.parseColor("#F59E0B") // amber-500
    val OVER = Color.parseColor("#DC2626") // red-600
    val NEUTRAL = Color.parseColor("#94A3B8") // slate-400 (track vòng tròn)
    val CARD_BG = Color.parseColor("#F8FAFC")
    val TEXT_PRIMARY = Color.parseColor("#0F172A")
    val TEXT_SECONDARY = Color.parseColor("#64748B")

    /** Nền nút outline (vd "Ghi chép" trên W2) khi không dùng nền tối TEXT_PRIMARY. */
    val NEUTRAL_LIGHT_BG = Color.parseColor("#E2E8F0") // slate-200

    // Bản sáng/tối theo giao diện hệ thống (Glance tự chọn theo uiMode). Giữ đồng bộ values*/colors.xml.
    private fun pair(day: Long, night: Long) = androidx.glance.color.ColorProvider(
        day = androidx.compose.ui.graphics.Color(day),
        night = androidx.compose.ui.graphics.Color(night),
    )
    val cardBg = pair(0xFFF8FAFC, 0xFF1E293B)
    val textPrimary = pair(0xFF0F172A, 0xFFF1F5F9)
    val textSecondary = pair(0xFF64748B, 0xFF94A3B8)
    val chipBg = pair(0xFFE2E8F0, 0xFF334155)
    /** Chữ trên nền [textPrimary] (nút "đầy"): đảo màu theo chế độ. */
    val onPrimary = pair(0xFFFFFFFF, 0xFF0F172A)

    /** Màu chữ phụ cho bitmap vẽ tay (ProgressRing), nơi không dùng được ColorProvider. */
    fun secondaryInt(context: android.content.Context): Int {
        val night = context.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK == android.content.res.Configuration.UI_MODE_NIGHT_YES
        return if (night) Color.parseColor("#94A3B8") else TEXT_SECONDARY
    }
}

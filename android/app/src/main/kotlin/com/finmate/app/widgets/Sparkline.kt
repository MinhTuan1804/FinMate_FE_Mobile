package com.finmate.app.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path

/** Đường biểu đồ nhỏ (không trục, không nhãn) cho thẻ "Dự báo cuối tháng". Glance không vẽ được đường cong trực tiếp nên vẽ sẵn
 * thành bitmap rồi hiển thị bằng `Image`, cùng cách làm với [ProgressRing]. */
object Sparkline {
    fun draw(values: List<Long>, widthPx: Int, heightPx: Int, lineColor: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val stroke = heightPx * 0.07f
        val pad = stroke * 1.6f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            color = lineColor
        }
        if (values.size < 2) {
            // Chưa có chuỗi dự báo: đường phẳng ở giữa, vẫn báo "đây là chỗ biểu đồ".
            canvas.drawLine(pad, heightPx / 2f, widthPx - pad, heightPx / 2f, paint)
            return bitmap
        }
        val min = values.min()
        val max = values.max()
        val span = (max - min).coerceAtLeast(1L).toFloat()
        val usableW = widthPx - 2 * pad
        val usableH = heightPx - 2 * pad
        val path = Path()
        var lastX = 0f
        var lastY = 0f
        values.forEachIndexed { i, v ->
            val x = pad + usableW * i / (values.size - 1)
            val y = pad + usableH * (1f - (v - min) / span)
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            lastX = x
            lastY = y
        }
        canvas.drawPath(path, paint)
        // chấm cuối: giá trị cuối tháng
        val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL; color = lineColor }
        canvas.drawCircle(lastX, lastY, stroke * 1.4f, dot)
        return bitmap
    }
}

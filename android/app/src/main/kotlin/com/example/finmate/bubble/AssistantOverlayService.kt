package com.example.finmate.bubble

import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import com.example.finmate.R
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Bong bóng FinMate AI tự vẽ đè lên mọi ứng dụng (quyền "Hiện trên các ứng dụng khác"), dùng cho máy không
 * hiển thị Bubbles API của hệ thống (MIUI/HyperOS, Android < 11). Kéo thả, thả ra thì hít về mép gần nhất,
 * kéo vào ô X ở đáy để tắt. Chạm thì như Messenger: bong bóng chạy lên góc trên bên phải và khung chat
 * [AssistantOverlayActivity] mở ngay bên dưới; chạm lần nữa (hoặc đóng khung) thì bong bóng về chỗ cũ.
 *
 * ponytail: Service thường (không foreground). Process đang có cửa sổ overlay hiển thị được Android xếp
 * "perceptible" nên hiếm bị kill; nếu ROM vẫn kill, chuyển sang foreground service (specialUse) + thông báo thường trực.
 */
class AssistantOverlayService : Service() {
    private lateinit var wm: WindowManager
    private var bubble: ImageView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var closeTarget: View? = null

    /** Khung chat đang mở; khi đó bong bóng nằm ở góc trên bên phải. */
    private var expanded = false
    private var collapsedX = 0
    private var collapsedY = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(WindowManager::class.java)
        if (!Settings.canDrawOverlays(this)) {
            stopSelf() // quyền bị thu hồi khi service được hệ thống khởi động lại
            return
        }
        running = true
        instance = this
        addBubble()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        running = false
        instance = null
        AssistantOverlayActivity.current?.finish()
        bubble?.let { wm.removeView(it) }
        closeTarget?.let { wm.removeView(it) }
        bubble = null
        closeTarget = null
        AssistantOverlayActivity.releaseEngine()
        super.onDestroy()
    }

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics).toInt()

    private fun overlayParams(w: Int, h: Int, touchable: Boolean) = WindowManager.LayoutParams(
        w,
        h,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        },
        // Không lấy focus để bàn phím/thao tác của app bên dưới vẫn hoạt động bình thường.
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            (if (touchable) 0 else WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE),
        PixelFormat.TRANSLUCENT,
    ).apply { gravity = Gravity.TOP or Gravity.START }

    private fun addBubble() {
        val size = dp(BUBBLE_DP)
        val screen = resources.displayMetrics
        val params = overlayParams(size, size, touchable = true).apply {
            x = screen.widthPixels - size - dp(EDGE_DP)
            y = (screen.heightPixels * 0.3f).toInt()
        }
        val view = ImageView(this).apply {
            setImageResource(R.mipmap.ic_launcher)
            scaleType = ImageView.ScaleType.CENTER_CROP
            contentDescription = "Mở FinMate AI"
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) = outline.setOval(0, 0, view.width, view.height)
            }
            clipToOutline = true
            elevation = dp(6f).toFloat()
            setOnTouchListener(DragListener())
        }
        wm.addView(view, params)
        bubble = view
        bubbleParams = params
    }

    private fun showCloseTarget() {
        if (closeTarget != null) return
        val size = dp(CLOSE_DP)
        val screen = resources.displayMetrics
        val params = overlayParams(size, size, touchable = false).apply {
            x = (screen.widthPixels - size) / 2
            y = screen.heightPixels - size - dp(CLOSE_BOTTOM_DP)
        }
        val view = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(CLOSE_TARGET_COLOR)
            }
            addView(
                ImageView(context).apply { setImageResource(R.drawable.ic_x) },
                FrameLayout.LayoutParams(dp(24f), dp(24f), Gravity.CENTER),
            )
        }
        wm.addView(view, params)
        closeTarget = view
    }

    private fun hideCloseTarget() {
        closeTarget?.let { wm.removeView(it) }
        closeTarget = null
    }

    /** Tâm bong bóng có nằm trong vùng hút của ô X không. */
    private fun isOverCloseTarget(params: WindowManager.LayoutParams): Boolean {
        val screen = resources.displayMetrics
        val half = dp(BUBBLE_DP) / 2
        val targetX = screen.widthPixels / 2f
        val targetY = screen.heightPixels - dp(CLOSE_BOTTOM_DP) - dp(CLOSE_DP) / 2f
        return hypot(params.x + half - targetX, params.y + half - targetY) < dp(CLOSE_DP)
    }

    private fun snapToEdge(view: View, params: WindowManager.LayoutParams) {
        val screen = resources.displayMetrics.widthPixels
        val size = dp(BUBBLE_DP)
        val target = if (params.x + size / 2 < screen / 2) dp(EDGE_DP) else screen - size - dp(EDGE_DP)
        ValueAnimator.ofInt(params.x, target).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                if (bubble == null) return@addUpdateListener
                params.x = it.animatedValue as Int
                wm.updateViewLayout(view, params)
            }
            start()
        }
    }

    private fun statusBarHeight(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else dp(24f)
    }

    private fun toggleChat() {
        if (expanded) collapse() else expand()
    }

    private fun expand() {
        val view = bubble ?: return
        val params = bubbleParams ?: return
        expanded = true
        collapsedX = params.x
        collapsedY = params.y
        val size = dp(BUBBLE_DP)
        val targetX = resources.displayMetrics.widthPixels - size - dp(EDGE_DP)
        val targetTop = statusBarHeight() + dp(EXPANDED_TOP_DP)
        moveTo(view, params, targetX, targetTop) {
            // Gốc toạ độ overlay có thể đã trừ thanh trạng thái tuỳ ROM: đo vị trí thật rồi chỉnh cho đúng,
            // để khớp với khung chat Flutter (dựa vào MediaQuery.padding.top + các hằng số cùng giá trị).
            val loc = IntArray(2)
            view.getLocationOnScreen(loc)
            if (loc[1] != targetTop) {
                params.y += targetTop - loc[1]
                wm.updateViewLayout(view, params)
            }
        }
        startActivity(Intent(this, AssistantOverlayActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /** Thu khung chat lại và đưa bong bóng về chỗ trước khi mở. */
    private fun collapse() {
        AssistantOverlayActivity.current?.finish()
        returnToCollapsedPosition()
    }

    private fun returnToCollapsedPosition() {
        if (!expanded) return
        expanded = false
        val view = bubble ?: return
        val params = bubbleParams ?: return
        moveTo(view, params, collapsedX, collapsedY)
    }

    private fun moveTo(view: View, params: WindowManager.LayoutParams, x: Int, y: Int, onEnd: (() -> Unit)? = null) {
        val fromX = params.x
        val fromY = params.y
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                if (bubble == null) return@addUpdateListener
                val t = it.animatedValue as Float
                params.x = (fromX + (x - fromX) * t).toInt()
                params.y = (fromY + (y - fromY) * t).toInt()
                wm.updateViewLayout(view, params)
            }
            if (onEnd != null) {
                addListener(object : android.animation.AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: android.animation.Animator) {
                        if (bubble != null) onEnd()
                    }
                })
            }
            start()
        }
    }

    private inner class DragListener : View.OnTouchListener {
        private val slop = ViewConfiguration.get(this@AssistantOverlayService).scaledTouchSlop
        private var startX = 0
        private var startY = 0
        private var downRawX = 0f
        private var downRawY = 0f
        private var dragging = false

        override fun onTouch(view: View, e: MotionEvent): Boolean {
            val params = bubbleParams ?: return false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    downRawX = e.rawX
                    downRawY = e.rawY
                    dragging = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downRawX
                    val dy = e.rawY - downRawY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        // Kéo khi khung đang mở: thu khung lại, bong bóng đi theo ngón tay (như Messenger).
                        if (expanded) {
                            expanded = false
                            AssistantOverlayActivity.current?.finish()
                        }
                        showCloseTarget()
                    }
                    if (dragging) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        wm.updateViewLayout(view, params)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragging) {
                        view.performClick()
                        toggleChat()
                    } else {
                        hideCloseTarget()
                        if (isOverCloseTarget(params)) stopSelf() else snapToEdge(view, params)
                    }
                }
                MotionEvent.ACTION_CANCEL -> {
                    hideCloseTarget()
                    if (dragging) snapToEdge(view, params)
                }
            }
            return true
        }
    }

    companion object {
        /** Bong bóng vẽ đè có đang hiện không (đọc từ kênh status). */
        @Volatile
        var running = false
            private set

        // BUBBLE_DP và EDGE_DP phải trùng kBubbleSize/kBubbleEdge trong assistant_overlay_frame.dart.
        private const val BUBBLE_DP = 56f
        private const val EDGE_DP = 8f
        private const val CLOSE_DP = 64f
        private const val CLOSE_BOTTOM_DP = 56f

        // Khoảng cách từ đáy thanh trạng thái tới đỉnh bong bóng khi khung chat mở.
        // Phải trùng với kBubbleExpandedTop trong assistant_overlay_frame.dart.
        private const val EXPANDED_TOP_DP = 8f

        private var instance: AssistantOverlayService? = null

        /** Khung chat vừa đóng (back, chạm ra ngoài, nút phóng to): đưa bong bóng về chỗ cũ. */
        fun onPanelClosed() {
            instance?.returnToCollapsedPosition()
        }

        // Nền ô X: đen mờ 80%, nổi rõ trên mọi nền app bên dưới.
        private const val CLOSE_TARGET_COLOR = 0xCC111827.toInt()

        fun start(context: Context) {
            context.startService(Intent(context, AssistantOverlayService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AssistantOverlayService::class.java))
        }
    }
}

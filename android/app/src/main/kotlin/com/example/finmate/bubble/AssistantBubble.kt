package com.example.finmate.bubble

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.example.finmate.MainActivity
import com.example.finmate.R

/**
 * Bong bóng "FinMate AI" kiểu Messenger, dựng bằng Bubbles API của Android (11+): hệ điều hành tự vẽ
 * bong bóng nổi trên mọi ứng dụng, tự lo kéo thả/hít mép/kéo vào X để tắt; bấm vào mở
 * [AssistantBubbleActivity] trong cửa sổ nổi. Không dùng quyền SYSTEM_ALERT_WINDOW.
 *
 * Điều kiện Android đặt ra để một thông báo thành bong bóng: là thông báo hội thoại (MessagingStyle +
 * Person) gắn với shortcut long-lived, kênh cho phép bubble, và người dùng không tắt bong bóng cho app.
 */
object AssistantBubble {
    private const val CHANNEL_ID = "assistant_bubble"
    private const val SHORTCUT_ID = "finmate_ai"
    private const val NOTIFICATION_ID = 7301

    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R

    /**
     * "system" = Bubbles API (hệ điều hành vẽ bong bóng); "overlay" = [AssistantOverlayService] tự vẽ đè.
     * MIUI/HyperOS nhận cờ bong bóng nhưng không vẽ bong bóng nổi (đã kiểm tra trên Xiaomi MIUI 13, Android 12),
     * Android < 11 không có Bubbles API → dùng overlay.
     * ponytail: chỉ nhận diện MIUI/HyperOS; gặp ROM khác cũng không vẽ bubble thì thêm vào đây.
     */
    fun mode(): String = if (isSupported() && !isMiui()) "system" else "overlay"

    private fun isMiui(): Boolean = !systemProperty("ro.miui.ui.version.name").isNullOrEmpty() ||
        !systemProperty("ro.mi.os.version.name").isNullOrEmpty()

    @Suppress("PrivateApi")
    private fun systemProperty(key: String): String? = try {
        Class.forName("android.os.SystemProperties").getMethod("get", String::class.java).invoke(null, key) as? String
    } catch (_: Exception) {
        null
    }

    fun hasNotificationPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** Người dùng có đang cho phép FinMate hiện bong bóng không (cấp app và cấp kênh). */
    fun bubblesAllowed(context: Context): Boolean {
        if (!isSupported()) return false
        ensureChannel(context)
        val nm = context.getSystemService(NotificationManager::class.java)
        // Chỉ xét lựa chọn cấp app (màn "Bong bóng" của FinMate). KHÔNG xét channel.canBubble(): từ Android 11
        // hệ điều hành bỏ qua setAllowBubbles() của app, kênh mới luôn ở mức "mặc định" (-1) nên canBubble()
        // trả false dù người dùng đã chọn "Mọi cuộc trò chuyện" — đã gặp thật trên Android 12.
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            nm.bubblePreference != NotificationManager.BUBBLE_PREFERENCE_NONE
        } else {
            @Suppress("DEPRECATION")
            nm.areBubblesAllowed()
        }
    }

    /** Màn cài đặt bong bóng của FinMate (Android 11+), để người dùng tự bật khi đang tắt. */
    fun bubbleSettingsIntent(context: Context): Intent =
        Intent(Settings.ACTION_APP_NOTIFICATION_BUBBLE_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    /** Đăng (hoặc cập nhật) thông báo hội thoại mang bong bóng. Trả false nếu thiếu quyền thông báo. */
    fun show(context: Context): Boolean {
        if (!isSupported() || !hasNotificationPermission(context)) return false
        ensureChannel(context)

        val icon = IconCompat.createWithResource(context, R.mipmap.ic_launcher)
        val ai = Person.Builder().setName("FinMate AI").setIcon(icon).setKey(SHORTCUT_ID).setImportant(true).build()

        ShortcutManagerCompat.pushDynamicShortcut(
            context,
            ShortcutInfoCompat.Builder(context, SHORTCUT_ID)
                .setLongLived(true)
                .setShortLabel("FinMate AI")
                .setIcon(icon)
                .setPerson(ai)
                .setIntent(Intent(context, MainActivity::class.java).setAction(Intent.ACTION_VIEW))
                .build(),
        )

        // Bubble bắt buộc PendingIntent MUTABLE (hệ điều hành gắn thêm extra khi mở cửa sổ nổi).
        val bubbleIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, AssistantBubbleActivity::class.java).setAction(Intent.ACTION_VIEW),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_sparkles)
            .setContentTitle("FinMate AI")
            .setContentText("Chạm để ghi chi tiêu hoặc hỏi FinMate")
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setShortcutId(SHORTCUT_ID)
            .addPerson(ai)
            .setStyle(
                NotificationCompat.MessagingStyle(ai)
                    .addMessage("Chạm để ghi chi tiêu hoặc hỏi FinMate", System.currentTimeMillis(), ai),
            )
            .setContentIntent(bubbleIntent)
            .setBubbleMetadata(
                NotificationCompat.BubbleMetadata.Builder(bubbleIntent, icon)
                    .setDesiredHeight(640)
                    .setAutoExpandBubble(false)
                    // Chỉ cần bong bóng, không để thêm một dòng thông báo trong khay.
                    .setSuppressNotification(true)
                    .build(),
            )
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            return false // người dùng vừa thu hồi quyền thông báo
        }
        return true
    }

    /** Thông báo mang bong bóng có đang hiện không (người dùng kéo bong bóng vào X thì Android gỡ nó). */
    fun isShowing(context: Context): Boolean =
        context.getSystemService(NotificationManager::class.java).activeNotifications.any { it.id == NOTIFICATION_ID }

    fun hide(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, "Bong bóng trợ lý", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Bong bóng FinMate AI nổi trên các ứng dụng khác"
            setShowBadge(false)
            setAllowBubbles(true)
        }
        nm.createNotificationChannel(channel)
    }
}

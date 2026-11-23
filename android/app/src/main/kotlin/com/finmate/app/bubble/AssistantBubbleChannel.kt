package com.finmate.app.bubble

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.finmate.app.MainActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Kênh Dart ↔ native cho bong bóng trợ lý (assistant_bubble_bridge.dart). Dùng ở cả MainActivity (công tắc
 * trong màn Cá nhân) và AssistantBubbleActivity (nút "Mở trong FinMate" của khung chat mini).
 */
class AssistantBubbleChannel(private val activity: Activity) {
    private var pendingPermission: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            val ctx = activity.applicationContext
            when (call.method) {
                "status" -> {
                    val overlay = AssistantBubble.mode() == "overlay"
                    result.success(
                        mapOf(
                            // minSdk 24 ≥ 23 nên chế độ overlay luôn dùng được.
                            "supported" to true,
                            "mode" to AssistantBubble.mode(),
                            "notificationPermission" to AssistantBubble.hasNotificationPermission(ctx),
                            "bubblesAllowed" to AssistantBubble.bubblesAllowed(ctx),
                            "overlayPermission" to Settings.canDrawOverlays(ctx),
                            "showing" to if (overlay) AssistantOverlayService.running else AssistantBubble.isShowing(ctx),
                        ),
                    )
                }
                "requestNotificationPermission" -> requestPermission(result)
                "show" -> if (AssistantBubble.mode() == "overlay") {
                    val allowed = Settings.canDrawOverlays(ctx)
                    if (allowed) AssistantOverlayService.start(ctx)
                    result.success(allowed)
                } else {
                    result.success(AssistantBubble.show(ctx))
                }
                "hide" -> {
                    AssistantBubble.hide(ctx)
                    AssistantOverlayService.stop(ctx)
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    activity.startActivity(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${ctx.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                "openBubbleSettings" -> {
                    if (AssistantBubble.isSupported()) activity.startActivity(AssistantBubble.bubbleSettingsIntent(ctx))
                    result.success(null)
                }
                "closePanel" -> {
                    // Chạm vùng trống phía trên khung chat (vẽ đè): thu khung, service đưa bong bóng về chỗ cũ.
                    if (activity is AssistantOverlayActivity) activity.finish()
                    result.success(null)
                }
                "openFullApp" -> {
                    // Khung chat mini (overlay) đóng lại khi đã sang app đầy đủ; bong bóng vẫn ở đó.
                    if (activity is AssistantOverlayActivity) activity.finish()
                    activity.startActivity(
                        Intent(ctx, MainActivity::class.java)
                            .setAction(Intent.ACTION_MAIN)
                            .addCategory(Intent.CATEGORY_LAUNCHER)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || AssistantBubble.hasNotificationPermission(activity)) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.error("BUSY", "Đang chờ người dùng trả lời quyền thông báo", null)
            return
        }
        pendingPermission = result
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
    }

    /** Gọi từ onRequestPermissionsResult của Activity. Trả true nếu đã xử lý request của kênh này. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
        return true
    }

    private companion object {
        const val CHANNEL = "com.finmate.app/assistant_bubble"
        const val REQUEST_CODE = 7302
    }
}

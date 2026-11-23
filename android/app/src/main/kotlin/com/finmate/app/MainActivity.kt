package com.finmate.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.glance.appwidget.updateAll
import androidx.lifecycle.lifecycleScope
import com.finmate.app.bubble.AssistantBubbleChannel
import com.finmate.app.notifications.NotificationChannelHandler
import com.finmate.app.widgets.DetailPrefs
import com.finmate.app.widgets.DetailSync
import com.finmate.app.widgets.DetailWidget
import com.finmate.app.widgets.DetailWidgetReceiver
import com.finmate.app.widgets.OverviewPrefs
import com.finmate.app.widgets.OverviewSync
import com.finmate.app.widgets.OverviewWidget
import com.finmate.app.widgets.OverviewWidgetReceiver
import com.finmate.app.widgets.SafeSpendPrefs
import com.finmate.app.widgets.SafeSpendSync
import com.finmate.app.widgets.SafeSpendWidget
import com.finmate.app.widgets.SafeSpendWidgetReceiver
import com.finmate.app.widgets.WidgetQuickFlash
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private lateinit var bubbleChannel: AssistantBubbleChannel

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (!bubbleChannel.onRequestPermissionsResult(requestCode, grantResults)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationChannelHandler(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        // Kênh cho push FCM (AndroidManifest: default_notification_channel_id). Mức HIGH để hiện nổi như
        // thông báo ngân hàng; tạo lại mỗi lần mở là no-op nếu đã có.
        NotificationManagerCompat.from(this).createNotificationChannel(
            NotificationChannelCompat.Builder(PUSH_NOTIFICATION_CHANNEL, NotificationManagerCompat.IMPORTANCE_HIGH)
                .setName("Giao dịch")
                .setDescription("Giao dịch mới cần xác nhận hoặc vừa được ghi")
                .build()
        )
        // App đang mở thì Android không tự đưa push FCM lên thanh thông báo: Dart (push_messaging.dart) gọi "show" để đăng
        // một bản im lặng (thẻ kính trong app đã báo rồi). Intent mang google.message_id nên khi bấm, firebase_messaging tự
        // tra lại tin đã lưu và phát onMessageOpenedApp như push thường → cùng một đường mở đúng màn.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PUSH_CHANNEL).setMethodCallHandler { call, result ->
            val id = call.argument<String>("id")
            when {
                id == null -> result.error("bad_args", "id is required", null)
                call.method == "show" -> {
                    val open = Intent(this, MainActivity::class.java)
                        .putExtra("google.message_id", id)
                        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val body = call.argument<String>("body")
                    val notification = NotificationCompat.Builder(this, PUSH_NOTIFICATION_CHANNEL)
                        .setSmallIcon(R.drawable.ic_stat_finmate)
                        .setColor(ContextCompat.getColor(this, R.color.push_accent))
                        .setContentTitle(call.argument<String>("title"))
                        .setContentText(body)
                        .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                        .setSilent(true)
                        .setAutoCancel(true)
                        .setContentIntent(
                            PendingIntent.getActivity(
                                this, id.hashCode(), open,
                                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                            )
                        )
                        .build()
                    try {
                        NotificationManagerCompat.from(this).notify(id, 0, notification)
                    } catch (_: SecurityException) {
                        // Người dùng tắt quyền thông báo: thẻ trong app vẫn hiện, không có gì khác để làm
                    }
                    result.success(null)
                }
                call.method == "cancel" -> {
                    NotificationManagerCompat.from(this).cancel(id, 0)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // Công tắc "Bong bóng trợ lý" trong màn Cá nhân.
        bubbleChannel = AssistantBubbleChannel(this).also { it.register(flutterEngine.dartExecutor.binaryMessenger) }

        // Cùng tên kênh với WidgetConfigBridge (widget_config_bridge.dart) nhưng chỉ phục vụ lối vào
        // "Widget trên màn hình chính" từ Cài đặt (K1WidgetConfigScreen mở trong app, không qua
        // WidgetConfigActivity native nên không có appWidgetId cụ thể) — cần hỏi đang ghim bao nhiêu
        // widget theo loại để áp dụng cấu hình cho TẤT CẢ.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CONFIG_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getPinnedWidgetIds") {
                val receiverClass = when (call.argument<String>("kind")) {
                    "w1" -> SafeSpendWidgetReceiver::class.java
                    "w4x4" -> DetailWidgetReceiver::class.java
                    else -> OverviewWidgetReceiver::class.java
                }
                val ids = AppWidgetManager.getInstance(this)
                    .getAppWidgetIds(ComponentName(this, receiverClass))
                    .toList()
                result.success(ids)
            } else {
                result.notImplemented()
            }
        }

        // Gọi từ WidgetRefreshBridge (widget_refresh_bridge.dart) ngay sau mọi thay đổi dữ liệu mà
        // widget home-screen hiển thị (tài khoản, ngân sách/mục tiêu, giao dịch). Gọi thẳng
        // *Sync.refresh() + *Widget().updateAll() trong 1 coroutine thay vì qua WorkManager
        // (*RefreshWorker.syncNow) — WorkManager/JobScheduler vẫn có thể tự hoãn expedited work khi hết
        // quota (lý do widget trước đây chỉ cập nhật sau khi app được foreground), còn ở đây app đang
        // sống sẵn (MainActivity) nên gọi đồng bộ trực tiếp là đủ và nhanh nhất. KHÔNG thay
        // *RefreshWorker.kt/schedulePeriodic() — WorkManager vẫn là đường chạy nền khi app bị kill
        // (onEnabled lúc ghim + chu kỳ định kỳ), coroutine ở đây không thể thay thế việc đó.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_REFRESH_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "syncAllWidgets") {
                Log.d(TAG_WIDGET_SYNC, "syncAllWidgets: invoked from Dart")
                // 3 widget riêng, chạy SONG SONG (launch riêng, không await nhau) thay vì nối tiếp —
                // trước đây 7 lượt gọi HTTP (1 của W1 + 2 của W2 + 4 của 4x4) chạy tuần tự trong cùng 1
                // coroutine nên tổng thời gian cộng dồn, đúng nguyên nhân "quá chậm". Mỗi launch tự
                // try/catch + log riêng — lỗi 1 widget không được làm mất log/chặn 2 widget còn lại,
                // và để lộ ra nếu 1 trong 3 đang âm thầm throw (trước đây không có try/catch nào quanh
                // *Sync.refresh()/*Widget().updateAll(), nên 1 exception bất ngờ có thể huỷ coroutine
                // giữa chừng mà không ai thấy gì trong log).
                lifecycleScope.launch(Dispatchers.IO) {
                    try {
                        val ok = SafeSpendSync.refresh(this@MainActivity)
                        // Thử nghiệm: đẩy thẳng bản RemoteViews cổ điển (không qua Glance Session) NGAY
                        // sau khi có dữ liệu mới — xem WidgetQuickFlash.kt để biết lý do + điều kiện bỏ.
                        SafeSpendPrefs.read(this@MainActivity)?.let { WidgetQuickFlash.flashW1(this@MainActivity, it) }
                        SafeSpendWidget().updateAll(this@MainActivity)
                        Log.d(TAG_WIDGET_SYNC, "W1 refresh ok=$ok, updateAll done")
                    } catch (e: Exception) {
                        Log.e(TAG_WIDGET_SYNC, "W1 sync failed", e)
                    }
                }
                lifecycleScope.launch(Dispatchers.IO) {
                    try {
                        val ok = OverviewSync.refresh(this@MainActivity)
                        OverviewPrefs.read(this@MainActivity)?.let { WidgetQuickFlash.flashW2(this@MainActivity, it) }
                        OverviewWidget().updateAll(this@MainActivity)
                        Log.d(TAG_WIDGET_SYNC, "W2 refresh ok=$ok, updateAll done")
                    } catch (e: Exception) {
                        Log.e(TAG_WIDGET_SYNC, "W2 sync failed", e)
                    }
                }
                lifecycleScope.launch(Dispatchers.IO) {
                    try {
                        val ok = DetailSync.refresh(this@MainActivity)
                        DetailPrefs.read(this@MainActivity)?.let { WidgetQuickFlash.flashDetail(this@MainActivity, it) }
                        DetailWidget().updateAll(this@MainActivity)
                        Log.d(TAG_WIDGET_SYNC, "4x4 refresh ok=$ok, updateAll done")
                    } catch (e: Exception) {
                        Log.e(TAG_WIDGET_SYNC, "4x4 sync failed", e)
                    }
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private companion object {
        const val WIDGET_CONFIG_CHANNEL = "com.finmate.app/widget_config"
        const val WIDGET_REFRESH_CHANNEL = "com.finmate.app/widget_refresh"
        const val TAG_WIDGET_SYNC = "FinMateWidgetSync"
        const val PUSH_CHANNEL = "com.finmate.app/push"
        const val PUSH_NOTIFICATION_CHANNEL = "finmate_transactions" // = default_notification_channel_id trong AndroidManifest
    }
}

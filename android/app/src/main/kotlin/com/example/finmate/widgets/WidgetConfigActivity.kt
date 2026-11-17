package com.example.finmate.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Android widget **configuration Activity** (k1_widget_config_screen.png) — hệ điều hành tự mở
 * màn này ngay sau khi người dùng kéo 1 trong 3 widget FinMate ra từ trình chọn "Tiện ích/Widgets"
 * (xem android:configure ở w1/w2/w4x4_widget_info.xml). KHÔNG qua app_router.dart.
 *
 * UI thật nằm ở phía Dart (K1WidgetConfigScreen, dùng chung cho cả màn hình này lẫn lối vào sửa
 * lại cấu hình sau này từ Cài đặt/H1) — Activity này chỉ là lớp vỏ FlutterActivity + kênh gọi về
 * native để đóng màn hình đúng cách theo quy ước AppWidget configuration activity của Android.
 */
class WidgetConfigActivity : FlutterActivity() {

    private var appWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    // FlutterEngineGroup mặc định của FlutterActivity (ở bản Flutter đang dùng) không đi đúng
    // entrypoint khai qua getDartEntrypointFunctionName()/getDartEntrypointLibraryUri() — tự tạo
    // FlutterEngine và chạy thẳng đúng entrypoint bằng DartExecutor.DartEntrypoint để né đường đó.
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val engine = FlutterEngine(context)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "package:finmate/widget_config_main.dart",
                "widgetConfigMain",
            ),
        )
        return engine
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Theo đúng quy ước AppWidget configuration activity: mặc định là CANCELED, chỉ đổi thành
        // OK khi người dùng bấm "Hoàn tất" — nếu người dùng bấm back giữa chừng, Android sẽ không
        // ghim widget dở dang.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWidgetId" -> result.success(appWidgetId)
                "getWidgetKind" -> result.success(resolveWidgetKind())
                "finishConfig" -> {
                    val accepted = call.argument<Boolean>("accepted") ?: false
                    finishConfig(accepted)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun finishConfig(accepted: Boolean) {
        if (accepted && appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            requestWidgetRefresh()
        } else {
            setResult(RESULT_CANCELED)
        }
        finish()
    }

    // "w1" (2×2 Chi an toàn) | "w2" (4×2 Tổng quan) | "w4x4" (Chi tiết) — Dart dùng để biết widget
    // nào đang được cấu hình (preselect đúng thẻ kích thước trong K1WidgetConfigScreen).
    private fun resolveWidgetKind(): String {
        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(appWidgetId)?.provider
        return when (provider?.className) {
            "com.example.finmate.widgets.SafeSpendWidgetReceiver" -> "w1"
            "com.example.finmate.widgets.OverviewWidgetReceiver" -> "w2"
            "com.example.finmate.widgets.DetailWidgetReceiver" -> "w4x4"
            else -> "w2"
        }
    }

    // Đánh thức đúng provider của widget vừa cấu hình để nó đọc lại dữ liệu Flutter vừa ghi qua
    // home_widget và vẽ lại ngay, không cần chờ tới chu kỳ WorkManager kế tiếp.
    private fun requestWidgetRefresh() {
        val manager = AppWidgetManager.getInstance(this)
        val provider = manager.getAppWidgetInfo(appWidgetId)?.provider ?: return
        val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
            component = provider
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        sendBroadcast(updateIntent)
    }

    companion object {
        private const val CHANNEL = "com.example.finmate/widget_config"
    }
}

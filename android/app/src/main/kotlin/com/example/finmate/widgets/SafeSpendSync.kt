package com.example.finmate.widgets

import android.content.Context
import com.example.finmate.notifications.NotificationRuntime
import com.example.finmate.notifications.RefreshResult
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

/** Dữ liệu đã tính sẵn cho W1 "Chi an toàn" — lưu/đọc qua đúng file SharedPreferences mà package
 * Flutter `home_widget` dùng ("HomeWidgetPreferences"), để nhất quán với cấu hình mà
 * K1WidgetConfigScreen đã ghi qua WidgetConfigBridge. */
object SafeSpendPrefs {
    // internal: OpenPlanningCallback (SafeSpendWidget.kt) cần ghi "pendingRoute" vào đúng file này.
    internal const val FILE = "HomeWidgetPreferences"

    private const val KEY_PER_DAY_CENTS = "w1_perDayCents"
    private const val KEY_SPENT_CENTS = "w1_spentCents"
    private const val KEY_PERCENT_USED = "w1_percentUsed"
    private const val KEY_HAS_BUDGET = "w1_hasBudget"
    private const val KEY_LAST_SYNC_AT = "w1_lastSyncAtMillis"
    private const val KEY_SYNC_ERROR = "w1_syncError"

    data class Data(
        val perDayCents: Long,
        val spentCents: Long,
        val percentUsed: Float,
        val hasBudget: Boolean,
        val lastSyncAtMillis: Long,
        val syncError: Boolean,
    )

    fun read(context: Context): Data? {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val lastSync = prefs.getLong(KEY_LAST_SYNC_AT, 0L)
        if (lastSync == 0L) return null // chưa đồng bộ lần nào
        return Data(
            perDayCents = prefs.getLong(KEY_PER_DAY_CENTS, 0L),
            spentCents = prefs.getLong(KEY_SPENT_CENTS, 0L),
            percentUsed = prefs.getFloat(KEY_PERCENT_USED, 0f),
            hasBudget = prefs.getBoolean(KEY_HAS_BUDGET, false),
            lastSyncAtMillis = lastSync,
            syncError = prefs.getBoolean(KEY_SYNC_ERROR, false),
        )
    }

    fun write(context: Context, data: Data) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putLong(KEY_PER_DAY_CENTS, data.perDayCents)
            .putLong(KEY_SPENT_CENTS, data.spentCents)
            .putFloat(KEY_PERCENT_USED, data.percentUsed)
            .putBoolean(KEY_HAS_BUDGET, data.hasBudget)
            .putLong(KEY_LAST_SYNC_AT, data.lastSyncAtMillis)
            .putBoolean(KEY_SYNC_ERROR, data.syncError)
            .commit()
    }

    /** Lần fetch lỗi (mất mạng/BE lỗi) nhưng ĐÃ từng có dữ liệu cũ: chỉ đánh dấu cờ lỗi, giữ
     * nguyên số liệu cũ để widget hiện "dữ liệu cũ" thay vì xoá sạch về trạng thái "đang đồng bộ". */
    fun markSyncError(context: Context) {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        if (prefs.getLong(KEY_LAST_SYNC_AT, 0L) == 0L) return
        prefs.edit().putBoolean(KEY_SYNC_ERROR, true).commit()
    }
}

/** Gọi GET /api/v1/me/spendable bằng token của native session store (EncryptedSessionStore) —
 * KHÔNG qua MethodChannel/Flutter engine, vì kênh đó chỉ được đăng ký khi MainActivity đang sống
 * (xem MainActivity.configureFlutterEngine), còn WorkManager chạy cả khi app đã bị kill. */
object SafeSpendSync {
    private const val TIMEOUT_MS = 15_000

    /** true = đã đồng bộ thành công (hoặc không có phiên đăng nhập, không tính là lỗi). */
    fun refresh(context: Context): Boolean {
        val runtime = NotificationRuntime.get(context)
        val store = runtime.store
        val baseUrl = store.baseUrl
        var token = store.accessToken
        if (baseUrl.isNullOrEmpty() || token.isNullOrEmpty()) return true // chưa đăng nhập: không phải lỗi, chỉ chưa có gì để đồng bộ

        return try {
            var result = fetchSpendable(baseUrl, token)
            // Access token hết hạn: xoay 1 lần theo đúng cơ chế dùng chung với NotificationSender.drain().
            if (result is FetchResult.Unauthorized) {
                when (val r = runtime.refresher.refresh(token)) {
                    is RefreshResult.Ok -> {
                        token = r.accessToken
                        result = fetchSpendable(baseUrl, token)
                    }
                    else -> { /* Expired/Network: giữ nguyên kết quả 401 cũ, coi như lỗi đồng bộ bên dưới. */
                    }
                }
            }
            when (result) {
                is FetchResult.Ok -> {
                    SafeSpendPrefs.write(context, computeFrom(result.json))
                    true
                }
                else -> {
                    SafeSpendPrefs.markSyncError(context)
                    false
                }
            }
        } catch (e: Exception) {
            SafeSpendPrefs.markSyncError(context)
            false
        }
    }

    private sealed interface FetchResult {
        data class Ok(val json: JSONObject) : FetchResult
        object Unauthorized : FetchResult
        object Failed : FetchResult
    }

    private fun fetchSpendable(baseUrl: String, token: String): FetchResult {
        val conn = URL(baseUrl.trimEnd('/') + "/api/v1/me/spendable").openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "GET"
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            conn.setRequestProperty("Accept", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("ngrok-skip-browser-warning", "true")
            val code = conn.responseCode
            if (code == 401) return FetchResult.Unauthorized
            if (code !in 200..299) return FetchResult.Failed
            val text = conn.inputStream.bufferedReader().use { it.readText() }
            val data = JSONObject(text).optJSONObject("data") ?: return FetchResult.Failed
            return FetchResult.Ok(data)
        } finally {
            conn.disconnect()
        }
    }

    /// Cùng công thức với `_buildSafeToSpendCard` (home_screen.dart): perDay = spendableCents /
    /// số ngày còn lại trong tháng; percentUsed = spentCents/incomeCents*100 (0 nếu chưa biết thu nhập).
    private fun computeFrom(json: JSONObject): SafeSpendPrefs.Data {
        val spendableCents = json.optLong("spendableCents", Long.MIN_VALUE).takeIf { !json.isNull("spendableCents") && it != Long.MIN_VALUE }
        val incomeCents = json.optLong("incomeCents", Long.MIN_VALUE).takeIf { !json.isNull("incomeCents") && it != Long.MIN_VALUE }
        val spentCents = json.optLong("spentCents", 0L)

        val cal = java.util.Calendar.getInstance()
        val lastDay = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
        val daysRemaining = lastDay - cal.get(java.util.Calendar.DAY_OF_MONTH) + 1
        val perDay = if (spendableCents != null && daysRemaining > 0) spendableCents / daysRemaining else 0L
        val percentUsed = if (incomeCents == null || incomeCents == 0L) 0f else (spentCents.toFloat() / incomeCents.toFloat() * 100f)

        return SafeSpendPrefs.Data(
            perDayCents = perDay,
            spentCents = spentCents,
            percentUsed = percentUsed,
            hasBudget = spendableCents != null,
            lastSyncAtMillis = System.currentTimeMillis(),
            syncError = false,
        )
    }
}

package com.example.finmate.widgets

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.example.finmate.notifications.NotificationRuntime
import com.example.finmate.notifications.RefreshResult
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject

/** Dữ liệu đã tính sẵn cho W2 "Tổng quan" — cùng file SharedPreferences "HomeWidgetPreferences" với
 * W1 (xem SafeSpendPrefs.FILE), tiền tố khoá "w2_" để không đụng key của W1. */
object OverviewPrefs {
    private const val KEY_BALANCE_CENTS = "w2_balanceCents"
    private const val KEY_PERCENT_USED = "w2_percentUsed"
    private const val KEY_HAS_BUDGET = "w2_hasBudget"
    private const val KEY_ACCOUNT_LABEL = "w2_accountLabel"
    private const val KEY_LAST_SYNC_AT = "w2_lastSyncAtMillis"
    private const val KEY_SYNC_ERROR = "w2_syncError"
    private const val KEY_SPENT_CENTS = "w2_spentCents"
    private const val KEY_PER_DAY_CENTS = "w2_perDayCents"

    data class Data(
        val balanceCents: Long,
        val percentUsed: Float,
        val hasBudget: Boolean,
        val accountLabel: String,
        val lastSyncAtMillis: Long,
        val syncError: Boolean,
        val spentCents: Long,
        val perDayCents: Long,
    )

    fun read(context: Context): Data? {
        val prefs = context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
        val lastSync = prefs.getLong(KEY_LAST_SYNC_AT, 0L)
        if (lastSync == 0L) return null // chưa đồng bộ lần nào
        return Data(
            balanceCents = prefs.getLong(KEY_BALANCE_CENTS, 0L),
            percentUsed = prefs.getFloat(KEY_PERCENT_USED, 0f),
            hasBudget = prefs.getBoolean(KEY_HAS_BUDGET, false),
            accountLabel = prefs.getString(KEY_ACCOUNT_LABEL, null) ?: "Tất cả tài khoản",
            lastSyncAtMillis = lastSync,
            syncError = prefs.getBoolean(KEY_SYNC_ERROR, false),
            spentCents = prefs.getLong(KEY_SPENT_CENTS, 0L),
            perDayCents = prefs.getLong(KEY_PER_DAY_CENTS, 0L),
        )
    }

    fun write(context: Context, data: Data) {
        context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE).edit()
            .putLong(KEY_BALANCE_CENTS, data.balanceCents)
            .putFloat(KEY_PERCENT_USED, data.percentUsed)
            .putBoolean(KEY_HAS_BUDGET, data.hasBudget)
            .putString(KEY_ACCOUNT_LABEL, data.accountLabel)
            .putLong(KEY_LAST_SYNC_AT, data.lastSyncAtMillis)
            .putBoolean(KEY_SYNC_ERROR, false)
            .putLong(KEY_SPENT_CENTS, data.spentCents)
            .putLong(KEY_PER_DAY_CENTS, data.perDayCents)
            .commit()
    }

    /** Giữ nguyên số liệu cũ, chỉ đánh dấu cờ lỗi — cùng cách W1 xử lý mất mạng/BE lỗi. */
    fun markSyncError(context: Context) {
        val prefs = context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
        if (prefs.getLong(KEY_LAST_SYNC_AT, 0L) == 0L) return
        prefs.edit().putBoolean(KEY_SYNC_ERROR, true).commit()
    }
}

/** Gọi GET /api/v1/financial-accounts + GET /api/v1/me/spendable để tính số dư khả dụng + % ngân
 * sách tháng đã dùng cho W2 — cùng cơ chế phiên/token với SafeSpendSync (không qua Flutter engine,
 * chạy được cả khi app đã bị kill), xem SafeSpendSync để biết lý do không tái dùng MethodChannel. */
object OverviewSync {
    private const val TIMEOUT_MS = 15_000

    /** true = đã đồng bộ thành công (hoặc không có phiên đăng nhập, không tính là lỗi). suspend vì
     * [readSourceAccountId] gọi `GlanceAppWidgetManager.getGlanceIds` (suspend) — luôn được gọi từ
     * [OverviewRefreshWorker.doWork], đã ở trong 1 coroutine sẵn. */
    suspend fun refresh(context: Context): Boolean {
        val runtime = NotificationRuntime.get(context)
        val store = runtime.store
        val baseUrl = store.baseUrl
        var token = store.accessToken
        if (baseUrl.isNullOrEmpty() || token.isNullOrEmpty()) return true // chưa đăng nhập: không phải lỗi

        return try {
            var accounts = fetchJson(baseUrl, token, "/api/v1/financial-accounts")
            var spendable = fetchJson(baseUrl, token, "/api/v1/me/spendable")
            if (accounts is FetchResult.Unauthorized || spendable is FetchResult.Unauthorized) {
                when (val r = runtime.refresher.refresh(token)) {
                    is RefreshResult.Ok -> {
                        token = r.accessToken
                        accounts = fetchJson(baseUrl, token, "/api/v1/financial-accounts")
                        spendable = fetchJson(baseUrl, token, "/api/v1/me/spendable")
                    }
                    else -> { /* giữ nguyên kết quả 401 cũ, rơi vào nhánh lỗi bên dưới */ }
                }
            }
            if (accounts is FetchResult.Ok && spendable is FetchResult.Ok) {
                val sourceAccountId = readSourceAccountId(context)
                OverviewPrefs.write(context, computeFrom(accounts.body as JSONArray, spendable.body as JSONObject, sourceAccountId))
                true
            } else {
                OverviewPrefs.markSyncError(context)
                false
            }
        } catch (e: Exception) {
            OverviewPrefs.markSyncError(context)
            false
        }
    }

    /// Nguồn tiền hiển thị đã chọn trong màn cấu hình (sourceAccountId_$widgetId, ghi bởi
    /// WidgetConfigBridge) — đọc theo instance OverviewWidget đầu tiên đang ghim, cùng cách đơn giản
    /// hoá mà Flutter đang dùng khi sửa cấu hình từ Cài đặt (getPinnedWidgetIds().first).
    private suspend fun readSourceAccountId(context: Context): String? {
        return try {
            val manager = GlanceAppWidgetManager(context)
            val ids = manager.getGlanceIds(OverviewWidget::class.java)
            if (ids.isEmpty()) return null
            val widgetId = manager.getAppWidgetId(ids.first())
            val raw = context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
                .getString("sourceAccountId_$widgetId", null)
            raw?.takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            null
        }
    }

    private sealed interface FetchResult {
        data class Ok(val body: Any) : FetchResult
        object Unauthorized : FetchResult
        object Failed : FetchResult
    }

    private fun fetchJson(baseUrl: String, token: String, path: String): FetchResult {
        val conn = URL(baseUrl.trimEnd('/') + path).openConnection() as HttpURLConnection
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
            val data = JSONObject(text).opt("data") ?: return FetchResult.Failed
            return FetchResult.Ok(data)
        } finally {
            conn.disconnect()
        }
    }

    /// Cùng công thức percentUsed với SafeSpendSync (spent/income*100); số dư = tổng balanceCents các
    /// tài khoản, lọc theo [sourceAccountId] nếu có chọn 1 tài khoản cụ thể (null = tất cả).
    private fun computeFrom(accounts: JSONArray, spendable: JSONObject, sourceAccountId: String?): OverviewPrefs.Data {
        var balanceCents = 0L
        var accountLabel = "Tất cả tài khoản"
        for (i in 0 until accounts.length()) {
            val account = accounts.getJSONObject(i)
            val id = account.optString("id")
            if (sourceAccountId != null && id != sourceAccountId) continue
            balanceCents += account.optLong("balanceCents", 0L)
            if (sourceAccountId != null) accountLabel = account.optString("accountName", accountLabel)
        }

        val incomeCents = spendable.optLong("incomeCents", Long.MIN_VALUE).takeIf { !spendable.isNull("incomeCents") && it != Long.MIN_VALUE }
        val spentCents = spendable.optLong("spentCents", 0L)
        val percentUsed = if (incomeCents == null || incomeCents == 0L) 0f else (spentCents.toFloat() / incomeCents.toFloat() * 100f)
        val spendableCents = spendable.optLong("spendableCents", Long.MIN_VALUE).takeIf { !spendable.isNull("spendableCents") && it != Long.MIN_VALUE }
        val hasBudget = spendableCents != null

        // Cùng công thức với SafeSpendSync.computeFrom: perDay = spendableCents / số ngày còn lại trong tháng.
        val cal = java.util.Calendar.getInstance()
        val lastDay = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
        val daysRemaining = lastDay - cal.get(java.util.Calendar.DAY_OF_MONTH) + 1
        val perDayCents = if (spendableCents != null && daysRemaining > 0) spendableCents / daysRemaining else 0L

        return OverviewPrefs.Data(
            balanceCents = balanceCents,
            percentUsed = percentUsed,
            hasBudget = hasBudget,
            accountLabel = accountLabel,
            lastSyncAtMillis = System.currentTimeMillis(),
            syncError = false,
            spentCents = spentCents,
            perDayCents = perDayCents,
        )
    }
}

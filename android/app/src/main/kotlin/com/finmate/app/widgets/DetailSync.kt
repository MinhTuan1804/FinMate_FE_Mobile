package com.finmate.app.widgets

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.finmate.app.notifications.NotificationRuntime
import com.finmate.app.notifications.RefreshResult
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

/** Dữ liệu đã tính sẵn cho widget 4×4 "Chi tiết" — cùng file SharedPreferences "HomeWidgetPreferences"
 * với W1/W2 (xem SafeSpendPrefs.FILE), tiền tố khoá "w4x4_" để không đụng key của W1/W2. */
object DetailPrefs {
    private const val KEY_BALANCE_CENTS = "w4x4_balanceCents"
    private const val KEY_FORECAST_END_BALANCE_CENTS = "w4x4_forecastEndBalanceCents"
    private const val KEY_TRANSACTIONS_TODAY_COUNT = "w4x4_transactionsTodayCount"
    private const val KEY_ACCOUNT_LABEL = "w4x4_accountLabel"
    private const val KEY_LAST_SYNC_AT = "w4x4_lastSyncAtMillis"
    private const val KEY_SYNC_ERROR = "w4x4_syncError"
    private const val KEY_PERCENT_USED = "w4x4_percentUsed"
    private const val KEY_HAS_BUDGET = "w4x4_hasBudget"
    private const val KEY_SPENT_CENTS = "w4x4_spentCents"
    private const val KEY_INCOME_CENTS = "w4x4_incomeCents"
    private const val KEY_SPENT_TODAY_CENTS = "w4x4_spentTodayCents"
    private const val KEY_SAFE_TODAY_CENTS = "w4x4_safeTodayCents"
    private const val KEY_OVER_MONTH = "w4x4_overMonth"
    private const val KEY_MONTH_OVER_CENTS = "w4x4_monthOverCents"
    private const val KEY_UPCOMING_LIST = "w4x4_upcomingList"
    private const val KEY_FORECAST_SERIES = "w4x4_forecastSeries"
    private const val KEY_FORECAST_CONFIDENCE = "w4x4_forecastConfidence"
    private const val KEY_RECENT_TRANSACTIONS = "w4x4_recentTransactions"

    /** 1 dòng trong "GIAO DỊCH VỪA GHI NHẬN" (xem design_reference/W_widgets/w_4x4_detail.png) —
     * quyết định 2026-11-17: đảo ngược lần nữa quyết định thu gọn trước đó (bỏ danh sách chi tiết vì
     * lộ thói quen chi tiêu), người dùng đã xác nhận chấp nhận đánh đổi này. */
    data class RecentTxn(
        val description: String,
        val categoryLabel: String,
        val timeMillis: Long,
        val amountCents: Long,
        val isIncome: Boolean,
    )

    const val UPCOMING_LIMIT = 3
    const val SERIES_POINTS = 24

    data class Upcoming(val name: String, val amountCents: Long, val dueDate: String)

    private fun readUpcoming(prefs: android.content.SharedPreferences): List<Upcoming> {
        val raw = prefs.getString(KEY_UPCOMING_LIST, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Upcoming(o.optString("name"), o.optLong("amountCents"), o.optString("dueDate"))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun writeUpcoming(items: List<Upcoming>): String {
        val arr = JSONArray()
        items.forEach { arr.put(JSONObject().put("name", it.name).put("amountCents", it.amountCents).put("dueDate", it.dueDate)) }
        return arr.toString()
    }

    data class Data(
        val balanceCents: Long,
        val forecastEndBalanceCents: Long,
        val transactionsTodayCount: Int,
        val accountLabel: String,
        val lastSyncAtMillis: Long,
        val syncError: Boolean,
        val percentUsed: Float,
        val hasBudget: Boolean,
        val spentCents: Long,
        val incomeCents: Long,
        val recentTransactions: List<RecentTxn>,
        val spentTodayCents: Long = 0L,
        val safeTodayCents: Long = 0L,
        val overMonth: Boolean = false,
        val monthOverCents: Long = 0L,
        /** Các khoản định kỳ (loại chi) sắp đến hạn, gần nhất trước, tối đa [UPCOMING_LIMIT]; rỗng = không có. */
        val upcomingItems: List<Upcoming> = emptyList(),
        /** Số dư dự kiến từng ngày tới cuối tháng (lấy mẫu tối đa [SERIES_POINTS] điểm) để vẽ đường biểu đồ nhỏ. */
        val forecastSeries: List<Long> = emptyList(),
        /** "high" | "medium" | "low" từ `/forecast/cashflow`; rỗng = không rõ. */
        val forecastConfidence: String = "",
    ) {
        /** Báo đỏ khi tháng đã vượt mức hoặc riêng hôm nay đã chi quá mức an toàn (xem [DailySafeSpend.over]). */
        val over: Boolean get() = hasBudget && (overMonth || percentUsed >= 100f)
    }

    fun read(context: Context): Data? {
        val prefs = context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
        val lastSync = prefs.getLong(KEY_LAST_SYNC_AT, 0L)
        if (lastSync == 0L) return null // chưa đồng bộ lần nào
        return Data(
            balanceCents = prefs.getLong(KEY_BALANCE_CENTS, 0L),
            forecastEndBalanceCents = prefs.getLong(KEY_FORECAST_END_BALANCE_CENTS, 0L),
            transactionsTodayCount = prefs.getInt(KEY_TRANSACTIONS_TODAY_COUNT, 0),
            accountLabel = prefs.getString(KEY_ACCOUNT_LABEL, null) ?: "Tất cả tài khoản",
            lastSyncAtMillis = lastSync,
            syncError = prefs.getBoolean(KEY_SYNC_ERROR, false),
            percentUsed = prefs.getFloat(KEY_PERCENT_USED, 0f),
            hasBudget = prefs.getBoolean(KEY_HAS_BUDGET, false),
            spentCents = prefs.getLong(KEY_SPENT_CENTS, 0L),
            incomeCents = prefs.getLong(KEY_INCOME_CENTS, 0L),
            recentTransactions = readRecentTransactions(prefs),
            spentTodayCents = prefs.getLong(KEY_SPENT_TODAY_CENTS, 0L),
            safeTodayCents = prefs.getLong(KEY_SAFE_TODAY_CENTS, 0L),
            overMonth = prefs.getBoolean(KEY_OVER_MONTH, false),
            monthOverCents = prefs.getLong(KEY_MONTH_OVER_CENTS, 0L),
            upcomingItems = readUpcoming(prefs),
            forecastSeries = (prefs.getString(KEY_FORECAST_SERIES, "") ?: "").split(",").mapNotNull { it.toLongOrNull() },
            forecastConfidence = prefs.getString(KEY_FORECAST_CONFIDENCE, "") ?: "",
        )
    }

    private fun readRecentTransactions(prefs: android.content.SharedPreferences): List<RecentTxn> {
        val raw = prefs.getString(KEY_RECENT_TRANSACTIONS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                RecentTxn(
                    description = o.optString("description"),
                    categoryLabel = o.optString("categoryLabel"),
                    timeMillis = o.optLong("timeMillis"),
                    amountCents = o.optLong("amountCents"),
                    isIncome = o.optBoolean("isIncome"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun writeRecentTransactions(data: List<RecentTxn>): String {
        val arr = JSONArray()
        data.forEach { txn ->
            arr.put(
                JSONObject()
                    .put("description", txn.description)
                    .put("categoryLabel", txn.categoryLabel)
                    .put("timeMillis", txn.timeMillis)
                    .put("amountCents", txn.amountCents)
                    .put("isIncome", txn.isIncome),
            )
        }
        return arr.toString()
    }

    fun write(context: Context, data: Data) {
        context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE).edit()
            .putLong(KEY_BALANCE_CENTS, data.balanceCents)
            .putLong(KEY_FORECAST_END_BALANCE_CENTS, data.forecastEndBalanceCents)
            .putInt(KEY_TRANSACTIONS_TODAY_COUNT, data.transactionsTodayCount)
            .putString(KEY_ACCOUNT_LABEL, data.accountLabel)
            .putLong(KEY_LAST_SYNC_AT, data.lastSyncAtMillis)
            .putBoolean(KEY_SYNC_ERROR, false)
            .putFloat(KEY_PERCENT_USED, data.percentUsed)
            .putBoolean(KEY_HAS_BUDGET, data.hasBudget)
            .putLong(KEY_SPENT_CENTS, data.spentCents)
            .putLong(KEY_INCOME_CENTS, data.incomeCents)
            .putString(KEY_RECENT_TRANSACTIONS, writeRecentTransactions(data.recentTransactions))
            .putLong(KEY_SPENT_TODAY_CENTS, data.spentTodayCents)
            .putLong(KEY_SAFE_TODAY_CENTS, data.safeTodayCents)
            .putBoolean(KEY_OVER_MONTH, data.overMonth)
            .putLong(KEY_MONTH_OVER_CENTS, data.monthOverCents)
            .putString(KEY_UPCOMING_LIST, writeUpcoming(data.upcomingItems))
            .putString(KEY_FORECAST_SERIES, data.forecastSeries.joinToString(","))
            .putString(KEY_FORECAST_CONFIDENCE, data.forecastConfidence)
            .commit()
    }

    /** Giữ nguyên số liệu cũ, chỉ đánh dấu cờ lỗi — cùng cách W1/W2 xử lý mất mạng/BE lỗi. */
    fun markSyncError(context: Context) {
        val prefs = context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
        if (prefs.getLong(KEY_LAST_SYNC_AT, 0L) == 0L) return
        prefs.edit().putBoolean(KEY_SYNC_ERROR, true).commit()
    }
}

/** Gọi GET /api/v1/financial-accounts (số dư) + GET /api/v1/forecast/cashflow (dự báo cuối tháng,
 * field `endBalanceCents`) + GET /api/v1/transactions (đếm giao dịch hôm nay, lọc fromDate/toDate) +
 * GET /api/v1/me/spendable (% ngân sách tháng đã dùng, cùng công thức W1) cho widget 4×4 — cùng cơ
 * chế phiên/token native với SafeSpendSync/OverviewSync, không qua Flutter engine nên chạy được cả
 * khi app đã bị kill. */
object DetailSync {
    private const val TIMEOUT_MS = 15_000
    private const val RECENT_LIMIT = 4

    /** true = đã đồng bộ thành công (hoặc không có phiên đăng nhập, không tính là lỗi). suspend vì
     * [readSourceAccountId] gọi `GlanceAppWidgetManager.getGlanceIds` (suspend), luôn được gọi từ
     * [DetailRefreshWorker.doWork] — đã ở trong 1 coroutine sẵn. */
    suspend fun refresh(context: Context): Boolean {
        val runtime = NotificationRuntime.get(context)
        val store = runtime.store
        val baseUrl = store.baseUrl
        var token = store.accessToken
        if (baseUrl.isNullOrEmpty() || token.isNullOrEmpty()) return true // chưa đăng nhập: không phải lỗi

        return try {
            val sourceAccountId = readSourceAccountId(context)
            var accounts = fetchJson(baseUrl, token, "/api/v1/financial-accounts")
            var forecast = fetchJson(baseUrl, token, forecastPath(sourceAccountId))
            var transactions = fetchJson(baseUrl, token, recentTransactionsPath(sourceAccountId))
            // /me/spendable không nhận query param nào (không có accountId) — xem MyFinanceController,
            // cùng cách SafeSpendSync/OverviewSync đang gọi, nên KHÔNG truyền sourceAccountId ở đây
            // dù 3 call còn lại có lọc theo nó.
            var spendable = fetchJson(baseUrl, token, "/api/v1/me/spendable")
            if (accounts is FetchResult.Unauthorized || forecast is FetchResult.Unauthorized ||
                transactions is FetchResult.Unauthorized || spendable is FetchResult.Unauthorized
            ) {
                when (val r = runtime.refresher.refresh(token)) {
                    is RefreshResult.Ok -> {
                        token = r.accessToken
                        accounts = fetchJson(baseUrl, token, "/api/v1/financial-accounts")
                        forecast = fetchJson(baseUrl, token, forecastPath(sourceAccountId))
                        transactions = fetchJson(baseUrl, token, recentTransactionsPath(sourceAccountId))
                        spendable = fetchJson(baseUrl, token, "/api/v1/me/spendable")
                    }
                    else -> { /* giữ nguyên kết quả 401 cũ, rơi vào nhánh lỗi bên dưới */ }
                }
            }
            if (accounts is FetchResult.Ok && forecast is FetchResult.Ok && transactions is FetchResult.Ok && spendable is FetchResult.Ok) {
                // Khoản sắp đến hạn chỉ là phần thêm: lỗi ở đây không được làm hỏng cả widget.
                val recurring = try { fetchJson(baseUrl, token, "/api/v1/recurring-items?status=Active") } catch (e: Exception) { FetchResult.Failed }
                DetailPrefs.write(
                    context,
                    computeFrom(
                        accounts = accounts.body as JSONArray,
                        forecast = forecast.body as JSONObject,
                        transactions = transactions.body as JSONArray,
                        spendable = spendable.body as JSONObject,
                        sourceAccountId = sourceAccountId,
                        upcoming = (recurring as? FetchResult.Ok)?.body?.let { nextUpcoming(it as? JSONArray) } ?: emptyList(),
                    ),
                )
                true
            } else {
                DetailPrefs.markSyncError(context)
                false
            }
        } catch (e: Exception) {
            DetailPrefs.markSyncError(context)
            false
        }
    }

    /// Nguồn tiền hiển thị đã chọn trong màn cấu hình (sourceAccountId_$widgetId, ghi bởi
    /// WidgetConfigBridge) — đọc theo instance DetailWidget đầu tiên đang ghim, cùng cách đơn giản
    /// hoá mà OverviewSync đang dùng (getPinnedWidgetIds().first).
    private suspend fun readSourceAccountId(context: Context): String? {
        return try {
            val manager = GlanceAppWidgetManager(context)
            val ids = manager.getGlanceIds(DetailWidget::class.java)
            if (ids.isEmpty()) return null
            val widgetId = manager.getAppWidgetId(ids.first())
            val raw = context.getSharedPreferences(SafeSpendPrefs.FILE, Context.MODE_PRIVATE)
                .getString("sourceAccountId_$widgetId", null)
            raw?.takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            null
        }
    }

    private fun forecastPath(sourceAccountId: String?): String =
        if (sourceAccountId != null) "/api/v1/forecast/cashflow?accountId=$sourceAccountId" else "/api/v1/forecast/cashflow"

    /// Vài giao dịch GẦN NHẤT, không giới hạn ngày: trước đây chỉ lấy của hôm nay nên nửa dưới widget trống hầu hết thời gian
    /// trong ngày. Danh sách trả về sắp xếp mới nhất trước.
    private fun recentTransactionsPath(sourceAccountId: String?): String {
        val accountParam = if (sourceAccountId != null) "&accountId=$sourceAccountId" else ""
        return "/api/v1/transactions?limit=$RECENT_LIMIT$accountParam"
    }

    /// Số dư dự kiến từng ngày, lấy mẫu đều để còn tối đa [DetailPrefs.SERIES_POINTS] điểm (luôn giữ điểm cuối).
    private fun forecastSeries(days: JSONArray?): List<Long> {
        if (days == null || days.length() == 0) return emptyList()
        val all = (0 until days.length()).map { days.getJSONObject(it).optLong("expectedBalanceCents", 0L) }
        if (all.size <= DetailPrefs.SERIES_POINTS) return all
        val step = (all.size - 1).toDouble() / (DetailPrefs.SERIES_POINTS - 1)
        return (0 until DetailPrefs.SERIES_POINTS).map { all[Math.round(it * step).toInt()] }
    }

    /// Khoản định kỳ đang hoạt động, loại CHI (Outflow), có hạn từ hôm nay trở đi: gần nhất trước, lấy tối đa [DetailPrefs.UPCOMING_LIMIT].
    private fun nextUpcoming(items: JSONArray?): List<DetailPrefs.Upcoming> {
        if (items == null) return emptyList()
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(java.util.Date())
        val found = ArrayList<DetailPrefs.Upcoming>()
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            if (!o.optString("direction").equals("Outflow", ignoreCase = true)) continue
            val due = o.optString("nextDueDate")
            if (due.length < 10 || due.substring(0, 10) < today) continue
            found.add(DetailPrefs.Upcoming(o.optString("name"), o.optLong("amountCents", 0L), due.substring(0, 10)))
        }
        return found.sortedBy { it.dueDate }.take(DetailPrefs.UPCOMING_LIMIT)
    }

    private sealed interface FetchResult {
        data class Ok(val body: Any) : FetchResult
        object Unauthorized : FetchResult
        object Failed : FetchResult
    }

    private fun fetchJson(baseUrl: String, token: String, pathAndQuery: String): FetchResult {
        val conn = URL(baseUrl.trimEnd('/') + pathAndQuery).openConnection() as HttpURLConnection
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

    /// Số dư = tổng balanceCents các tài khoản (lọc theo [sourceAccountId] nếu đã chọn 1 tài khoản cụ
    /// thể, null = tất cả) — cùng công thức OverviewSync.computeFrom. Dự báo cuối tháng = thẳng
    /// `forecast.endBalanceCents`. Số giao dịch hôm nay = độ dài mảng transactions trả về. percentUsed/
    /// hasBudget/spentCents/incomeCents = y hệt công thức SafeSpendSync.computeFrom (spent/income*100,
    /// 0 nếu chưa biết thu nhập; hasBudget = đã có spendableCents).
    private fun computeFrom(
        accounts: JSONArray,
        forecast: JSONObject,
        transactions: JSONArray,
        spendable: JSONObject,
        sourceAccountId: String?,
        upcoming: List<DetailPrefs.Upcoming>,
    ): DetailPrefs.Data {
        var balanceCents = 0L
        var accountLabel = "Tất cả tài khoản"
        for (i in 0 until accounts.length()) {
            val account = accounts.getJSONObject(i)
            val id = account.optString("id")
            if (sourceAccountId != null && id != sourceAccountId) continue
            balanceCents += account.optLong("balanceCents", 0L)
            if (sourceAccountId != null) accountLabel = account.optString("accountName", accountLabel)
        }

        // Cùng công thức với Trang chủ và W1/W2 (xem [DailySafeSpend]): mức an toàn hôm nay do server tính, vòng tròn = đã chi hôm nay ÷ mức đó.
        val daily = DailySafeSpend.from(spendable)
        val incomeCents = spendable.optLong("incomeCents", Long.MIN_VALUE)
            .takeIf { !spendable.isNull("incomeCents") && it != Long.MIN_VALUE }
        val spentCents = spendable.optLong("spentCents", 0L)

        return DetailPrefs.Data(
            balanceCents = balanceCents,
            forecastEndBalanceCents = forecast.optLong("endBalanceCents", 0L),
            transactionsTodayCount = transactions.length(),
            accountLabel = accountLabel,
            lastSyncAtMillis = System.currentTimeMillis(),
            syncError = false,
            percentUsed = daily.percentUsed,
            hasBudget = daily.hasBudget,
            spentCents = spentCents,
            incomeCents = incomeCents ?: 0L,
            recentTransactions = extractRecentTransactions(transactions, accounts),
            spentTodayCents = daily.spentTodayCents,
            safeTodayCents = daily.safeTodayCents,
            overMonth = daily.overMonth,
            monthOverCents = daily.monthOverCents,
            upcomingItems = upcoming,
            forecastSeries = forecastSeries(forecast.optJSONArray("days")),
            forecastConfidence = forecast.optString("confidence", ""),
        )
    }

    /// `GET /transactions` đã trả về sắp xếp mới nhất trước (`OrderByDescending(TransactedAt)
    /// .ThenByDescending(CreatedAt)` — xem TransactionsController.GetList), nên chỉ cần lấy N phần tử
    /// đầu, không cần tự sort lại. Giới hạn 4 (trước là 2, lúc đó tưởng là nguyên nhân tràn khung —
    /// nguyên nhân thật là Column vượt quá 10 phần tử con, đã sửa bằng cách tách section riêng trong
    /// DetailWidget.kt; giờ RecentTransactionsSection có Column CON riêng của nó nên thoải mái hơn
    /// nhiều so với giới hạn 10 chung trước đây — 4 dòng vẫn còn dư margin). Field name khớp
    /// `TransactionDto`/`transaction_entity.dart`: description/categoryName/merchantName/
    /// financialAccountId/transactedAt/amountCents/transactionType ("Credit" = thu nhập, còn lại coi
    /// là chi tiêu khi tô màu +/-). Tên hiển thị ưu tiên: description → merchantName → tên ví
    /// (financialAccountId tra trong [accounts]) → categoryName → "Giao dịch" — KHÔNG dùng optString
    /// trần vì nó trả literal "null" (không rỗng) khi field là JSON null thật sự, xem optStringOrNull.
    private fun extractRecentTransactions(transactions: JSONArray, accounts: JSONArray): List<DetailPrefs.RecentTxn> {
        val count = minOf(4, transactions.length())
        return (0 until count).map { i ->
            val t = transactions.getJSONObject(i)
            val description = t.optStringOrNull("description")
                ?: t.optStringOrNull("merchantName")
                ?: resolveAccountName(t.optString("financialAccountId"), accounts)
                ?: t.optStringOrNull("categoryName")
                ?: "Giao dịch"
            DetailPrefs.RecentTxn(
                description = description,
                categoryLabel = t.optStringOrNull("categoryName") ?: "Khác",
                timeMillis = parseIso8601(t.optString("transactedAt")),
                amountCents = t.optLong("amountCents", 0L),
                isIncome = t.optString("transactionType").equals("Credit", ignoreCase = true),
            )
        }
    }

    /// `optString(key)` của org.json trả literal `"null"` (không rỗng/blank) khi value là JSON null
    /// thật sự, không phải field vắng mặt — phải tự chặn bằng `isNull` trước, nếu không "null" sẽ lọt
    /// qua `.ifBlank{}` và hiện thẳng ra UI (đã xảy ra thật với `description: null`).
    private fun JSONObject.optStringOrNull(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }

    /// Tên ví hiển thị khi giao dịch không có description/merchantName — tra cùng cách computeFrom()
    /// đang lọc theo sourceAccountId (so khớp `account.optString("id")`).
    private fun resolveAccountName(financialAccountId: String, accounts: JSONArray): String? {
        if (financialAccountId.isEmpty()) return null
        for (i in 0 until accounts.length()) {
            val account = accounts.getJSONObject(i)
            if (account.optString("id") == financialAccountId) {
                return account.optStringOrNull("accountName")
            }
        }
        return null
    }

    /// `transactedAt` là DateTimeOffset ISO 8601 ("...Z" hoặc "...+07:00"), có thể kèm phần giây
    /// thập phân — bỏ phần thập phân rồi parse bằng đúng pattern "XXX" đã dùng để GỬI ngày tháng ở
    /// [transactionsTodayPath] (giữ nguyên offset, không tự quy UTC sai).
    private fun parseIso8601(raw: String): Long {
        if (raw.isEmpty()) return System.currentTimeMillis()
        return try {
            val cleaned = raw.replace(Regex("\\.\\d+"), "")
            val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)
            fmt.parse(cleaned)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
    }
}

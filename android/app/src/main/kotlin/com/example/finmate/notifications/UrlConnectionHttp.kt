package com.example.finmate.notifications

import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONObject

private const val TIMEOUT_MS = 15_000

/**
 * POST JSON, trả về mã HTTP và (tùy chọn) thân phản hồi. Ném exception khi lỗi mạng trước khi có mã HTTP; hai lớp bên dưới bắt hết.
 * Đọc thân 2xx lỗi/quá hạn thì trả null thay vì ném: BE có thể đã xử lý xong (vd. xoay refresh token), người gọi cần biết mã.
 * Không log URL, thân yêu cầu hay token.
 */
private fun postJson(url: String, body: JSONObject, bearer: String?, readBody: Boolean): Pair<Int, String?> {
    val conn = URL(url).openConnection() as HttpURLConnection
    try {
        conn.requestMethod = "POST"
        conn.connectTimeout = TIMEOUT_MS
        conn.readTimeout = TIMEOUT_MS
        conn.instanceFollowRedirects = false
        conn.doOutput = true
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("ngrok-skip-browser-warning", "true")
        if (bearer != null) conn.setRequestProperty("Authorization", "Bearer $bearer")
        conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
        val code = conn.responseCode
        val text = if (readBody && code in 200..299) {
            try {
                conn.inputStream.bufferedReader().use { it.readText() }
            } catch (e: Exception) {
                null
            }
        } else null
        return code to text
    } finally {
        conn.disconnect()
    }
}

private fun joinUrl(baseUrl: String, path: String) = baseUrl.trimEnd('/') + path

/**
 * 404 (trang endpoint-offline của ngrok), 429 và 502..504 nghĩa là tunnel/BE đang tắt: giữ mục và dừng lượt xả,
 * KHÔNG tính lần thử, nếu không một đêm BE tắt sẽ làm rụng cả hàng đợi. 500 vẫn là Retryable (có giới hạn lần thử).
 */
internal fun mapAnalyzeStatus(code: Int): AnalyzeOutcome = when {
    code in 200..299 -> AnalyzeOutcome.Success
    code == 401 -> AnalyzeOutcome.Unauthorized
    code == 404 || code == 429 || code in 502..504 -> AnalyzeOutcome.NetworkError
    code in 500..599 -> AnalyzeOutcome.Retryable
    code in 400..499 -> AnalyzeOutcome.Rejected
    else -> AnalyzeOutcome.Retryable // 1xx/3xx bất thường: thử lại có giới hạn thay vì bỏ mất thông báo
}

/**
 * 2xx mà thân thiếu/hỏng nghĩa là BE đã xoay refresh token nhưng ta không nhận được cặp mới: token đang giữ đã bị thu hồi,
 * dùng lại sẽ khiến BE thu hồi mọi phiên trên mọi thiết bị -> Rejected để chỉ máy này đăng xuất.
 */
internal fun interpretRefreshResponse(code: Int, text: String?): RefreshHttpResult = when {
    code in 200..299 -> try {
        val data = JSONObject(text ?: throw IllegalStateException()).getJSONObject("data")
        RefreshHttpResult.Ok(data.getString("accessToken"), data.getString("refreshToken"))
    } catch (e: Exception) {
        RefreshHttpResult.Rejected
    }
    code == 400 || code == 401 || code == 403 -> RefreshHttpResult.Rejected
    else -> RefreshHttpResult.NetworkError
}

/** Mọi exception (IOException, URL sai, lỗi parse...) -> NetworkError; không bao giờ ném ra ngoài. */
class UrlConnectionAnalyzeHttp : AnalyzeHttp {
    override fun post(baseUrl: String, accessToken: String, item: QueuedNotification): AnalyzeOutcome = try {
        // SimpleDateFormat không thread-safe nên tạo mới mỗi lần; receivedAt lấy từ lúc bắt thông báo để gửi lại không đổi hash.
        val receivedAt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }
            .format(Date(item.receivedAtMs))
        val body = JSONObject()
            .put("packageName", item.packageName)
            .put("notificationTitle", item.title)
            .put("notificationBody", item.body)
            .put("receivedAt", receivedAt)
        val (code, _) = postJson(joinUrl(baseUrl, "/api/v1/notifications/analyze"), body, accessToken, readBody = false)
        mapAnalyzeStatus(code)
    } catch (e: Exception) {
        AnalyzeOutcome.NetworkError
    }
}

class UrlConnectionRefreshHttp : RefreshHttp {
    override fun refresh(baseUrl: String, refreshToken: String): RefreshHttpResult = try {
        val (code, text) = postJson(
            joinUrl(baseUrl, "/api/v1/auth/refresh"),
            JSONObject().put("refreshToken", refreshToken), bearer = null, readBody = true,
        )
        interpretRefreshResponse(code, text)
    } catch (e: Exception) {
        RefreshHttpResult.NetworkError
    }
}

package com.example.finmate.notifications

sealed interface RefreshHttpResult {
    data class Ok(val accessToken: String, val refreshToken: String) : RefreshHttpResult
    object Rejected : RefreshHttpResult      // 400/401/403
    object NetworkError : RefreshHttpResult  // mạng/5xx
}

fun interface RefreshHttp {
    fun refresh(baseUrl: String, refreshToken: String): RefreshHttpResult
}

sealed interface RefreshResult {
    data class Ok(val accessToken: String) : RefreshResult
    object Expired : RefreshResult
    object Network : RefreshResult
}

class TokenRefresher(private val store: SessionStore, private val http: RefreshHttp) {
    // Backend xoay refresh token và thu hồi cả phiên nếu một token bị dùng hai lần,
    // nên mọi lần làm mới trong tiến trình phải đi qua cùng một khóa.
    private val lock = Any()

    // Khóa ngắn (KHÔNG BAO GIỜ giữ khi gọi http) bảo vệ việc ghi phiên: setSession/clearSession và bước ghi kết quả refresh.
    // Thứ tự khóa: (rt | lock) -> writeLock, writeLock luôn ở trong cùng nên không có vòng.
    val writeLock = Any()

    /** [staleAccessToken] == null: luôn làm mới, không so sánh token. */
    fun refresh(staleAccessToken: String?): RefreshResult = synchronized(lock) {
        // Luồng khác đã xoay token trong lúc ta chờ khóa -> dùng lại token mới, không gọi http.
        val current = store.accessToken
        if (staleAccessToken != null && current != null && current != staleAccessToken) {
            return RefreshResult.Ok(current)
        }
        val refreshToken: String?
        val baseUrl: String?
        synchronized(writeLock) { refreshToken = store.refreshToken; baseUrl = store.baseUrl }
        if (refreshToken == null || baseUrl == null) return RefreshResult.Expired
        val res = http.refresh(baseUrl, refreshToken)
        synchronized(writeLock) {
            // Đăng xuất / đăng nhập tài khoản khác trong lúc chờ http: bỏ kết quả, không đụng vào kho.
            // Trả Network (không phải Expired) để sender không xóa hàng đợi của phiên mới.
            if (store.refreshToken != refreshToken || store.baseUrl != baseUrl) return RefreshResult.Network
            when (res) {
                is RefreshHttpResult.Ok -> {
                    store.saveTokens(res.accessToken, res.refreshToken)
                    RefreshResult.Ok(res.accessToken)
                }
                RefreshHttpResult.Rejected -> {
                    store.clearTokens()
                    store.sessionExpired = true
                    RefreshResult.Expired
                }
                RefreshHttpResult.NetworkError -> RefreshResult.Network
            }
        }
    }
}

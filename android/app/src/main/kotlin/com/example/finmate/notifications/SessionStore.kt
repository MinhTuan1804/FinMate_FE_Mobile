package com.example.finmate.notifications

interface SessionStore {
    var baseUrl: String?
    var accessToken: String?
    var refreshToken: String?
    var sessionExpired: Boolean

    /** Xóa access + refresh token. */
    fun clearTokens()

    /**
     * Lưu cặp token mới. Backend xoay refresh token nên hai khóa phải được ghi cùng lúc:
     * nếu chỉ ghi được một nửa rồi app bị kill, lần sau sẽ dùng refresh token đã bị thu hồi.
     * Bản mặc định ghi tuần tự; kho thật override để ghi nguyên tử.
     */
    fun saveTokens(accessToken: String, refreshToken: String) {
        this.accessToken = accessToken
        this.refreshToken = refreshToken
    }
}

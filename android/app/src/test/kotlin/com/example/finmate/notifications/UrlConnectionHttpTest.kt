package com.example.finmate.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class UrlConnectionHttpTest {
    @Test fun mapAnalyzeStatus_table() {
        val expected = mapOf(
            200 to AnalyzeOutcome.Success,
            201 to AnalyzeOutcome.Success,
            204 to AnalyzeOutcome.Success,
            301 to AnalyzeOutcome.Retryable,
            401 to AnalyzeOutcome.Unauthorized,
            // Tunnel/BE tắt: 404 của trang endpoint-offline (ngrok), 429, 502..504 -> giữ mục, không tính lần thử.
            404 to AnalyzeOutcome.NetworkError,
            429 to AnalyzeOutcome.NetworkError,
            502 to AnalyzeOutcome.NetworkError,
            503 to AnalyzeOutcome.NetworkError,
            504 to AnalyzeOutcome.NetworkError,
            400 to AnalyzeOutcome.Rejected,
            409 to AnalyzeOutcome.Rejected,
            422 to AnalyzeOutcome.Rejected,
            500 to AnalyzeOutcome.Retryable,
        )
        expected.forEach { (code, outcome) -> assertEquals("status $code", outcome, mapAnalyzeStatus(code)) }
    }

    @Test fun refresh_2xx_valid_body_is_ok() {
        val body = """{"data":{"accessToken":"a","refreshToken":"r"}}"""
        assertEquals(RefreshHttpResult.Ok("a", "r"), interpretRefreshResponse(200, body))
    }

    // BE đã xoay token mà ta không đọc được phản hồi: token cũ đã bị thu hồi, coi là Rejected để chỉ máy này đăng xuất.
    @Test fun refresh_2xx_null_body_is_rejected() {
        assertEquals(RefreshHttpResult.Rejected, interpretRefreshResponse(200, null))
    }

    @Test fun refresh_2xx_malformed_or_incomplete_body_is_rejected() {
        assertEquals(RefreshHttpResult.Rejected, interpretRefreshResponse(200, "not json"))
        assertEquals(RefreshHttpResult.Rejected, interpretRefreshResponse(200, """{"data":{"accessToken":"a"}}"""))
    }

    @Test fun refresh_non_2xx() {
        assertEquals(RefreshHttpResult.Rejected, interpretRefreshResponse(401, null))
        assertEquals(RefreshHttpResult.Rejected, interpretRefreshResponse(400, null))
        assertEquals(RefreshHttpResult.Rejected, interpretRefreshResponse(403, null))
        assertEquals(RefreshHttpResult.NetworkError, interpretRefreshResponse(500, null))
        assertEquals(RefreshHttpResult.NetworkError, interpretRefreshResponse(503, null))
    }
}

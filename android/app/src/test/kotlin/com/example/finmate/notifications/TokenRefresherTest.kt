package com.example.finmate.notifications

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeSessionStore(
    override var baseUrl: String? = "https://api.test",
    override var accessToken: String? = "old-access",
    override var refreshToken: String? = "old-refresh",
    override var sessionExpired: Boolean = false,
) : SessionStore {
    var saveTokensCalls = 0

    override fun clearTokens() {
        accessToken = null
        refreshToken = null
    }

    override fun saveTokens(accessToken: String, refreshToken: String) {
        saveTokensCalls++
        super.saveTokens(accessToken, refreshToken)
    }
}

private class CountingHttp(
    private val result: RefreshHttpResult,
    private val delayMs: Long = 0,
) : RefreshHttp {
    val calls = AtomicInteger(0)
    @Volatile var lastRefreshToken: String? = null

    override fun refresh(baseUrl: String, refreshToken: String): RefreshHttpResult {
        calls.incrementAndGet()
        lastRefreshToken = refreshToken
        if (delayMs > 0) Thread.sleep(delayMs)
        return result
    }
}

class TokenRefresherTest {
    private val ok = RefreshHttpResult.Ok("new-access", "new-refresh")

    @Test fun success_saves_new_pair_and_returns_ok() {
        val store = FakeSessionStore()
        val http = CountingHttp(ok)
        val r = TokenRefresher(store, http).refresh("old-access")
        assertEquals(RefreshResult.Ok("new-access"), r)
        assertEquals("new-access", store.accessToken)
        assertEquals("new-refresh", store.refreshToken)
        assertEquals("old-refresh", http.lastRefreshToken)
        assertFalse(store.sessionExpired)
    }

    @Test fun success_writes_pair_through_single_saveTokens_call() {
        val store = FakeSessionStore()
        TokenRefresher(store, CountingHttp(ok)).refresh("old-access")
        assertEquals(1, store.saveTokensCalls)
    }

    @Test fun token_already_changed_returns_current_without_http() {
        val store = FakeSessionStore(accessToken = "rotated")
        val http = CountingHttp(ok)
        val r = TokenRefresher(store, http).refresh("old-access")
        assertEquals(RefreshResult.Ok("rotated"), r)
        assertEquals(0, http.calls.get())
    }

    @Test fun two_threads_same_stale_token_call_http_once() {
        val store = FakeSessionStore()
        // Độ trễ để luồng thứ hai chắc chắn phải chờ khóa trong lúc luồng đầu đang gọi http.
        val http = CountingHttp(ok, delayMs = 200)
        val refresher = TokenRefresher(store, http)
        val start = CountDownLatch(1)
        val done = CountDownLatch(2)
        val results = arrayOfNulls<RefreshResult>(2)
        repeat(2) { i ->
            Thread {
                start.await()
                results[i] = refresher.refresh("old-access")
                done.countDown()
            }.start()
        }
        start.countDown()
        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertEquals(1, http.calls.get())
        assertEquals(RefreshResult.Ok("new-access"), results[0])
        assertEquals(RefreshResult.Ok("new-access"), results[1])
    }

    @Test fun rejected_clears_tokens_and_sets_expired() {
        val store = FakeSessionStore()
        val r = TokenRefresher(store, CountingHttp(RefreshHttpResult.Rejected)).refresh("old-access")
        assertEquals(RefreshResult.Expired, r)
        assertNull(store.accessToken)
        assertNull(store.refreshToken)
        assertTrue(store.sessionExpired)
    }

    @Test fun network_error_keeps_tokens_and_returns_network() {
        val store = FakeSessionStore()
        val r = TokenRefresher(store, CountingHttp(RefreshHttpResult.NetworkError)).refresh("old-access")
        assertEquals(RefreshResult.Network, r)
        assertEquals("old-access", store.accessToken)
        assertEquals("old-refresh", store.refreshToken)
        assertFalse(store.sessionExpired)
    }

    @Test fun missing_refresh_token_returns_expired() {
        val store = FakeSessionStore(refreshToken = null)
        val http = CountingHttp(ok)
        assertEquals(RefreshResult.Expired, TokenRefresher(store, http).refresh("old-access"))
        assertEquals(0, http.calls.get())
    }

    // Đăng xuất / đổi tài khoản trong lúc http đang chạy: kết quả refresh cũ không được đụng vào kho.
    private fun refreshWithSessionChange(
        result: RefreshHttpResult,
        change: (FakeSessionStore) -> Unit,
    ): Pair<FakeSessionStore, RefreshResult> {
        val store = FakeSessionStore()
        val http = RefreshHttp { _, _ -> change(store); result }
        return store to TokenRefresher(store, http).refresh("old-access")
    }

    private fun loginAsB(s: FakeSessionStore) {
        s.clearTokens()
        s.baseUrl = "https://b.test"
        s.saveTokens("b-access", "b-refresh")
    }

    @Test fun ok_after_logout_during_http_keeps_store_empty_and_returns_network() {
        val (store, r) = refreshWithSessionChange(ok) { it.clearTokens() }
        assertEquals(RefreshResult.Network, r)
        assertNull(store.accessToken)
        assertNull(store.refreshToken)
    }

    @Test fun ok_after_new_login_during_http_keeps_b_tokens_and_returns_network() {
        val (store, r) = refreshWithSessionChange(ok, ::loginAsB)
        assertEquals(RefreshResult.Network, r)
        assertEquals("b-access", store.accessToken)
        assertEquals("b-refresh", store.refreshToken)
        assertEquals("https://b.test", store.baseUrl)
    }

    @Test fun rejected_after_new_login_during_http_keeps_b_tokens_and_expired_flag_false() {
        val (store, r) = refreshWithSessionChange(RefreshHttpResult.Rejected, ::loginAsB)
        assertEquals(RefreshResult.Network, r)
        assertEquals("b-access", store.accessToken)
        assertEquals("b-refresh", store.refreshToken)
        assertFalse(store.sessionExpired)
    }

    @Test fun null_stale_token_always_refreshes() {
        val store = FakeSessionStore()
        val http = CountingHttp(ok)
        val r = TokenRefresher(store, http).refresh(null)
        assertEquals(RefreshResult.Ok("new-access"), r)
        assertEquals(1, http.calls.get())
    }
}

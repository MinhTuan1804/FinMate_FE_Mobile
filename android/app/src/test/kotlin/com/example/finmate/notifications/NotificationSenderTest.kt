package com.example.finmate.notifications

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

private class SenderFakeStore(
    override var baseUrl: String? = "https://api.test",
    override var accessToken: String? = "old-access",
    override var refreshToken: String? = "old-refresh",
    override var sessionExpired: Boolean = false,
) : SessionStore {
    override fun clearTokens() {
        accessToken = null
        refreshToken = null
    }
}

private class SenderFakeRefreshHttp(private val result: RefreshHttpResult) : RefreshHttp {
    var calls = 0
    override fun refresh(baseUrl: String, refreshToken: String): RefreshHttpResult {
        calls++
        return result
    }
}

/** Trả lần lượt các outcome theo kịch bản; ghi lại (id, token) của mỗi lần gọi. */
private class ScriptedHttp(private val script: (String, String) -> AnalyzeOutcome) : AnalyzeHttp {
    val calls = mutableListOf<Pair<String, String>>()
    override fun post(baseUrl: String, accessToken: String, item: QueuedNotification): AnalyzeOutcome {
        calls += item.id to accessToken
        return script(item.id, accessToken)
    }
}

class NotificationSenderTest {
    @get:Rule val tmp = TemporaryFolder()

    private fun queueOf(vararg ids: String): NotificationQueue {
        val q = NotificationQueue(File(tmp.root, "q-${System.nanoTime()}.json"))
        ids.forEachIndexed { i, id -> q.add(QueuedNotification(id, "pkg", "t", "b", i.toLong())) }
        return q
    }

    private fun sender(
        q: NotificationQueue,
        store: SenderFakeStore,
        http: AnalyzeHttp,
        refreshHttp: SenderFakeRefreshHttp = SenderFakeRefreshHttp(RefreshHttpResult.NetworkError),
        maxAttempts: Int = 5,
    ) = NotificationSender(q, store, TokenRefresher(store, refreshHttp), http, maxAttempts)

    private fun ids(q: NotificationQueue) = q.all().map { it.id }

    @Test fun success_removes_item() {
        val q = queueOf("a")
        sender(q, SenderFakeStore(), ScriptedHttp { _, _ -> AnalyzeOutcome.Success }).drain()
        assertTrue(q.all().isEmpty())
    }

    @Test fun item_removed_from_queue_during_drain_is_not_posted() {
        val q = queueOf("a", "b", "c")
        // Đang gửi "a" thì "b" bị xóa (vd. đăng xuất rồi đăng nhập lại).
        val http = ScriptedHttp { id, _ ->
            if (id == "a") q.remove("b")
            AnalyzeOutcome.Success
        }
        sender(q, SenderFakeStore(), http).drain()
        assertEquals(listOf("a", "c"), http.calls.map { it.first })
    }

    @Test fun clear_during_drain_stops_posting_remaining_snapshot_items() {
        val q = queueOf("a", "b", "c")
        val store = SenderFakeStore()
        val http = ScriptedHttp { _, _ ->
            // Đăng xuất xóa hàng đợi, rồi tài khoản B đăng nhập với token khác.
            q.clear()
            store.accessToken = "token-of-B"
            AnalyzeOutcome.Success
        }
        sender(q, store, http).drain()
        assertEquals(listOf("a" to "old-access"), http.calls)
    }

    @Test fun item_cleared_while_refreshing_is_not_resent_with_other_sessions_token() {
        val q = queueOf("a")
        val store = SenderFakeStore()
        val http = ScriptedHttp { _, token ->
            if (token == "old-access") {
                // 401 của A; trong lúc đó A đăng xuất và B đăng nhập nên refresh sẽ thấy token đã đổi và trả token của B.
                q.clear()
                store.accessToken = "token-of-B"
                AnalyzeOutcome.Unauthorized
            } else AnalyzeOutcome.Success
        }
        sender(q, store, http).drain()
        assertEquals(listOf("a" to "old-access"), http.calls)
    }

    @Test fun no_session_does_not_send_and_keeps_queue() {
        for (store in listOf(SenderFakeStore(baseUrl = null), SenderFakeStore(accessToken = null))) {
            val q = queueOf("a", "b")
            val http = ScriptedHttp { _, _ -> AnalyzeOutcome.Success }
            sender(q, store, http).drain()
            assertTrue(http.calls.isEmpty())
            assertEquals(listOf("a", "b"), ids(q))
        }
    }

    @Test fun unauthorized_refreshes_once_then_retries_and_removes() {
        val q = queueOf("a")
        val store = SenderFakeStore()
        val refreshHttp = SenderFakeRefreshHttp(RefreshHttpResult.Ok("new-access", "new-refresh"))
        val http = ScriptedHttp { _, token ->
            if (token == "old-access") AnalyzeOutcome.Unauthorized else AnalyzeOutcome.Success
        }
        sender(q, store, http, refreshHttp).drain()
        assertEquals(1, refreshHttp.calls)
        assertEquals(listOf("a" to "old-access", "a" to "new-access"), http.calls)
        assertTrue(q.all().isEmpty())
    }

    @Test fun unauthorized_then_expired_clears_whole_queue() {
        val q = queueOf("a", "b", "c")
        val store = SenderFakeStore()
        val http = ScriptedHttp { _, _ -> AnalyzeOutcome.Unauthorized }
        sender(q, store, http, SenderFakeRefreshHttp(RefreshHttpResult.Rejected)).drain()
        assertTrue(q.all().isEmpty())
        assertEquals(1, http.calls.size)
        assertTrue(store.sessionExpired)
    }

    @Test fun unauthorized_then_refresh_network_stops_and_keeps_items() {
        val q = queueOf("a", "b")
        val http = ScriptedHttp { _, _ -> AnalyzeOutcome.Unauthorized }
        sender(q, SenderFakeStore(), http, SenderFakeRefreshHttp(RefreshHttpResult.NetworkError)).drain()
        assertEquals(1, http.calls.size)
        assertEquals(listOf("a", "b"), ids(q))
        assertEquals(0, q.all().first().attempts)
    }

    @Test fun network_error_stops_drain_keeps_items_without_counting_attempt() {
        val q = queueOf("a", "b")
        val http = ScriptedHttp { _, _ -> AnalyzeOutcome.NetworkError }
        sender(q, SenderFakeStore(), http).drain()
        assertEquals(1, http.calls.size)
        assertEquals(listOf("a", "b"), ids(q))
        assertTrue(q.all().all { it.attempts == 0 })
    }

    @Test fun repeated_network_error_across_many_drains_never_counts_attempts_or_drops_items() {
        val q = queueOf("a", "b", "c")
        val s = sender(q, SenderFakeStore(), ScriptedHttp { _, _ -> AnalyzeOutcome.NetworkError })
        repeat(10) { s.drain() }
        assertEquals(listOf("a", "b", "c"), ids(q))
        assertTrue(q.all().all { it.attempts == 0 })
    }

    @Test fun retryable_increments_attempts_and_removes_at_max() {
        val q = queueOf("a", "b")
        val http = ScriptedHttp { id, _ -> if (id == "a") AnalyzeOutcome.Retryable else AnalyzeOutcome.Success }
        val s = sender(q, SenderFakeStore(), http, maxAttempts = 3)

        s.drain() // a: attempts 1; vẫn drain tiếp b
        assertEquals(listOf("a"), ids(q))
        assertEquals(1, q.all().single().attempts)

        s.drain() // attempts 2
        assertEquals(2, q.all().single().attempts)

        s.drain() // attempts 3 == maxAttempts -> bỏ
        assertTrue(q.all().isEmpty())
    }

    @Test fun rejected_removes_item() {
        val q = queueOf("a", "b")
        val http = ScriptedHttp { id, _ -> if (id == "a") AnalyzeOutcome.Rejected else AnalyzeOutcome.Success }
        sender(q, SenderFakeStore(), http).drain()
        assertTrue(q.all().isEmpty())
        assertEquals(2, http.calls.size)
    }

    @Test fun drains_oldest_first() {
        val q = queueOf("first", "second", "third")
        val http = ScriptedHttp { _, _ -> AnalyzeOutcome.Success }
        sender(q, SenderFakeStore(), http).drain()
        assertEquals(listOf("first", "second", "third"), http.calls.map { it.first })
    }
}

package com.finmate.app.notifications

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class StatusFakeSession(
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

private class StatusFakeRefreshHttp(private val result: RefreshHttpResult) : RefreshHttp {
    var calls = 0
    override fun refresh(baseUrl: String, refreshToken: String): RefreshHttpResult {
        calls++
        return result
    }
}

private class FakeStatusStore : ListenerStatusStore {
    override val installationId = "11111111-2222-3333-4444-555555555555"
    override var listenerConnected = true
    private val posted = mutableMapOf<String, Long>()
    override var lastReportKey: String? = null
    override var lastReportAtMs = 0L
    override fun recordPosted(packageName: String, atMs: Long) {
        posted[packageName] = atMs
    }
    override fun lastPosted(packageName: String): Long? = posted[packageName]
}

private class ScriptedStatusHttp(private val script: (String) -> StatusOutcome) : ListenerStatusHttp {
    val calls = mutableListOf<Pair<String, JSONObject>>()
    override fun put(baseUrl: String, accessToken: String, body: JSONObject): StatusOutcome {
        calls += accessToken to body
        return script(accessToken)
    }
}

class ListenerStatusTest {
    private var now = 1_700_000_000_000L
    private val store = FakeStatusStore()
    private var permission = true

    private fun reporter(
        http: ListenerStatusHttp,
        session: StatusFakeSession = StatusFakeSession(),
        refreshHttp: StatusFakeRefreshHttp = StatusFakeRefreshHttp(RefreshHttpResult.NetworkError),
        packages: List<String> = listOf("com.VCB"),
    ) = ListenerStatusReporter(
        session = session,
        refresher = TokenRefresher(session, refreshHttp),
        monitoredPackages = { packages },
        statusStore = store,
        http = http,
        device = { DeviceFacts(permission, "2.4.0", "Xiaomi") },
        clock = { now },
    )

    // ---- payload ----

    @Test fun payload_has_the_documented_shape_and_no_notification_content() {
        store.recordPosted("com.VCB", 1_700_000_000_000L)
        val json = reporter(ScriptedStatusHttp { StatusOutcome.Success }).snapshot().toJson()

        assertEquals("11111111-2222-3333-4444-555555555555", json.getString("installationId"))
        assertTrue(json.getBoolean("permissionGranted"))
        assertTrue(json.getBoolean("listenerConnected"))
        assertEquals("2.4.0", json.getString("appVersion"))
        assertEquals("Xiaomi", json.getString("manufacturer"))
        val pkg = json.getJSONArray("selectedPackages").getJSONObject(0)
        assertEquals("com.VCB", pkg.getString("packageName"))
        assertEquals("2023-11-14T22:13:20Z", pkg.getString("lastPostedAt"))
        // Android không cho đọc cài đặt thông báo của app khác: không gửi, không bịa.
        assertFalse(pkg.has("notificationsEnabled"))
        assertEquals(setOf("installationId", "permissionGranted", "listenerConnected", "selectedPackages", "appVersion", "manufacturer"), json.keys().asSequence().toSet())
    }

    @Test fun package_never_seen_has_no_lastPostedAt_and_lists_are_capped() {
        val many = (1..60).map { "com.bank$it" }
        val json = reporter(ScriptedStatusHttp { StatusOutcome.Success }, packages = many).snapshot().toJson()
        val arr = json.getJSONArray("selectedPackages")

        assertEquals(50, arr.length())
        assertFalse(arr.getJSONObject(0).has("lastPostedAt"))
    }

    @Test fun long_version_and_manufacturer_are_truncated_to_the_server_limits() {
        val snap = ListenerSnapshot("id", true, true, emptyList(), "v".repeat(40), "m".repeat(80))
        val json = snap.toJson()

        assertEquals(32, json.getString("appVersion").length)
        assertEquals(64, json.getString("manufacturer").length)
    }

    @Test fun blank_version_and_manufacturer_are_omitted() {
        val json = ListenerSnapshot("id", false, false, emptyList(), " ", null).toJson()

        assertFalse(json.has("appVersion"))
        assertFalse(json.has("manufacturer"))
        assertFalse(json.getBoolean("permissionGranted"))
    }

    // ---- throttle ----

    @Test fun shouldReport_when_forced_changed_or_stale_but_not_otherwise() {
        val key = "true/true"
        assertTrue(shouldReport(null, 0, key, now, force = false))
        assertTrue(shouldReport(key, now, key, now, force = true))
        assertTrue(shouldReport("true/false", now, key, now, force = false))
        assertTrue(shouldReport(key, now - REPORT_INTERVAL_MS, key, now, force = false))
        assertFalse(shouldReport(key, now - 1_000, key, now, force = false))
    }

    // ---- reporter ----

    @Test fun no_session_sends_nothing() {
        val http = ScriptedStatusHttp { StatusOutcome.Success }

        assertEquals(ReportResult.NoSession, reporter(http, StatusFakeSession(baseUrl = null)).report(force = true))
        assertEquals(ReportResult.NoSession, reporter(http, StatusFakeSession(accessToken = null)).report(force = true))
        assertTrue(http.calls.isEmpty())
    }

    @Test fun success_records_the_state_and_skips_an_unchanged_repeat() {
        val http = ScriptedStatusHttp { StatusOutcome.Success }
        val r = reporter(http)

        assertEquals(ReportResult.Sent, r.report(force = false))
        assertEquals("true/true", store.lastReportKey)
        assertEquals(now, store.lastReportAtMs)

        now += 60_000
        assertEquals(ReportResult.Skipped, r.report(force = false))
        assertEquals(1, http.calls.size)
    }

    @Test fun a_changed_state_is_reported_straight_away() {
        val http = ScriptedStatusHttp { StatusOutcome.Success }
        val r = reporter(http)
        r.report(force = false)

        permission = false
        now += 60_000

        assertEquals(ReportResult.Sent, r.report(force = false))
        assertFalse(http.calls.last().second.getBoolean("permissionGranted"))
    }

    @Test fun service_disconnect_is_reported_as_listenerConnected_false() {
        val http = ScriptedStatusHttp { StatusOutcome.Success }
        val r = reporter(http)
        r.report(force = false)

        store.listenerConnected = false
        r.report(force = false)

        assertFalse(http.calls.last().second.getBoolean("listenerConnected"))
    }

    @Test fun force_ignores_the_throttle() {
        val http = ScriptedStatusHttp { StatusOutcome.Success }
        val r = reporter(http)
        r.report(force = false)

        assertEquals(ReportResult.Sent, r.report(force = true))
        assertEquals(2, http.calls.size)
    }

    @Test fun server_error_is_retried_later_and_not_marked_as_reported() {
        val http = ScriptedStatusHttp { StatusOutcome.Retry }

        assertEquals(ReportResult.Retry, reporter(http).report(force = false))
        assertNull(store.lastReportKey)
    }

    @Test fun rejected_is_not_marked_as_reported_either() {
        val http = ScriptedStatusHttp { StatusOutcome.Rejected }

        assertEquals(ReportResult.Skipped, reporter(http).report(force = false))
        assertNull(store.lastReportKey)
    }

    @Test fun unauthorized_refreshes_once_then_sends_with_the_new_token() {
        val session = StatusFakeSession()
        val refreshHttp = StatusFakeRefreshHttp(RefreshHttpResult.Ok("new-access", "new-refresh"))
        val http = ScriptedStatusHttp { token -> if (token == "old-access") StatusOutcome.Unauthorized else StatusOutcome.Success }

        assertEquals(ReportResult.Sent, reporter(http, session, refreshHttp).report(force = false))
        assertEquals(listOf("old-access", "new-access"), http.calls.map { it.first })
        assertEquals(1, refreshHttp.calls)
    }

    @Test fun still_unauthorized_after_refresh_is_a_retry_not_a_loop() {
        val refreshHttp = StatusFakeRefreshHttp(RefreshHttpResult.Ok("new-access", "new-refresh"))
        val http = ScriptedStatusHttp { StatusOutcome.Unauthorized }

        assertEquals(ReportResult.Retry, reporter(http, StatusFakeSession(), refreshHttp).report(force = false))
        assertEquals(2, http.calls.size)
    }

    @Test fun refresh_rejected_means_no_session_and_refresh_network_error_means_retry() {
        val http = ScriptedStatusHttp { StatusOutcome.Unauthorized }

        assertEquals(
            ReportResult.NoSession,
            reporter(http, StatusFakeSession(), StatusFakeRefreshHttp(RefreshHttpResult.Rejected)).report(force = false),
        )
        assertEquals(
            ReportResult.Retry,
            reporter(http, StatusFakeSession(), StatusFakeRefreshHttp(RefreshHttpResult.NetworkError)).report(force = false),
        )
    }

    // ---- HTTP status mapping ----

    @Test fun http_status_mapping() {
        assertEquals(StatusOutcome.Success, mapStatusResponse(204))
        assertEquals(StatusOutcome.Unauthorized, mapStatusResponse(401))
        assertEquals(StatusOutcome.Rejected, mapStatusResponse(400))
        assertEquals(StatusOutcome.Rejected, mapStatusResponse(422)) // LISTENER_TOO_MANY_DEVICES
        assertEquals(StatusOutcome.Retry, mapStatusResponse(404)) // trang endpoint-offline của ngrok
        assertEquals(StatusOutcome.Retry, mapStatusResponse(429))
        assertEquals(StatusOutcome.Retry, mapStatusResponse(503))
    }
}

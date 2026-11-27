package com.finmate.app.notifications

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

/** Một gói ngân hàng/ví người dùng đã chọn và lần cuối listener thấy BẤT KỲ thông báo nào của nó (kể cả thông báo bị lọc). */
data class PackageActivity(val packageName: String, val lastPostedAtMs: Long?)

/** Phần của trạng thái do hệ điều hành/ứng dụng cho biết (không phải do listener tự theo dõi). */
data class DeviceFacts(val permissionGranted: Boolean, val appVersion: String?, val manufacturer: String?)

/**
 * Trạng thái dịch vụ đọc thông báo gửi cho `PUT /devices/listener-status` (docs/listener-health-api.md).
 * KHÔNG chứa nội dung thông báo, số tiền hay app nào ngoài các gói người dùng đã chọn.
 */
data class ListenerSnapshot(
    val installationId: String,
    val permissionGranted: Boolean,
    val listenerConnected: Boolean,
    val packages: List<PackageActivity>,
    val appVersion: String?,
    val manufacturer: String?,
) {
    /** Khóa so sánh để biết trạng thái có đổi không: chỉ hai cờ mà server dùng để tính "ngày ok". */
    val stateKey: String get() = "$permissionGranted/$listenerConnected"

    fun toJson(): JSONObject {
        val selected = JSONArray()
        // Server nhận tối đa 50 mục; gói nào ngoài ví/provider đã biết bị server bỏ lặng lẽ.
        for (p in packages.take(MAX_PACKAGES)) {
            val item = JSONObject().put("packageName", p.packageName)
            // notificationsEnabled: Android không cho app đọc cài đặt thông báo của app khác nên không gửi (trường tùy chọn).
            p.lastPostedAtMs?.let { item.put("lastPostedAt", isoUtc(it)) }
            selected.put(item)
        }
        val json = JSONObject()
            .put("installationId", installationId)
            .put("permissionGranted", permissionGranted)
            .put("listenerConnected", listenerConnected)
            .put("selectedPackages", selected)
        appVersion?.takeIf { it.isNotBlank() }?.let { json.put("appVersion", it.take(MAX_APP_VERSION)) }
        manufacturer?.takeIf { it.isNotBlank() }?.let { json.put("manufacturer", it.take(MAX_MANUFACTURER)) }
        return json
    }

    private companion object {
        const val MAX_PACKAGES = 50
        const val MAX_APP_VERSION = 32
        const val MAX_MANUFACTURER = 64

        // SimpleDateFormat không thread-safe nên tạo mới mỗi lần.
        fun isoUtc(ms: Long): String =
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date(ms))
    }
}

/** Báo lại ít nhất chừng này dù trạng thái không đổi (BE: mỗi ngày một lần; dư ra để lịch của WorkManager lệch vẫn đủ). */
internal const val REPORT_INTERVAL_MS = 20L * 60 * 60 * 1000

/** Báo khi: ép buộc, trạng thái vừa đổi, hoặc đã lâu chưa báo. */
internal fun shouldReport(lastKey: String?, lastAtMs: Long, key: String, nowMs: Long, force: Boolean): Boolean =
    force || lastKey != key || nowMs - lastAtMs >= REPORT_INTERVAL_MS

/** Trạng thái listener lưu cục bộ giữa các lần chạy (service, worker và Flutter dùng chung một tiến trình/ổ đĩa). */
interface ListenerStatusStore {
    /** UUID tự sinh MỘT lần mỗi lần cài; không dùng token FCM vì token đổi bất cứ lúc nào. */
    val installationId: String
    var listenerConnected: Boolean
    fun recordPosted(packageName: String, atMs: Long)
    fun lastPosted(packageName: String): Long?
    var lastReportKey: String?
    var lastReportAtMs: Long
}

class SharedPrefsListenerStatusStore(context: Context) : ListenerStatusStore {
    private val prefs = context.applicationContext.getSharedPreferences("finmate_listener_status", Context.MODE_PRIVATE)

    @get:Synchronized
    override val installationId: String
        get() = prefs.getString(KEY_INSTALLATION, null) ?: UUID.randomUUID().toString().also {
            prefs.edit().putString(KEY_INSTALLATION, it).apply()
        }

    override var listenerConnected: Boolean
        get() = prefs.getBoolean(KEY_CONNECTED, false)
        set(value) = prefs.edit().putBoolean(KEY_CONNECTED, value).apply()

    override fun recordPosted(packageName: String, atMs: Long) {
        prefs.edit().putLong(POSTED_PREFIX + packageName, atMs).apply()
    }

    override fun lastPosted(packageName: String): Long? =
        if (prefs.contains(POSTED_PREFIX + packageName)) prefs.getLong(POSTED_PREFIX + packageName, 0L) else null

    override var lastReportKey: String?
        get() = prefs.getString(KEY_LAST_KEY, null)
        set(value) = prefs.edit().apply { if (value == null) remove(KEY_LAST_KEY) else putString(KEY_LAST_KEY, value) }.apply()

    override var lastReportAtMs: Long
        get() = prefs.getLong(KEY_LAST_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_AT, value).apply()

    private companion object {
        const val KEY_INSTALLATION = "installation_id"
        const val KEY_CONNECTED = "listener_connected"
        const val KEY_LAST_KEY = "last_report_key"
        const val KEY_LAST_AT = "last_report_at"
        const val POSTED_PREFIX = "posted_"
    }
}

enum class StatusOutcome { Success, Unauthorized, Retry, Rejected }

fun interface ListenerStatusHttp {
    fun put(baseUrl: String, accessToken: String, body: JSONObject): StatusOutcome
}

enum class ReportResult { Sent, Skipped, NoSession, Retry }

/**
 * Báo trạng thái dịch vụ đọc thông báo lên backend (BR-LH-01). Chạy từ WorkManager mỗi ngày, khi service nối/ngắt,
 * và khi app mở lại (quyền có thể vừa đổi trong Cài đặt). Không log gì: payload gắn với danh sách ví của người dùng.
 */
class ListenerStatusReporter(
    private val session: SessionStore,
    private val refresher: TokenRefresher,
    private val monitoredPackages: () -> List<String>,
    private val statusStore: ListenerStatusStore,
    private val http: ListenerStatusHttp,
    private val device: () -> DeviceFacts,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    fun snapshot(): ListenerSnapshot {
        val facts = device()
        return ListenerSnapshot(
            installationId = statusStore.installationId,
            permissionGranted = facts.permissionGranted,
            listenerConnected = statusStore.listenerConnected,
            packages = monitoredPackages().map { PackageActivity(it, statusStore.lastPosted(it)) },
            appVersion = facts.appVersion,
            manufacturer = facts.manufacturer,
        )
    }

    /** [force]: bỏ qua giới hạn tần suất (worker hằng ngày). Các nguồn khác chỉ báo khi trạng thái đổi hoặc đã lâu. */
    @Synchronized
    fun report(force: Boolean): ReportResult {
        // Chưa đăng nhập (hoặc đã đăng xuất): không có gì để báo và không có token để báo.
        val baseUrl = session.baseUrl ?: return ReportResult.NoSession
        val token = session.accessToken ?: return ReportResult.NoSession

        val snap = snapshot()
        val now = clock()
        if (!shouldReport(statusStore.lastReportKey, statusStore.lastReportAtMs, snap.stateKey, now, force)) return ReportResult.Skipped

        val body = snap.toJson()
        var outcome = http.put(baseUrl, token, body)
        if (outcome == StatusOutcome.Unauthorized) {
            when (val r = refresher.refresh(token)) {
                is RefreshResult.Ok -> {
                    outcome = http.put(baseUrl, r.accessToken, body)
                    // Vẫn 401 sau khi làm mới: coi là lỗi tạm để không lặp vô hạn.
                    if (outcome == StatusOutcome.Unauthorized) outcome = StatusOutcome.Retry
                }
                RefreshResult.Expired -> return ReportResult.NoSession
                RefreshResult.Network -> return ReportResult.Retry
            }
        }

        return when (outcome) {
            StatusOutcome.Success -> {
                statusStore.lastReportKey = snap.stateKey
                statusStore.lastReportAtMs = now
                ReportResult.Sent
            }
            // 4xx khác (vd. 422 quá số thiết bị): không báo lại ngay, nhưng cũng không đánh dấu đã báo; lần sau thử lại.
            StatusOutcome.Rejected -> ReportResult.Skipped
            StatusOutcome.Retry, StatusOutcome.Unauthorized -> ReportResult.Retry
        }
    }
}

# Bắt thông báo ngân hàng (Flow 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App FinMate bắt thông báo MB Bank/VietinBank trên Android, tự gửi lên BE (kể cả khi app đóng) và cho người dùng xác nhận nháp ở mục "Chờ duyệt".

**Architecture:** Service Android (Kotlin) lọc gói → hàng đợi file → gửi `POST /notifications/analyze`. Android là nơi **duy nhất** giữ và làm mới token; Flutter nhờ Android qua `MethodChannel`. Danh sách nháp là chip mới trên `TransactionsScreen`, gọi `GET /transactions?status=Draft`.

**Tech Stack:** Kotlin (`HttpURLConnection`, `org.json`, EncryptedSharedPreferences), Flutter (Riverpod, dio, drift), BE `FinMate_BE` đã có sẵn.

**Spec:** `docs/superpowers/specs/2026-10-28-notification-capture-design.md`

**Thư mục làm việc:** `E:\Ki 9\Capstone_Project\FinMate_FE`. Lệnh Flutter chạy từ đây; lệnh Gradle chạy từ `android\` bằng `.\gradlew.bat`.

**Không có git:** thay bước "commit" bằng bước **Checkpoint** (chạy kiểm tra của task đó).

## Global Constraints

- Access token sống 15 phút (`JWT_ACCESS_TTL_MINUTES`); BE xoay refresh token và **thu hồi toàn bộ phiên nếu một refresh token bị dùng hai lần** → chỉ Android được gọi `POST /api/v1/auth/refresh`.
- Package Kotlin: `com.example.finmate.notifications`. Channel: `com.example.finmate/notifications`. `MainActivity` đang dùng: `com.example.finmate`.
- Không thêm dependency Flutter (pubspec). Phía Android chỉ dùng `HttpURLConnection` + `org.json`, không WorkManager.
- Hàng đợi tối đa **200** mục; tối đa **5** lần thử cho lỗi 5xx; xóa mục ngay khi BE trả 2xx; xóa sạch khi đăng xuất.
- Không log nội dung thông báo, token, số tiền, số dư.
- Danh sách gói theo dõi do Flutter đẩy xuống (tài khoản `isMonitored` có `packageName`); không ghi cứng gói trong Kotlin.
- Body gửi lên: `{packageName, notificationTitle, notificationBody, receivedAt}`; `receivedAt` là ISO-8601 UTC, chụp **một lần** lúc bắt (để gửi lại không đổi hash của BE).
- Mọi header gửi lên BE kèm `ngrok-skip-browser-warning: true` (URL mặc định của app là tunnel ngrok).
- Việc UI (Task 9) phải gọi skill `ui-ux-pro-max` và `taste-skill` trước khi viết code; dùng token màu/spacing trong `lib/core/theme`, icon từ `lucide_icons_flutter`.
- Ngôn ngữ UI/comment: tiếng Việt, giống code xung quanh.

## Review Focus

- Thông báo có tiêu đề + nội dung đều rỗng/chỉ khoảng trắng → không vào hàng đợi (Task 4).
- File hàng đợi bị hỏng/cắt dở khi app bị kill giữa lúc ghi → đọc như rỗng, ghi bằng file tạm rồi đổi tên, service không crash (Task 1).
- Hai thông báo cùng gặp 401 → đúng **một** lần refresh (Task 2).
- Đăng xuất / hết phiên khi hàng đợi còn mục → hàng đợi bị xóa, không gửi sang tài khoản đăng nhập kế tiếp (Task 3, 5).
- Danh sách lịch sử mặc định **không** hiện nháp và chế độ offline không cache nháp, vì BE trả mọi trạng thái khi không có `status` (Task 8).

---

### Task 0: Chuẩn bị (sao lưu, sửa lỗi cú pháp, mốc ban đầu)

**Files:**
- Modify: `lib/core/network/api_client.dart:24` (xóa dòng chỉ có chữ `E`)

- [ ] **Step 1:** Sao chép toàn bộ `FinMate_FE` (trừ `build\` và `.dart_tool\`) sang `E:\Ki 9\Capstone_Project\FinMate_FE_backup_2026-10-28\` (không có git nên đây là đường lùi).
- [ ] **Step 2:** Xóa dòng 24 của `api_client.dart` (chữ `E` lẻ giữa `Dio? customDio,` và `}) : dio = ...`).
- [ ] **Step 3: Mốc ban đầu.** Run: `flutter analyze` và `flutter test`. Expected: ghi lại số lỗi/test fail có sẵn (nếu có) vào ghi chú để biết lỗi nào không do ta gây ra.

### Task 1: `NotificationQueue` (hàng đợi file)

**Files:**
- Create: `android/app/src/main/kotlin/com/example/finmate/notifications/NotificationQueue.kt`
- Test: `android/app/src/test/kotlin/com/example/finmate/notifications/NotificationQueueTest.kt`
- Modify: `android/app/build.gradle.kts` (thêm `dependencies { testImplementation("junit:junit:4.13.2"); testImplementation("org.json:json:20231013") }`; hai phụ thuộc **chỉ cho test**, cần bạn đồng ý trước)

**Interfaces:**
- Produces:
```kotlin
data class QueuedNotification(val id: String, val packageName: String, val title: String,
    val body: String, val receivedAtMs: Long, val attempts: Int = 0)
class NotificationQueue(private val file: File, private val maxItems: Int = 200) {
    fun add(item: QueuedNotification)
    fun all(): List<QueuedNotification>        // cũ nhất trước
    fun remove(id: String)
    fun incrementAttempts(id: String): Int     // trả số lần mới
    fun clear()
}
```

- [ ] **Step 1: Viết test (thất bại)** trong `NotificationQueueTest` dùng `TemporaryFolder`: `add_then_all_returns_oldest_first`, `add_beyond_max_drops_oldest` (max=3, thêm 4 → còn id 2,3,4), `remove_deletes_only_that_id`, `incrementAttempts_returns_new_count_and_persists`, `corrupt_file_reads_as_empty_and_add_still_works`, `survives_new_instance_on_same_file`, `clear_empties_queue`.
- [ ] **Step 2:** Run: `.\gradlew.bat :app:testDebugUnitTest --tests "*NotificationQueueTest"` (từ `android\`). Expected: FAIL (lớp chưa có).
- [ ] **Step 3:** Cài đặt `NotificationQueue`: mọi hàm công khai `@Synchronized`; lưu JSON mảng bằng `org.json`; ghi vào `file.tmp` rồi `renameTo(file)` để không hỏng giữa chừng; đọc lỗi/parse hỏng → danh sách rỗng.
- [ ] **Step 4:** Chạy lại test. Expected: PASS.
- [ ] **Step 5: Checkpoint:** test trên PASS.

### Task 2: `SessionStore` + `TokenRefresher`

**Files:**
- Create: `.../notifications/SessionStore.kt` (chỉ interface `SessionStore` + kiểu kết quả), `.../notifications/TokenRefresher.kt`
- Test: `android/app/src/test/kotlin/com/example/finmate/notifications/TokenRefresherTest.kt`

**Interfaces:**
- Produces:
```kotlin
interface SessionStore {
    var baseUrl: String?; var accessToken: String?; var refreshToken: String?
    var sessionExpired: Boolean
    fun clearTokens()   // xóa access+refresh
}
sealed interface RefreshHttpResult {
    data class Ok(val accessToken: String, val refreshToken: String) : RefreshHttpResult
    object Rejected : RefreshHttpResult      // 400/401/403
    object NetworkError : RefreshHttpResult  // mạng/5xx
}
fun interface RefreshHttp { fun refresh(baseUrl: String, refreshToken: String): RefreshHttpResult }
sealed interface RefreshResult {
    data class Ok(val accessToken: String) : RefreshResult
    object Expired : RefreshResult
    object Network : RefreshResult
}
class TokenRefresher(private val store: SessionStore, private val http: RefreshHttp) {
    fun refresh(staleAccessToken: String?): RefreshResult   // đồng bộ bằng một khóa trong tiến trình; staleAccessToken == null: luôn làm mới, không so sánh token
}
```

- [ ] **Step 1: Viết test (thất bại)** với `FakeSessionStore` và `RefreshHttp` đếm số lần gọi: `success_saves_new_pair_and_returns_ok`, `token_already_changed_returns_current_without_http` (stale ≠ hiện tại → không gọi http), `two_threads_same_stale_token_call_http_once` (2 luồng, `CountDownLatch`), `rejected_clears_tokens_and_sets_expired`, `network_error_keeps_tokens_and_returns_network`, `missing_refresh_token_returns_expired`, `null_stale_token_always_refreshes` (stale = null → vẫn gọi http dù đã có access token).
- [ ] **Step 2:** Run: `.\gradlew.bat :app:testDebugUnitTest --tests "*TokenRefresherTest"`. Expected: FAIL.
- [ ] **Step 3:** Cài đặt `TokenRefresher.refresh` trong khối `synchronized(lock)`: nếu `staleAccessToken` không null và `store.accessToken` khác `staleAccessToken` (và không null) → `Ok` token hiện tại; nếu `staleAccessToken` null thì bỏ qua phép so sánh này; không có `refreshToken`/`baseUrl` → `Expired`; còn lại gọi `http.refresh`; `Ok` lưu cặp mới; `Rejected` → `clearTokens()` + `sessionExpired = true` → `Expired`; `NetworkError` → `Network`.
- [ ] **Step 4:** Chạy lại test. Expected: PASS.
- [ ] **Step 5: Checkpoint:** cả `NotificationQueueTest` và `TokenRefresherTest` PASS.

### Task 3: `NotificationSender` (xả hàng đợi)

**Files:**
- Create: `.../notifications/NotificationSender.kt`
- Test: `android/app/src/test/kotlin/com/example/finmate/notifications/NotificationSenderTest.kt`

**Interfaces:**
- Consumes: `NotificationQueue`, `SessionStore`, `TokenRefresher`, `QueuedNotification` (Task 1, 2)
- Produces:
```kotlin
sealed interface AnalyzeOutcome {
    object Success : AnalyzeOutcome; object Unauthorized : AnalyzeOutcome
    object Retryable : AnalyzeOutcome      // 5xx, 429
    object Rejected : AnalyzeOutcome       // 4xx khác
    object NetworkError : AnalyzeOutcome
}
fun interface AnalyzeHttp { fun post(baseUrl: String, accessToken: String, item: QueuedNotification): AnalyzeOutcome }
class NotificationSender(queue: NotificationQueue, store: SessionStore, refresher: TokenRefresher,
                         http: AnalyzeHttp, maxAttempts: Int = 5) { fun drain() }  // @Synchronized
```

- [ ] **Step 1: Viết test (thất bại)** với fake: `success_removes_item`, `no_session_does_not_send_and_keeps_queue`, `unauthorized_refreshes_once_then_retries_and_removes`, `unauthorized_then_expired_clears_whole_queue`, `network_error_stops_drain_keeps_items_without_counting_attempt`, `retryable_increments_attempts_and_removes_at_max`, `rejected_removes_item`, `drains_oldest_first`.
- [ ] **Step 2:** Run: `.\gradlew.bat :app:testDebugUnitTest --tests "*NotificationSenderTest"`. Expected: FAIL.
- [ ] **Step 3:** Cài đặt `drain()` đúng các hành vi trên; `Unauthorized` gọi `refresher.refresh(stale)` rồi thử lại đúng một lần; `Expired` → `queue.clear()` và dừng; `Network` → dừng.
- [ ] **Step 4:** Chạy lại test. Expected: PASS.
- [ ] **Step 5: Checkpoint:** ba lớp test Kotlin PASS.

### Task 4: Nối Android (service, kho mã hóa, HTTP thật, channel, manifest)

**Files:**
- Create (cùng thư mục `.../notifications/`): `EncryptedSessionStore.kt`, `UrlConnectionHttp.kt` (cài `RefreshHttp` và `AnalyzeHttp`), `MonitoredPackages.kt`, `NotificationRuntime.kt`, `NotificationCaptureService.kt`, `NotificationChannelHandler.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/example/finmate/MainActivity.kt`, `android/app/build.gradle.kts` (thêm `dependencies { implementation("androidx.security:security-crypto:1.1.0-alpha06") }`; **cùng phiên bản** `flutter_secure_storage` 9.2.4 đã kéo vào build, nhưng khai báo `implementation` của plugin không lộ ra cho module app nên phải khai báo lại)

**Interfaces:**
- Consumes: Task 1–3.
- Produces:
```kotlin
class EncryptedSessionStore(context: Context) : SessionStore          // EncryptedSharedPreferences
class MonitoredPackages(context: Context) { fun set(list: List<String>); fun contains(pkg: String): Boolean; fun clear() }
class NotificationRuntime private constructor(...) {
    val queue: NotificationQueue; val store: SessionStore; val monitored: MonitoredPackages
    fun drainAsync()                                   // executor đơn luồng gọi NotificationSender.drain()
    companion object { fun get(context: Context): NotificationRuntime }
}
class NotificationChannelHandler(private val context: Context) { fun register(messenger: BinaryMessenger) }
```
- Channel `com.example.finmate/notifications`, các phương thức: `setSession{baseUrl,accessToken,refreshToken}`, `clearSession` (xóa token + hàng đợi + danh sách gói + cờ hết phiên), `getAccessToken`, `getRefreshToken`, `refreshSession{staleAccessToken?}` (gọi `TokenRefresher.refresh(staleAccessToken)`) → `{status:"ok",accessToken}|{status:"expired"}|{status:"network"}`, `setMonitoredPackages{packages}`, `isNotificationAccessEnabled`, `openNotificationAccessSettings`, `flushQueue` (gọi `drainAsync`), `consumeSessionExpired` (trả bool rồi đặt lại).

- [ ] **Step 1:** `UrlConnectionHttp`: timeout 15 s; header `Content-Type: application/json`, `Authorization: Bearer ...`, `ngrok-skip-browser-warning: true`. `POST {baseUrl}/api/v1/notifications/analyze`: 2xx→`Success`, 401→`Unauthorized`, 5xx/429→`Retryable`, 4xx khác→`Rejected`, `IOException`→`NetworkError`. `POST {baseUrl}/api/v1/auth/refresh` body `{"refreshToken":...}`, đọc `data.accessToken` + `data.refreshToken`; 400/401/403→`Rejected`; lỗi khác→`NetworkError`. `receivedAt` định dạng bằng `SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)` múi giờ UTC (minSdk thấp nên không dùng `Instant`).
- [ ] **Step 2:** `NotificationCaptureService : NotificationListenerService`: trong `onNotificationPosted` lấy tiêu đề (`EXTRA_TITLE`) và nội dung (`EXTRA_BIG_TEXT` nếu không rỗng, ngược lại `EXTRA_TEXT`); bỏ nếu cả hai đều trống/khoảng trắng; bỏ nếu `!monitored.contains(packageName)`; ngược lại `queue.add(QueuedNotification(UUID, pkg, title, body, System.currentTimeMillis()))` rồi `drainAsync()`. `onListenerConnected`: đăng ký `ConnectivityManager.registerNetworkCallback` (khi có mạng → `drainAsync()`); `onListenerDisconnected`: hủy đăng ký + `requestRebind(ComponentName(this, javaClass))`. Không gọi `Log` với nội dung/token.
- [ ] **Step 3:** `AndroidManifest.xml`: thêm khối `<service android:name=".notifications.NotificationCaptureService" android:exported="true" android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">` với intent-filter `android.service.notification.NotificationListenerService`. `MainActivity.configureFlutterEngine` gọi `NotificationChannelHandler(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)`.
- [ ] **Step 4: Xác nhận biên dịch.** Run: `flutter build apk --debug`. Expected: BUILD SUCCESSFUL, và `.\gradlew.bat :app:testDebugUnitTest` vẫn PASS.
- [ ] **Step 5: Checkpoint:** build debug thành công (chưa thử trên máy thật ở bước này).

### Task 5: Cầu nối Dart + `NativeTokenStorage`

**Files:**
- Create: `lib/core/native/notification_bridge.dart`, `lib/core/network/native_token_storage.dart`
- Test: `test/core/native_token_storage_test.dart`

**Interfaces:**
- Produces:
```dart
enum NativeRefreshStatus { ok, expired, network }
class NativeRefreshResult { final NativeRefreshStatus status; final String? accessToken; const NativeRefreshResult(this.status, [this.accessToken]); }
class NotificationBridge {
  NotificationBridge({MethodChannel? channel});   // mặc định MethodChannel('com.example.finmate/notifications')
  Future<void> setSession({required String baseUrl, required String accessToken, required String refreshToken});
  Future<void> clearSession();
  Future<String?> getAccessToken();  Future<String?> getRefreshToken();
  Future<NativeRefreshResult> refreshSession({String? staleAccessToken});
  Future<void> setMonitoredPackages(List<String> packages);
  Future<bool> isNotificationAccessEnabled();  Future<void> openNotificationAccessSettings();
  Future<void> flushQueue();  Future<bool> consumeSessionExpired();
}
abstract interface class NativeRefresher { Future<NativeRefreshResult> refreshViaNative({String? staleAccessToken}); }
class NativeTokenStorage implements ITokenStorage, NativeRefresher {
  NativeTokenStorage({required NotificationBridge bridge, required ITokenStorage legacy, required String baseUrl});
}
```
(Lựa chọn của tôi: dùng interface `NativeRefresher` riêng thay vì thêm phương thức vào `ITokenStorage`, để các lớp `implements ITokenStorage` sẵn có và trong test không bị vỡ.)

- [ ] **Step 1: Viết test (thất bại)** với kênh giả (`TestDefaultBinaryMessengerBinding...setMockMethodCallHandler`) và `InMemoryTokenStorage` làm `legacy`: `saveTokens_calls_setSession_with_baseUrl`, `getAccessToken_reads_native`, `clearTokens_clears_native_and_legacy`, `first_use_migrates_legacy_tokens_when_native_empty_then_clears_legacy`, `no_migration_when_native_already_has_token`, `refreshViaNative_maps_ok_expired_network_and_passes_staleAccessToken`, `bridge_swallows_MissingPluginException_with_safe_defaults` (flush no-op, `isNotificationAccessEnabled` false, `consumeSessionExpired` false).
- [ ] **Step 2:** Run: `flutter test test/core/native_token_storage_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Cài đặt hai file. `hasAccessToken` đọc từ native. Di chuyển legacy chạy lười, đúng một lần, trước mọi phương thức của `NativeTokenStorage`.
- [ ] **Step 4:** Chạy lại test. Expected: PASS.
- [ ] **Step 5: Checkpoint:** `flutter analyze` không thêm lỗi mới so với mốc Task 0.

### Task 6: `AuthInterceptor` nhờ Android làm mới + đổi provider

**Files:**
- Modify: `lib/core/network/auth_interceptor.dart` (nhánh đầu của `onError`), `lib/features/auth/presentation/controllers/auth_controller.dart:10` (`tokenStorageProvider`)
- Test: `test/core/api_client_test.dart` (thêm nhóm `AuthInterceptor + NativeRefresher`, dùng `_StubAdapter` và `buildClient` sẵn có)

**Interfaces:**
- Consumes: `NativeRefresher`, `NativeRefreshResult` (Task 5)
- Produces: `tokenStorageProvider` trả `NativeTokenStorage(bridge: NotificationBridge(), legacy: SecureTokenStorage(), baseUrl: ApiClient.defaultBaseUrl)` khi `Platform.isAndroid`, ngược lại `SecureTokenStorage()`.

- [ ] **Step 1: Viết test (thất bại).** Thêm `_NativeStorage extends InMemoryTokenStorage implements NativeRefresher` với kết quả cấu hình được. Ba ca: `native ok → gửi lại request với token mới, không gọi /auth/refresh qua Dio, và storage nhận đúng token cũ ('old') làm staleAccessToken`; `native expired → clearTokens + onSessionExpired đúng 1 lần`; `native network → ném NetworkException, giữ phiên (expiredCount 0)`.
- [ ] **Step 2:** Run: `flutter test test/core/api_client_test.dart`. Expected: 3 test mới FAIL, test cũ vẫn PASS.
- [ ] **Step 3:** Trong `AuthInterceptor.onError`, sau khi xác định là 401 trên API bảo vệ: nếu `tokenStorage is NativeRefresher` thì gọi `refreshViaNative(staleAccessToken: <token trong header Authorization của request lỗi, bỏ tiền tố "Bearer ">)` và xử lý ba trạng thái (`ok` → đặt header `Bearer` mới và `plain.fetch`; `expired` → `_expireSession()` + `handler.next(err)`; `network` → `handler.next(DioException(requestOptions: options, type: DioExceptionType.connectionError))`); ngược lại giữ nguyên đường Dio cũ. Sửa `tokenStorageProvider` như trên.
- [ ] **Step 4:** Chạy lại `flutter test test/core/api_client_test.dart`. Expected: PASS toàn bộ.
- [ ] **Step 5: Checkpoint:** `flutter test` toàn bộ không có test mới bị đỏ so với mốc Task 0.

### Task 7: Đẩy danh sách gói + xả hàng đợi khi mở app

**Files:**
- Modify: `lib/features/accounts/domain/financial_account.dart` (thêm `final String? packageName;` đọc từ `json['packageName']`), `lib/main.dart` (thêm `builder:` bọc router)
- Create: `lib/features/notifications/presentation/notification_capture_scope.dart`
- Test: `test/features/notifications/notification_capture_scope_test.dart`, `test/features/accounts/accounts_test.dart` (thêm ca `packageName`)

**Interfaces:**
- Produces:
```dart
final notificationBridgeProvider = Provider<NotificationBridge>((ref) => NotificationBridge());
List<String> monitoredPackagesOf(List<FinancialAccount> accounts);   // isMonitored && packageName không rỗng, không trùng
class NotificationCaptureScope extends ConsumerStatefulWidget { const NotificationCaptureScope({required Widget child}); }
final notificationAccessEnabledProvider = FutureProvider.autoDispose<bool>(...);   // đọc bridge.isNotificationAccessEnabled()
```

- [ ] **Step 1: Viết test (thất bại):** `monitoredPackagesOf_filters_unmonitored_blank_and_duplicates`; `FinancialAccount.fromJson_reads_packageName`; widget test với `notificationBridgeProvider` bị override bằng bridge giả: `pushes_packages_when_accounts_load`, `flushes_queue_on_start_and_on_resume`, `session_expired_flag_sets_sessionExpiredProvider`.
- [ ] **Step 2:** Run: `flutter test test/features/notifications test/features/accounts/accounts_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Cài đặt `NotificationCaptureScope` (`WidgetsBindingObserver`): khi khởi tạo và khi `resumed` gọi `flushQueue()`, `consumeSessionExpired()` (true → `sessionExpiredProvider.notifier.state = true`) và `ref.invalidate(notificationAccessEnabledProvider)`; `ref.listen(accountsControllerProvider, ...)` đẩy `monitoredPackagesOf(...)` xuống `setMonitoredPackages`. Trong `main.dart`: `builder: (context, child) => NotificationCaptureScope(child: child ?? const SizedBox.shrink())`.
- [ ] **Step 4:** Chạy lại các test trên. Expected: PASS.
- [ ] **Step 5: Checkpoint:** `flutter analyze` không thêm lỗi mới.

### Task 8: Repository và controller cho nháp

**Files:**
- Modify: `lib/features/transactions/data/transaction_repository.dart`, `lib/features/transactions/presentation/controllers/transaction_controller.dart`
- Test: `test/features/transactions/transaction_drafts_test.dart` (xây `AppDatabase` và `ApiClient` giống `test/core/sync_service_test.dart`)

**Interfaces:**
- Produces:
```dart
// TransactionRepository
Future<TransactionPage> getTransactions({TransactionType? type, DateTime? fromDate, DateTime? toDate,
    String? cursor, int limit = 20, TransactionStatus status = TransactionStatus.confirmed});
Future<TransactionEntity> confirmDraft(String id, {String? categoryId});     // POST /api/v1/transactions/{id}/confirm
Future<TransactionEntity> updateDraft({required String id, required String accountId, String? categoryId,
    required BigInt amountCents, required TransactionType type, required DateTime date,
    String? merchantName, String description = ''});                          // PATCH /api/v1/transactions/{id}
// TransactionController
bool get draftsOnly;  Future<void> setDraftsOnly(bool value);
Future<void> confirmDraft(String id, {String? categoryId});                  // gỡ khỏi danh sách rồi onDataChanged
Future<void> saveDraft({... như updateDraft ...});                           // cập nhật dòng trong danh sách
```
- `status` gửi lên query là `Confirmed`/`Draft`; **mặc định `confirmed`** vì BE trả mọi trạng thái khi thiếu tham số. Giao dịch `draft` **không** được ghi vào cache drift (`insertLocalTransaction`) và `_cached` không trả nháp.
- Body PATCH: `financialAccountId, counterAccountId: null, categoryId, amountCents, transactionType, transactedAt (UTC ISO), merchantName, description`.

- [ ] **Step 1: Viết test (thất bại):** `default_list_requests_status_Confirmed`; `drafts_request_status_Draft_and_are_not_cached`; `confirmDraft_posts_to_confirm_and_returns_entity`; `updateDraft_patches_full_body`; controller: `setDraftsOnly_true_loads_drafts_and_ignores_type_filter`, `confirmDraft_removes_item_and_calls_onDataChanged`.
- [ ] **Step 2:** Run: `flutter test test/features/transactions/transaction_drafts_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Cài đặt như Interfaces. Với `setDraftsOnly(true)` bộ lọc loại bị bỏ qua; đặt lại `_cursor`.
- [ ] **Step 4:** Chạy lại test, rồi `flutter test test/core/sync_service_test.dart test/core/database_test.dart`. Expected: PASS (không phá offline queue).
- [ ] **Step 5: Checkpoint:** `flutter test` toàn bộ không có test mới bị đỏ.

### Task 9: Giao diện "Chờ duyệt"

**Files:**
- Modify: `lib/features/transactions/presentation/screens/transactions_screen.dart` (thêm chip + nhánh hiển thị nháp)
- Create: `lib/features/transactions/presentation/widgets/draft_transaction_tile.dart`, `lib/features/transactions/presentation/widgets/notification_access_card.dart`
- Test: `test/features/transactions/pending_tab_test.dart`

**Interfaces:**
- Consumes: `transactionControllerProvider`, `notificationAccessEnabledProvider`, `notificationBridgeProvider` (Task 7, 8)

- [ ] **Step 1: Gọi skill `ui-ux-pro-max` và `taste-skill`** (bắt buộc theo `CLAUDE.md` của FE) rồi lập bố cục: chip "Chờ duyệt" nằm trong hàng chip hiện có (cạnh "Tất cả"...); mỗi nháp là một tile gồm số tiền (màu theo thu/chi), người nhận/mô tả, tên danh mục, ngày, nút **Xác nhận** và **Sửa**; thẻ nhắc quyền hiện trong chế độ Chờ duyệt khi quyền tắt, có nút "Mở cài đặt"; đủ trạng thái loading/empty/error.
- [ ] **Step 2: Viết widget test (thất bại)** với `transactionControllerProvider`, `notificationAccessEnabledProvider` bị override: `shows_Cho_duyet_chip`, `tapping_chip_requests_drafts`, `draft_tile_shows_amount_and_actions`, `tapping_Xac_nhan_confirms_draft`, `permission_card_shown_when_access_disabled`, `empty_state_when_no_drafts`.
- [ ] **Step 3:** Run: `flutter test test/features/transactions/pending_tab_test.dart`. Expected: FAIL.
- [ ] **Step 4:** Cài đặt giao diện. Nút **Sửa**: đọc `lib/features/assistant/presentation/screens/transaction_review_screen.dart`; nếu `ReviewArgs` mang được một nháp có sẵn trên server (id + trường hiện có) thì tái dùng và gọi `saveDraft` rồi `confirmDraft`; nếu không thì mở bottom sheet gọn (số tiền, danh mục, tài khoản, người nhận, mô tả) dùng cùng hai lệnh. Ghi lựa chọn vào đầu file widget.
- [ ] **Step 5:** Chạy lại test. Expected: PASS.
- [ ] **Step 6: Checkpoint:** `flutter analyze` không thêm lỗi mới.

### Task 10: Kiểm tra toàn bộ và thử trên máy thật

**Files:** không sửa file; chỉ chạy lệnh và ghi kết quả.

- [ ] **Step 1:** Run: `flutter analyze`, `flutter test`, `.\gradlew.bat :app:testDebugUnitTest` (từ `android\`), `flutter build apk --debug`. Expected: không có lỗi/test đỏ mới so với mốc Task 0; build thành công.
- [ ] **Step 2 (máy Android thật, BE + ai-service đang chạy, tài khoản MB hoặc VietinBank đã tạo qua onboarding):** (a) bật Notification Access cho FinMate; (b) **đóng hẳn app**, nhận một thông báo MB/VietinBank thật → mở app, mục "Chờ duyệt" có nháp; (c) tắt mạng, nhận thông báo, bật mạng → nháp xuất hiện không cần mở app; (d) để app đóng hơn 16 phút rồi nhận thông báo → nháp vẫn được tạo và **không bị đăng xuất**; (e) đăng xuất → mở lại bằng tài khoản khác, hàng đợi trống; (f) `adb logcat -d | findstr /i "analyze refresh"` không chứa nội dung thông báo hay token. (Thông báo giả đăng bằng `adb shell cmd notification` đến từ gói `com.android.shell` nên bị bộ lọc bỏ; đúng thiết kế.)
- [ ] **Step 3:** Ghi kết quả (đạt/không đạt từng mục a–f) vào cuối tài liệu spec, mục mới "Kết quả kiểm tra".

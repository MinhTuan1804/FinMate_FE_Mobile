# Bắt thông báo ngân hàng (Flow 1) vào FinMate_FE — thiết kế

Ngày: 2026-10-28. Trạng thái: chờ duyệt. Chưa viết code.

## 1. Mục đích

Khi ngân hàng (MB Bank, VietinBank) báo biến động số dư, FinMate tự đọc thông báo đó, nhờ BE + AI tạo **bản nháp giao dịch**, và người dùng chỉ cần xác nhận. Phần BE (`POST /notifications/analyze`, nháp, `confirm`) và AI đã có sẵn trong `FinMate_BE`. Việc còn thiếu là **phía app**: bắt thông báo trên Android, gửi lên BE, và cho người dùng thấy/xác nhận nháp.

Nguồn code tham khảo: prototype `FinMate_Flow1_Flutter` (service bắt thông báo bằng Kotlin). Chỉ lấy phần bắt thông báo; không lấy parser, màn lab, hay Flow1.Api.

## 2. Mục tiêu, không phải mục tiêu, điều phải tránh

**Mục tiêu**
- Thông báo ngân hàng bắt được thì nháp được tạo trên BE **kể cả khi app đang đóng**.
- Người dùng thấy các nháp ở mục "Chờ duyệt" trong màn Giao dịch và xác nhận hoặc sửa rồi xác nhận.
- Tận dụng đăng nhập, `ApiClient`, onboarding chọn provider, danh sách giao dịch đã có.

**Không phải mục tiêu (v1)**
- Push FCM / thông báo đẩy khi có nháp (làm sau, không phải làm lại gì).
- iOS (iOS không cho đọc thông báo của app khác).
- Ví điện tử (MoMo, ZaloPay...). Chỉ gửi package nằm trong tài khoản đang theo dõi của người dùng, nên tự mở rộng khi BE bật provider.
- Parser phía app. Trích xuất là việc của ai-service.
- WorkManager. v1 thử lại bằng callback mạng và khi mở app.

**Điều phải tránh**
- Làm người dùng bị đăng xuất vì hai nơi cùng làm mới token.
- Giữ nội dung thông báo (có số dư, số tài khoản) lâu hơn cần thiết hoặc ghi vào log.
- Hỏng đăng nhập hiện có.

## 3. Ràng buộc đã kiểm tra

- Access token sống 15 phút (`JWT_ACCESS_TTL_MINUTES`), refresh token 30 ngày. BE **xoay** refresh token; dùng lại một token đã xoay sẽ **thu hồi toàn bộ phiên** của người dùng (`RefreshTokenCommandHandler`).
- Hiện chỉ Flutter làm mới token (`AuthInterceptor`), token nằm trong `flutter_secure_storage`.
- BE chặn thông báo gửi trùng bằng hash (gói + tiêu đề + nội dung + phút nhận). BE tự lọc "có theo dõi gói này không" bằng tài khoản của user, nên gói lạ trả `Ignored`.
- Repo `CLAUDE.md`: không thêm dependency Flutter khi chưa hỏi; việc UI phải qua skill thiết kế; không log dữ liệu nhạy cảm.
- Thư mục FE không phải git repo, nên không có đường lùi. Mỗi file sửa/thêm được liệt kê ở mục 9.

## 4. Các hướng đã cân nhắc

| Hướng | Nội dung | Kết quả |
|---|---|---|
| 1 | Android lưu hàng đợi, Flutter gửi khi mở app | Bỏ: app đóng thì BE không nhận gì |
| 2 | Android ghi thẳng vào DB drift | Bỏ: hai bên cùng ghi một file SQLite, phải sửa schema |
| **3** | **Android tự gửi lên BE ngay** | **Chọn** (người dùng chọn) |

Hướng 3 đòi Android làm mới token. Để tránh va chạm với Flutter, người dùng **đã đồng ý**: Android là nơi duy nhất làm mới token; Flutter nhờ Android qua channel.

## 5. Thiết kế

### 5.1 Phía Android (Kotlin, package `com.example.finmate.notifications`)

- **`NotificationCaptureService`** (NotificationListenerService): nhận thông báo, bỏ nếu `packageName` không nằm trong danh sách theo dõi, ngược lại thêm vào hàng đợi rồi thử gửi.
- **Danh sách gói theo dõi**: Flutter đẩy xuống (SharedPreferences thường, không nhạy cảm), lấy từ tài khoản có `isMonitored` và `packageName`. Không ghi cứng trong Kotlin.
- **Kho phiên (`SessionStore`)**: lưu `baseUrl`, `accessToken`, `refreshToken` bằng EncryptedSharedPreferences. Đây là **nguồn sự thật duy nhất** của token. Thư viện `androidx.security:security-crypto` nhiều khả năng đã có sẵn trên classpath qua `flutter_secure_storage` 9.x; cần kiểm khi lập kế hoạch. Nếu chưa có thì cần hỏi người dùng trước khi thêm.
- **Hàng đợi (`NotificationQueue`)**: file riêng trong thư mục riêng của app, mỗi mục gồm `id`, `packageName`, `title`, `body`, `receivedAt` (giờ lúc bắt, lưu một lần để gửi lại không đổi hash), `attempts`. Xóa mục **ngay khi BE trả 2xx**. Tối đa 200 mục. Xóa sạch khi đăng xuất.
- **Gửi (`NotificationSender`)**: HTTP bằng `HttpURLConnection` + `org.json` (không thêm thư viện). `POST /api/v1/notifications/analyze` với `{packageName, notificationTitle, notificationBody, receivedAt(ISO-8601 UTC)}`.
  - 2xx → xóa mục.
  - 401 → làm mới token (xem dưới), thử lại đúng một lần.
  - Lỗi mạng / 5xx → giữ mục, tăng `attempts`.
  - 4xx khác hoặc `attempts` ≥ 5 → bỏ mục (không ghi nội dung vào log).
- **Làm mới token (`TokenRefresher`)**: một khóa trong tiến trình (`Mutex`). Trong khóa: đọc lại token mới nhất; nếu đã đổi so với lúc 401 thì dùng luôn, nếu không thì gọi `POST /auth/refresh` và lưu cặp mới. Refresh trả 400/401/403 → xóa token, đặt cờ "hết phiên".
- **Thử lại**: `ConnectivityManager.registerNetworkCallback` trong service (khi có mạng thì xả hàng đợi), và xả khi Flutter báo app mở lại.
- **Khôi phục**: `onListenerDisconnected` gọi `requestRebind`.

### 5.2 Channel `com.example.finmate/notifications` (đăng ký trong `MainActivity` đang dùng: `com.example.finmate`)

`setSession(baseUrl, accessToken, refreshToken)`, `clearSession()` (xóa token + hàng đợi + danh sách gói), `getAccessToken()`, `getRefreshToken()`, `refreshSession()` (làm mới có khóa, trả token mới hoặc lỗi/hết phiên), `setMonitoredPackages(list)`, `isNotificationAccessEnabled()`, `openNotificationAccessSettings()`, `flushQueue()`, `consumeSessionExpired()`.

### 5.3 Phía Flutter

- **`NativeTokenStorage`** thực thi `ITokenStorage` bằng channel. Provider dựng `ApiClient` dùng nó thay `SecureTokenStorage` trên Android. `AuthInterceptor` gọi `refreshSession()` của channel thay vì tự `POST /auth/refresh`, nên **không còn hai nơi cùng làm mới**.
- **Giao diện `ITokenStorage`** (lựa chọn của tôi, người xây có thể đổi): thêm một phương thức làm mới tùy chọn; `SecureTokenStorage` giữ đường cũ (Flutter tự refresh), `NativeTokenStorage` chuyển cho Android. `saveTokens` của `NativeTokenStorage` gọi `setSession` kèm `baseUrl` lấy từ `ApiClient.defaultBaseUrl` (cùng giá trị `--dart-define=API_BASE_URL`).
- **Di chuyển một lần**: lần chạy đầu sau khi cập nhật, nếu kho Android trống mà `flutter_secure_storage` còn token thì chép sang rồi xóa bên cũ, để người dùng đang đăng nhập không bị đăng xuất.
- **Đồng bộ phiên**: sau đăng nhập/đăng ký thành công `setSession`; đăng xuất `clearSession`; khi app mở lại gọi `flushQueue` và `consumeSessionExpired` (nếu hết phiên thì chạy đường `onSessionExpired` sẵn có).
- **Danh sách gói**: sau khi tải tài khoản, đẩy các `packageName` của tài khoản `isMonitored` xuống Android. Cần thêm trường `packageName` vào `FinancialAccount` (BE đã trả sẵn).
- **Quyền**: một thẻ nhắc trong mục "Chờ duyệt" khi `isNotificationAccessEnabled()` là false, có nút mở cài đặt.

### 5.4 Mục "Chờ duyệt"

- Thêm chip **"Chờ duyệt"** vào hàng chip lọc có sẵn của `TransactionsScreen`, gọi `GET /transactions?status=Draft` (thêm tham số `status` cho `getTransactions`).
- Mỗi nháp có: **Xác nhận** (một chạm, `POST /transactions/{id}/confirm`) và **Sửa** (PATCH rồi confirm; ưu tiên tái dùng màn xem lại sẵn có của trợ lý nếu khớp, quyết khi lập kế hoạch).
- Làm mới khi mở màn và khi app quay lại foreground.
- Phần giao diện phải đi qua skill thiết kế UI theo `CLAUDE.md` của FE (đủ trạng thái loading/empty/error).

## 6. Luồng chính

Thông báo MB → `NotificationCaptureService` → lọc gói → hàng đợi → `NotificationSender` → BE `analyze` → (BE) AI đọc, tạo nháp → mục bị xóa khỏi hàng đợi. Người dùng mở app → mục "Chờ duyệt" → Xác nhận.

## 7. Lỗi và trường hợp biên

- Không có mạng: giữ hàng đợi, gửi lại khi có mạng.
- Chưa đăng nhập / đã đăng xuất: không có phiên thì không gửi; thông báo bị bỏ (không giữ nội dung vô thời hạn).
- Hết phiên (refresh bị từ chối): xóa token, lần mở app kế tiếp đưa về màn đăng nhập.
- Thông báo lặp / cập nhật cùng nội dung: BE chặn bằng hash.
- Nháp tạo nhưng người dùng chưa mở app: nằm ở "Chờ duyệt" cho đến khi xác nhận (chưa tính vào ngân sách).
- Đổi tài khoản trên cùng máy: đăng xuất xóa sạch hàng đợi nên không lẫn dữ liệu giữa hai người.

## 8. Kiểm thử và xác nhận

- Unit test Kotlin cho `NotificationQueue` (thêm/xóa/giới hạn) và `TokenRefresher` (hai lời gọi đồng thời chỉ tạo một refresh).
- Test Dart cho `NativeTokenStorage` bằng channel giả và tham số `status` mới.
- Bắt buộc thử trên **máy Android thật** với thông báo MB/VietinBank thật hoặc mô phỏng: app đóng, app mở, mất mạng rồi có mạng, token hết hạn.
- Trước khi báo xong: chạy `flutter analyze`, `flutter test`, build debug.

## 9. File dự kiến đụng vào

Mới: các file Kotlin trong `android/app/src/main/kotlin/com/example/finmate/notifications/`, `lib/core/network/native_token_storage.dart`, phần danh sách nháp trong `lib/features/transactions/`. Sửa: `AndroidManifest.xml` (khai báo service), `MainActivity.kt` (channel), `auth_interceptor.dart`, nơi dựng `ITokenStorage`/`ApiClient`, `financial_account.dart`, `transaction_repository.dart`, `transactions_screen.dart`, `api_client.dart` (xem mục 10).

## 10. Việc cần xác nhận / để người xây quyết

- **Cần bạn OK**: `lib/core/network/api_client.dart` dòng 24 có một chữ `E` lẻ giữa danh sách tham số (lỗi cú pháp, app không build được). Cần xóa để build; đây là file ngoài phạm vi nên hỏi trước.
- Nếu `security-crypto` chưa có sẵn trên classpath: có thêm phụ thuộc Android này không?
- Trên nền tảng không phải Android, `NativeTokenStorage` quay về `SecureTokenStorage`.
- Quyết khi lập kế hoạch: tái dùng màn xem lại của trợ lý cho "Sửa", và giữ file hàng đợi dạng thường hay mã hóa.

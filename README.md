# FinMate – Mobile App

FinMate là ứng dụng di động giúp quản lý tài chính cá nhân thông minh: ghi chép thu chi, theo dõi tài khoản/ví, đặt ngân sách và mục tiêu tiết kiệm, xem báo cáo, và nhập giao dịch nhanh bằng trợ lý AI (chat, giọng nói, quét hóa đơn). Đây là repo **frontend (Flutter)** của đồ án Capstone; backend và AI service nằm ở repo riêng.

## Tính năng

- **Xác thực:** đăng ký, xác minh OTP, đăng nhập, quản lý phiên; token lưu trong secure storage và tự làm mới.
- **Onboarding:** thiết lập ban đầu (thu nhập, tài khoản) và đồng ý dùng dữ liệu để huấn luyện.
- **Giao dịch:** thêm/sửa/xóa, phân trang, tab "Chờ duyệt" cho các bản nháp.
- **Tài khoản & danh mục:** nhiều tài khoản/ví, danh mục thu chi.
- **Kế hoạch:** ngân sách và mục tiêu tiết kiệm.
- **Báo cáo:** biểu đồ thu chi theo thời gian, theo danh mục.
- **Trợ lý AI:** nhập giao dịch bằng chat, giọng nói hoặc quét hóa đơn; tạo nháp để người dùng xác nhận.
- **Bắt thông báo ngân hàng (Android):** đọc thông báo biến động số dư, gửi lên backend để tạo nháp giao dịch, kể cả khi app đang đóng.
- **Offline-first:** dữ liệu lưu cục bộ bằng SQLite (Drift), có hàng đợi đồng bộ khi có mạng.

## Công nghệ

| Mảng | Thư viện |
|------|----------|
| Framework | Flutter (Dart SDK `^3.12.0`) |
| State management | `flutter_riverpod` |
| Điều hướng | `go_router` |
| Mạng | `dio` |
| Lưu trữ an toàn | `flutter_secure_storage` |
| Cơ sở dữ liệu cục bộ | `drift`, `sqlite3_flutter_libs` |
| UI | `google_fonts`, `fl_chart`, `lucide_icons_flutter` |
| AI / thiết bị | `speech_to_text`, `record`, `image_picker`, `google_mlkit_document_scanner` |
| Định dạng | `intl` (locale `vi-VN`) |

## Yêu cầu

- Flutter SDK tương thích Dart `^3.12.0` (kiểm tra bằng `flutter --version`)
- Android Studio hoặc VS Code kèm Flutter plugin
- Thiết bị thật hoặc emulator Android (tính năng bắt thông báo chỉ chạy trên Android)

## Chạy dự án

```bash
# 1. Cài thư viện
flutter pub get

# 2. Sinh code Drift (khi sửa bảng/database)
dart run build_runner build --delete-conflicting-outputs

# 3. Chạy app
flutter run
```

### Cấu hình địa chỉ backend

Địa chỉ API đọc từ `API_BASE_URL` (xem `lib/core/network/api_client.dart`). Ghi đè khi chạy:

```bash
# Emulator Android gọi backend chạy trên máy host
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# Thiết bị thật: dùng IP LAN của máy chạy backend
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
```

Không đưa secret, API key hay token vào code hoặc commit. Dùng `--dart-define` hoặc biến môi trường.

## Kiểm thử

```bash
flutter analyze
flutter test
```

Bộ test live kiểm chứng hợp đồng với backend thật (`test/live/contract_live_test.dart`) mặc định bị bỏ qua. Muốn chạy, đặt `FINMATE_BASE_URL`, `FINMATE_TEST_EMAIL`, `FINMATE_TEST_PASSWORD` trỏ tới môi trường dev với tài khoản thử đã xác thực.

## Cấu trúc thư mục

```
lib/
├── main.dart
├── routes/              # Cấu hình go_router
├── core/
│   ├── database/        # Drift: bảng, database, dịch vụ đồng bộ
│   ├── network/         # ApiClient, interceptor xác thực, lưu token
│   ├── native/          # Cầu nối với code Android (thông báo)
│   ├── theme/           # Design token: màu, spacing, typography
│   └── format/          # Định dạng tiền tệ, ngày tháng (vi-VN)
└── features/            # Mỗi tính năng: data / domain / presentation
    ├── auth/  onboarding/  dashboard/  transactions/  accounts/
    ├── categories/  planning/  analytics/  assistant/
    └── notifications/  profile/

android/app/src/main/kotlin/.../notifications/   # Service bắt thông báo (Kotlin)
test/                    # Unit, widget, integration, live
docs/                    # Tài liệu thiết kế, đặc tả, kế hoạch
```

## Quy trình làm việc với Git

```
dev/tuan, dev/thien, dev/tho, dev/tung  →  PR  →  develop  →  PR  →  main
```

- Mỗi thành viên code trên nhánh `dev/<tên>` của mình, cập nhật từ `develop` trước khi bắt đầu.
- Tạo Pull Request vào `develop`; cần người khác review trước khi merge.
- Khi `develop` build và test ổn, leader tạo PR từ `develop` sang `main`. `main` luôn là bản ổn định.
- Không push thẳng vào `main`.

## Quy ước

- Icon: chỉ dùng `lucide_icons_flutter`, không tự vẽ icon hay dùng emoji.
- Màu, spacing, font, bo góc lấy từ `lib/core/theme`, không hard-code rải rác.
- Số tiền không tính bằng `double`; định dạng tiền và ngày bằng `Intl` locale `vi-VN`.
- Không log dữ liệu nhạy cảm (số tài khoản, số dư, token, thông tin cá nhân).
- Xem thêm `CLAUDE.md` cho các quy tắc đầy đủ khi làm việc cùng AI.

## Tài liệu

Thiết kế và đặc tả nằm trong [`docs/`](docs), ví dụ:

- [`docs/superpowers/specs/`](docs/superpowers/specs) – thiết kế dữ liệu thật, trợ lý AI, bắt thông báo ngân hàng
- [`docs/superpowers/plans/`](docs/superpowers/plans) – kế hoạch triển khai
- [`docs/admin-pages-spec.md`](docs/admin-pages-spec.md) – đặc tả trang quản trị

## Nhóm thực hiện

Nhóm Capstone: Tuấn, Thiên, Thọ, Tùng.

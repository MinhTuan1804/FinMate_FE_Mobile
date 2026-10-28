# PROMPT: Tạo toàn bộ màn hình app di động quản lý tài chính cá nhân "FinMate"

> Dán toàn bộ nội dung bên dưới cho AI. Có thể thay tên app, công nghệ và màu sắc ở phần 1–3.

---

## 0. Vai trò và mục tiêu

Bạn là Senior Mobile Engineer + UI/UX Designer. Hãy xây dựng **toàn bộ các màn hình** của một app di động quản lý tài chính cá nhân cho người Việt, tên **FinMate**. App giúp người dùng: ghi chép thu chi (nhập tay, nhập bằng câu tự nhiên/AI, giọng nói, quét hóa đơn), theo dõi số dư nhiều ví/ngân hàng, đặt ngân sách, tiết kiệm theo mục tiêu, xem báo cáo, và được "game hóa" bằng linh vật Finny.

Làm theo thứ tự: (1) đề xuất cấu trúc thư mục và điều hướng, (2) viết design system và component dùng chung, (3) lần lượt từng màn hình ở phần 5. Mỗi màn hình phải chạy được, có dữ liệu mẫu tách riêng (mock), đủ trạng thái loading/empty/error, không để nút chết.

## 1. Công nghệ (thay nếu cần)

- Flutter 3, Dart 3, Material 3. Quản lý state: Riverpod (`StateNotifier` + `AsyncValue`). Điều hướng: go_router (có `redirect` theo trạng thái đăng nhập). HTTP: Dio + interceptor tự refresh token. Lưu token: flutter_secure_storage. CSDL offline: Drift (SQLite). Biểu đồ: fl_chart. Định dạng: intl (`vi_VN`).
- Kiến trúc theo feature: `features/<tên>/{domain,data,presentation}`; `core/{theme,network,database,format}`.
- Icon: **chỉ dùng một bộ thư viện** (lucide_icons_flutter). Cấm emoji làm icon, cấm tự vẽ SVG.

## 2. Design system (bắt buộc dùng token, không hard-code)

- Phong cách "Neo-Fintech tối giản", ưu tiên **dark mode OLED** nhưng phải hỗ trợ cả light mode.
- Token màu: primary (xanh dương), safe (xanh lá), warning (vàng), danger (đỏ), income (xanh lá), expense (đỏ cam), nền/bề mặt/viền cho cả sáng và tối, chữ chính/phụ/mờ. Đạt tương phản WCAG AA.
- Typography: một font (Plus Jakarta Sans hoặc tương đương, phải đóng gói trong `pubspec`), các cấp h1/h2/h3/body/caption; **số tiền dùng tabular figures** để không nhảy hàng.
- Spacing theo bội số 4/8; bo góc: medium 12, large 16–20, pill cho nút chính. Tránh "AI slop": không gradient tím-xanh mặc định, không card lồng card, không lorem ipsum, không số liệu bịa trong code chạy thật.
- Component dùng chung: `AppButton` (primary/secondary/danger, trạng thái loading), `AppTextField` (nhãn, lỗi, ẩn/hiện mật khẩu), `MoneyField` (nhập số tiền, tự thêm dấu chấm nghìn), `MoneyText`, `EmptyState`, `ErrorState` (có nút Thử lại), `SectionHeader`, `StatCard`, `BudgetGauge` (3 màu), `CategoryChip`, `AccountTile`, `TransactionTile`, `ConfirmDialog`, `BottomSheetScaffold` (tự né bàn phím), `AppScaffold` có thanh điều hướng dưới.
- Mọi tiền tệ hiển thị dạng `150.000 ₫`; ngày `dd/MM/yyyy`; nhóm giao dịch theo ngày **giờ địa phương**.

## 3. Quy tắc chung cho mọi màn hình

1. **Trạng thái:** loading (skeleton/spinner), empty (có minh họa + nút hành động), error (thông điệp thân thiện tiếng Việt + Thử lại), disabled, và offline (banner "Đang ngoại tuyến").
2. **Form:** validate ngay khi rời ô, thông báo lỗi tiếng Việt cụ thể, khóa nút khi đang gửi, chống bấm đúp, đóng bàn phím khi cuộn/gửi.
3. **Số tiền:** số nguyên VND, **không dùng float**; chặn 0/âm/chữ; tối đa 999.999.999.999 ₫.
4. **Lỗi mạng:** phân biệt mất mạng / hết phiên (401) / lỗi nghiệp vụ (hiện thông điệp của server) / lỗi 5xx. Không nuốt lỗi thành dữ liệu giả.
5. **Accessibility:** vùng chạm ≥ 48dp, nhãn `Semantics` cho icon-only button, hỗ trợ cỡ chữ lớn không tràn, không chỉ dùng màu để truyền đạt trạng thái (kèm icon/chữ).
6. **Bảo mật:** không log số dư/token/thông tin cá nhân; ẩn số dư khi app vào nền (tùy chọn); token chỉ lưu secure storage.
7. **Điều hướng:** thanh dưới 5 tab luôn hiển thị ở các màn chính: Trang chủ, Sổ thu chi, Kế hoạch, Phân tích, Cá nhân; chuyển tab không chồng màn hình; nút Back xử lý đúng khi không còn gì để pop.

## 4. Sơ đồ điều hướng

```
Splash ─┬─ (chưa đăng nhập) Welcome ─┬─ Đăng nhập ─┬─ Quên mật khẩu → Đặt lại mật khẩu
        │                            └─ Đăng ký → Xác thực OTP → (Đăng nhập)
        └─ (đã đăng nhập) Onboarding (nếu thiếu thu nhập) → Shell 5 tab
Shell: [Trang chủ] [Sổ thu chi] [Kế hoạch] [Phân tích] [Cá nhân]
  Trang chủ → Thông báo, Chi tiết tài khoản, Ghi chép nhanh (bottom sheet)
  Sổ thu chi → Chi tiết giao dịch → Sửa giao dịch; Tìm kiếm/Lọc
  Ghi chép (sheet 4 tab) → Xem trước AI → Xác nhận
  Kế hoạch → Ngân sách, Mục tiêu tiết kiệm → Chi tiết mục tiêu
  Phân tích → Chi tiết danh mục, Gợi ý (insights)
  Cá nhân → Tài khoản & ví, Danh mục, Tủ đồ linh vật, Nhiệm vụ, Cài đặt (Thông báo, Bảo mật, Dữ liệu, Xóa tài khoản)
```

## 5. Đặc tả từng màn hình

Mỗi mục gồm: **Mục đích · Bố cục · Trường/nút · Quy tắc · Trạng thái · Dữ liệu/API**.

### 5.1 Splash
- Logo + vòng tải. Kiểm tra token trong secure storage rồi gọi lấy hồ sơ. Có token hợp lệ → Shell (hoặc Onboarding nếu chưa có thu nhập); không có → Welcome. Nếu mất mạng nhưng có token: vào Shell ở chế độ ngoại tuyến (dùng dữ liệu cache), không đẩy về Welcome.

### 5.2 Welcome (Chào mừng & điều khoản)
- Logo, tên app, khẩu hiệu. Thẻ "Cam kết Zero-Credential": FinMate không bao giờ hỏi mật khẩu Internet Banking, mã PIN, OTP ngân hàng.
- Checkbox "Tôi đồng ý Điều khoản dịch vụ & Chính sách quyền riêng tư" (hai cụm chữ bấm được mở trang nội dung). Hai nút **Đăng nhập với Email** và **Tạo tài khoản mới** chỉ bật khi đã tick.

### 5.3 Đăng ký
- Trường: Họ và tên (bắt buộc), Email (đúng định dạng), Mật khẩu (≥ 8 ký tự, có chỉ báo độ mạnh), Xác nhận mật khẩu (khớp). Banner Zero-Credential. Nút **Đăng ký tài khoản**; liên kết "Đã có tài khoản? Đăng nhập".
- Thành công → sang OTP. Lỗi (email đã tồn tại, mật khẩu yếu) hiện ngay dưới form với thông điệp của server, **không** chuyển màn khi lỗi. API: `POST /auth/register`.

### 5.4 Xác thực OTP email
- Hiển thị email nhận mã. Ô nhập 6 số (chỉ số, dán được), nút **Xác nhận**; đếm ngược 60 giây rồi mới cho **Gửi lại mã**; khi đến từ đăng nhập (email chưa xác thực) thì gửi mã ngay lúc vào màn.
- Không tự gửi khi đủ 6 số; chống gửi đúp. Sai mã → hiện "Mã không hợp lệ hoặc đã hết hạn". Thành công: nếu server cấp token thì vào app, không thì về Đăng nhập với email điền sẵn và thông báo "Email đã được xác thực". API: `POST /auth/verify-email`, `POST /auth/resend-verification` (trả 204 rỗng: coi là thành công).

### 5.5 Đăng nhập
- Email, Mật khẩu (ẩn/hiện), nút **Đăng nhập**, liên kết **Quên mật khẩu?**, "Chưa có tài khoản? Đăng ký". Tùy chọn đăng nhập Google.
- Thông báo (banner xanh) khi vừa xác thực email hoặc phiên hết hạn; lỗi (banner đỏ) hiển thị thông điệp server ("Email hoặc mật khẩu không đúng"). Email chưa xác thực (`AUTH_EMAIL_NOT_VERIFIED`) → chuyển sang OTP. Đăng nhập xong: chưa có thu nhập → Onboarding, có rồi → Trang chủ. API: `POST /auth/login` (chỉ trả token) rồi `GET /users/me`.

### 5.6 Quên mật khẩu / Đặt lại mật khẩu
- Bước 1: nhập email → "Nếu email tồn tại, chúng tôi đã gửi mã". Bước 2: nhập mã + mật khẩu mới + xác nhận. Sau khi xong về Đăng nhập. API: `POST /auth/forgot-password`, `POST /auth/reset-password`.

### 5.7 Onboarding (3 bước, có thanh tiến độ, có "Bỏ qua" ở bước 1–2)
1. **Tự động ghi nhận:** giải thích đọc thông báo biến động số dư; hai thẻ quyền (Truy cập thông báo, Tắt tối ưu pin) mỗi thẻ có nút mở cài đặt hệ thống và hiển thị đã cấp/chưa cấp.
2. **Chọn nguồn theo dõi:** danh sách ngân hàng/ví lấy từ server (MB Bank, Vietcombank, MoMo, VNPay, ZaloPay…), mỗi mục có công tắc. Mỗi ứng dụng chỉ theo dõi một tài khoản.
3. **Kế hoạch tài chính:** Thu nhập hàng tháng (bắt buộc, > 0), Ngân sách chi tiêu tháng (tùy chọn), Số dư ví tiền mặt hiện có (cho phép 0). Nút **Hoàn tất & Khám phá**: lưu thu nhập, tạo "Ví tiền mặt", tạo tài khoản cho các nguồn đã chọn, tạo ngân sách tổng; có thể chạy lại an toàn nếu lỗi giữa chừng. API: `PATCH /users/me`, `GET /financial-accounts/providers`, `POST /financial-accounts`, `POST /budgets`.

### 5.8 Trang chủ
- **Header:** lời chào + tên, nút Thông báo (badge số chưa đọc), nút Hồ sơ.
- **Thẻ tổng tài sản khả dụng:** tổng số dư mọi tài khoản, nút ẩn/hiện số dư; hai chỉ số Thu nhập và Chi tiêu của tháng (từ báo cáo). Chưa có tài khoản: hiện `0 ₫` + gợi ý tạo ví.
- **Linh vật Finny:** biểu cảm theo % ngân sách tổng (dưới 70% vui, 70–89% lo lắng, từ 90% hoảng); hiện cấp độ, vật phẩm đang mặc, lời thoại; chạm để xem mẹo.
- **Lối tắt:** Ghi chép, Kế hoạch, Báo cáo, Lịch sử.
- **Giao dịch gần đây:** 4 giao dịch mới nhất + "Xem tất cả". Trống: "Chưa có giao dịch nào".
- Kéo để làm mới. Sau khi ghi giao dịch, số dư/báo cáo/ngân sách/điểm kinh nghiệm phải được tải lại. API: `/financial-accounts`, `/reports/monthly-summary`, `/transactions`, `/gamification/*`.

### 5.9 Sổ thu chi (danh sách giao dịch)
- Thanh tìm kiếm + nút bộ lọc; chip nhanh: Tất cả, Chi tiêu, Thu nhập, Chuyển tiền nội bộ.
- Danh sách nhóm theo ngày (tiêu đề ngày + tổng chi/thu trong ngày). Mỗi dòng: icon danh mục, mô tả (hoặc tên danh mục), tên danh mục + tài khoản, số tiền (đỏ có dấu `-`, xanh có dấu `+`; chuyển tiền màu trung tính và nhãn "Nội bộ – không tính chi tiêu"), biểu tượng đám mây gạch chéo nếu chưa đồng bộ.
- Phân trang vô hạn (cursor), kéo để làm mới, vuốt để xóa (có hoàn tác). Nút nổi **Ghi chép mới**.
- **Bộ lọc nâng cao (bottom sheet):** khoảng ngày, tài khoản, danh mục (nhiều lựa chọn), loại, khoảng số tiền; nút Áp dụng/Đặt lại. API: `GET /transactions?type&accountId&categoryId&fromDate&toDate&cursor&limit`.

### 5.10 Ghi chép giao dịch (bottom sheet 4 tab, né bàn phím)
- **Tab AI Text:** ô nhập câu tự nhiên ("Ăn trưa cơm tấm 45k bằng ví tiền mặt"), nút **Phân tích bằng AI** → màn Xem trước. Lỗi (AI không phản hồi) hiện ngay dưới ô, giữ nguyên nội dung, cho phép chuyển sang nhập tay; **không tạo bản xem trước giả**. API: `POST /transactions/parse`.
- **Tab Giọng nói:** nút mic lớn, hiệu ứng sóng khi ghi, hiển thị văn bản nhận dạng để sửa trước khi gửi; xin quyền micro; nếu chưa hỗ trợ thì hiện "Sắp ra mắt".
- **Tab Hóa đơn:** chụp ảnh/chọn thư viện, xem ảnh, nút Quét; kết quả sang màn Xem trước; nếu chưa hỗ trợ thì "Sắp ra mắt". API: `POST /transactions/scan-receipt`.
- **Tab Thủ công:** chip loại (Chi tiêu / Thu nhập / Chuyển tiền); Số tiền (bắt buộc > 0); Danh mục (có icon, tùy chọn) — ẩn khi Chuyển tiền; Tài khoản (hoặc Từ/Đến tài khoản, khác nhau, cần ≥ 2 tài khoản); Ngày giờ (mặc định bây giờ); Ghi chú. Chưa có tài khoản nào: hiện "Bạn chưa có tài khoản" + nút **Tạo ví tiền mặt** (hộp thoại số dư ban đầu, cho phép 0). Lưu → đóng sheet + SnackBar thành công; lỗi hiển thị **ngay trong sheet**. Mất mạng: lưu local, xếp hàng đồng bộ, đánh dấu chưa đồng bộ. API: `POST /transactions`, `POST /transactions/transfer` (kèm `clientRequestId` chống trùng).

### 5.11 Xem trước & xác nhận giao dịch AI
- Banner cảnh báo khi độ tin cậy < 85% hoặc thiếu trường ("AI cần bạn kiểm tra lại một số chi tiết", liệt kê trường thiếu). Khối "Nội dung nhận diện" (văn bản gốc, in nghiêng).
- Có thể sửa: Loại (Chi/Thu), Số tiền, Danh mục (chip; gợi ý của AI có icon sao), Tài khoản, Ghi chú, Ngày. Nút **Xác nhận & Lưu** (lưu giá trị đã rà soát rồi xác nhận), **Hủy bỏ bản nháp**. Mọi giao dịch từ AI/giọng nói/OCR bắt buộc qua màn này. API: `PATCH /transactions/{id}`, `POST /transactions/{id}/confirm`.

### 5.12 Chi tiết & sửa giao dịch
- Hiển thị đầy đủ: số tiền lớn, loại, danh mục, tài khoản (và tài khoản đích nếu chuyển), thời gian, nguồn (Thủ công/Thông báo/Giọng nói/Hóa đơn), số dư sau giao dịch, trạng thái đồng bộ. Nút **Sửa** (form như tab Thủ công), **Xóa** (xác nhận). API: `GET/PATCH/DELETE /transactions/{id}`.

### 5.13 Kế hoạch – tab Ngân sách
- **Thẻ hạn mức chi tiêu hôm nay** = (ngân sách tổng − đã chi) / số ngày còn lại; chip "Còn N ngày"; vượt ngân sách thì đổi sang cảnh báo đỏ "ĐÃ CHI VƯỢT NGÂN SÁCH". Chưa đặt ngân sách: thẻ mời **Tạo ngân sách tháng**.
- **Ngân sách theo danh mục:** thẻ mỗi danh mục có thanh tiến độ 3 màu (xanh < 70%, vàng 70–89%, đỏ ≥ 90%), % và "Đã chi / Hạn mức". Nút **Thêm** (chọn danh mục chưa có ngân sách + hạn mức); chạm thẻ để sửa hạn mức; vuốt để xóa. Trùng danh mục → báo "Bạn đã có hạn mức cho danh mục này". API: `GET/POST /budgets`, `PATCH/DELETE /budgets/{id}`.

### 5.14 Kế hoạch – tab Mục tiêu tiết kiệm
- Danh sách thẻ mục tiêu: tên, thanh tiến độ, Đã tích lũy / Mục tiêu, hạn chót, nhãn trạng thái (Hoàn thành / Trễ hạn / "Cần ~X ₫/tháng" / Không hạn chót), nút **Nạp tiền vào mục tiêu** (vô hiệu khi đã hoàn thành).
- **Tạo mục tiêu:** Tên, Số tiền mục tiêu, Hạn chót (date picker, tùy chọn). **Nạp tiền:** nhập số tiền (> 0), ghi chú; thành công hiện tiến độ mới, và nếu lên cấp/mở khóa vật phẩm thì hiện màn ăn mừng ("Bạn vừa lên cấp N! Mở khóa: …"). Chi tiết mục tiêu: lịch sử nạp, sửa, hủy mục tiêu. API: `GET/POST /saving-goals`, `POST /saving-goals/{id}/contribute`, `PATCH /saving-goals/{id}`, `POST /saving-goals/{id}/cancel`.

### 5.15 Phân tích
- Bộ chọn kỳ (Tháng này / Tuần này / Năm nay; kỳ chưa hỗ trợ hiển thị vô hiệu).
- **Thẻ so sánh** với tháng trước ("Chi tiêu giảm 12,5%", "Bạn đã chi ít hơn X ₫…"), ẩn nếu tháng trước không có dữ liệu.
- **Biểu đồ tròn cơ cấu chi tiêu** theo danh mục + chú giải (tên, %, số tiền); chạm lát/hàng để vào chi tiết danh mục. Trống: "Chưa có chi tiêu tháng này".
- **Dự báo cuối tháng:** đã chi tới nay, dự kiến cuối tháng, so với ngân sách (thanh tiến độ), độ tin cậy, thu nhập tháng, **số dư dự kiến cuối tháng (có thể âm)**, gợi ý cắt giảm mỗi ngày. Thiếu dữ liệu: "Chưa đủ dữ liệu để dự báo".
- **Xu hướng theo ngày:** biểu đồ đường thu/chi. **Gợi ý (insights):** danh sách thẻ cảnh báo/lời khuyên, đánh dấu đã đọc. API: `/reports/monthly-summary`, `/category-breakdown`, `/forecast`, `/timeline`, `/insights`.

### 5.16 Cá nhân (hồ sơ & game hóa)
- Thẻ người dùng: avatar chữ cái đầu, tên, email, nút Sửa hồ sơ (tên hiển thị, thu nhập tháng).
- **Thẻ cấp độ:** "Cấp N", thanh XP `xp / xpCầnChoCấpTiếp`, chuỗi ngày hiện tại / dài nhất.
- **Tủ đồ linh vật Finny:** lưới vật phẩm theo loại (mũ, phụ kiện, nền, trang phục); vật phẩm đã sở hữu chạm để mặc/tháo (mỗi loại một món), chưa sở hữu hiển thị ổ khóa + gợi ý mở khóa ("Đạt level 8").
- **Nhiệm vụ:** hàng ngày/tuần/một lần, tiến độ `x/y`, phần thưởng XP, trạng thái hoàn thành; xem lịch sử.
- Các mục điều hướng: Tài khoản & ví, Danh mục, Cài đặt, Đăng xuất. Đăng xuất: nếu còn giao dịch chưa đồng bộ thì hỏi xác nhận vì sẽ mất; đăng xuất xóa toàn bộ dữ liệu cục bộ và đưa về Welcome.

### 5.17 Tài khoản & ví
- Danh sách tài khoản: tên, loại (Ngân hàng / Ví điện tử / Tiền mặt), nhà cung cấp, số dư, công tắc **Theo dõi**. Tổng cộng ở đầu trang.
- **Thêm tài khoản:** Tên, Loại, Nhà cung cấp (nếu Ngân hàng/Ví), Số dư ban đầu (cho phép 0); mỗi nhà cung cấp chỉ một tài khoản theo dõi. **Sửa/Xóa** (xóa có xác nhận, cảnh báo ảnh hưởng giao dịch). Chi tiết tài khoản: số dư, danh sách giao dịch của tài khoản đó. API: `/financial-accounts`, `/financial-accounts/{id}/balance`, `/monitoring`.

### 5.18 Danh mục
- Danh sách danh mục hệ thống (Ăn uống, Di chuyển, Mua sắm, Hóa đơn, Giải trí, Sức khỏe, Giáo dục, Gia đình, Nhà ở, Thu nhập, Khác) và danh mục do người dùng tạo. Thêm/sửa/xóa danh mục riêng (tên + chọn icon từ bộ icon của app); danh mục hệ thống chỉ xem. API: `/categories`.

### 5.19 Thông báo
- Danh sách thông báo (cảnh báo vượt ngân sách, nhắc nhiệm vụ, gợi ý), phân nhóm hôm nay/trước đó, chưa đọc in đậm, đánh dấu đã đọc, trạng thái trống.

### 5.20 Cài đặt
- **Thông báo:** công tắc Thông báo đẩy, Cảnh báo ngân sách, Nhắc nhiệm vụ (`PATCH /users/me/notification-prefs`).
- **Bảo mật:** khóa app bằng sinh trắc học/PIN, ẩn số dư khi vào nền, Đổi mật khẩu (mật khẩu cũ, mới, xác nhận; `POST /auth/change-password`), Đăng xuất mọi thiết bị.
- **Hiển thị:** Sáng/Tối/Theo hệ thống, ngôn ngữ.
- **Dữ liệu & quyền riêng tư:** xuất dữ liệu, xem điều khoản.
- **Xóa tài khoản:** cảnh báo hậu quả, yêu cầu nhập mật khẩu, xác nhận hai bước (`DELETE /auth/account`).

### 5.21 Màn hình hệ thống
- **Mất kết nối:** banner ngoại tuyến toàn cục, thử lại tự động khi có mạng. **Hết phiên:** đưa về Đăng nhập kèm thông báo (một lần). **Lỗi máy chủ:** màn lỗi chung. **Cập nhật bắt buộc/Bảo trì:** màn chặn thân thiện. **Trang 404 điều hướng.**

## 6. Dữ liệu và hợp đồng API (nếu có backend)

- Phong bì phản hồi: `{success, data, error:{code,message,details}, meta:{cursor}}`; lỗi nghiệp vụ nằm ở `error`; validation có thể có `error.details[{field,message}]`; một số API trả 204 không nội dung.
- Loại giao dịch: `Credit | Debit | Transfer`; số tiền nguyên VND; `transactedAt` ISO UTC; danh mục/tài khoản là UUID. Nếu **không** có backend: dựng lớp `Repository` giao diện + bản `Fake` dùng dữ liệu mẫu nằm trong `test/`/`mock/`, dễ thay bằng API thật.

## 7. Offline-first (giao dịch)

Ghi vào SQLite trước rồi gửi server kèm `clientRequestId`; mất mạng → xếp hàng đồng bộ (FIFO), thử lại tối đa 5 lần, quá số lần thì đánh dấu "lỗi đồng bộ" hiển thị cho người dùng. Chỉ trả cache khi **mất mạng**; lỗi 401/4xx/5xx phải báo cho người dùng. Đăng xuất/đổi tài khoản phải xóa dữ liệu cục bộ.

## 8. Kiểm thử và tiêu chí hoàn thành

- Với **mỗi màn hình**: widget test cho trạng thái loading/empty/error/thành công; test validate form; test không gọi API khi dữ liệu không hợp lệ.
- Test tích hợp chạy nguyên app với backend giả: đăng ký → OTP → đăng nhập → onboarding → ghi giao dịch (số dư cập nhật) → đăng xuất (dữ liệu bị xóa).
- `flutter analyze` không còn cảnh báo, toàn bộ test pass, không còn chuỗi/số tài chính giả trong code chạy thật, không nút chết, không icon ngoài bộ đã chọn.

## 9. Định dạng đầu ra yêu cầu

1. Cây thư mục đề xuất và file điều hướng. 2. Design system + component dùng chung. 3. Với từng mục ở phần 5: danh sách file tạo/sửa, code đầy đủ, test tương ứng, và ghi chú giả định. 4. Cuối cùng liệt kê những gì **chưa làm được/chưa kiểm chứng**. Không viết "tương tự như trên"; mỗi màn hình phải đầy đủ.

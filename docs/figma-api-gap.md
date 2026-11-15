# Đối chiếu Figma với API BE: màn nào còn thiếu API nào

Nguồn đối chiếu:
- Figma: file FinMate, trang "Page 2" (khoảng 77 frame, nội dung chữ đọc ngày 12–13/11/2026).
- BE: các controller người dùng trong `FinMate_BE/backend/FinMate.API/Controllers` (không tính Admin/Ops) và các DTO trong `FinMate.Application`.
- Danh sách mã màn: `docs/screen-map.txt`.

Ký hiệu: ✅ đã có | ⚠️ có nhưng tôi chưa xác minh được chi tiết (tham số lọc, trường dữ liệu) | ❌ chưa có, cần BE làm thêm | 🖥 làm phía app, không cần API.

Giới hạn: tôi đọc danh sách route, DTO và entity, chưa đọc từng handler. Mục ⚠️ cần BE xác nhận.

---

## 0. Đính chính các điều tôi nói trước đây

- `GET reports/monthly-summary` **có** `PrevMonthSpentCents` và `ChangePercent`. Vì vậy "so với tháng trước" của chi tiêu có API. Tôi từng nói là chưa thấy, câu đó sai.
- Chỉ so sánh được **theo tháng**. "+4.2% tuần này" ở B1 và so sánh theo tuần/năm thì chưa có.
- `ForecastSettings` đã có giờ yên lặng, ngưỡng số dư thấp và công tắc cảnh báo dự báo. Có thể dùng cho H4.

---

## 1. Tổng hợp: các nhóm API còn thiếu

| # | Nhóm API thiếu | Màn bị ảnh hưởng |
|---|---|---|
| 1 | Văn bản pháp lý (Điều khoản, Chính sách) kèm phiên bản | A7, H9, H10 |
| 2 | Định danh bằng số điện thoại, OTP SMS, chọn kênh nhận mã | A2, A3, A5, A6, H1, H2 |
| 3 | Hồ sơ mở rộng: ảnh đại diện, ngày nhận lương, đổi email/SĐT | H1, H2, A9 |
| 4 | Hộp thông báo: danh sách, số chưa đọc, đánh dấu đã đọc, xóa | B1, B2 |
| 5 | Báo cáo mở rộng: chuỗi theo ngày/tuần/năm, chi tiết thu nhập theo danh mục, điểm sức khỏe tài chính | F1, F2, F6 |
| 6 | Xuất, sao lưu và nhập dữ liệu | H5, H6, C3, F2 |
| 7 | Khoản vay: CRUD, lịch trả, ghi nhận trả nợ | G1, G9–G11, F3, Sheet trả nợ |
| 8 | Mục tiêu tiết kiệm mở rộng: biểu tượng, tần suất, trích tự động | G2, G3, G4 |
| 9 | Ngân sách mở rộng: ngưỡng riêng theo ngân sách/hũ | G5, G6, B7 |
| 10 | Danh mục mở rộng: loại thu/chi, màu, nhóm cha, thứ tự, yêu thích | H12, H13 |
| 11 | Tài khoản mở rộng: tài khoản mặc định, số tài khoản/chủ tài khoản | H7, H8 |
| 12 | Gói đăng ký mở rộng: tự gia hạn, hóa đơn PDF/VAT | H14, H15 |
| 13 | Hỗ trợ mở rộng: tên chuyên viên, tin chưa đọc, mức ưu tiên | H16, H17 |
| 14 | Nhóm chi tiêu: công nợ, chia hóa đơn, quỹ chung, tìm thành viên, từ chối lời mời, duyệt chi | I1–I7 |
| 15 | QR: "Mã QR của tôi", ghim yêu thích, loại thanh toán hóa đơn | C1, C3, C4, C5 |
| 16 | Định kỳ: nhắc trước hạn, tự tạo giao dịch | G7, G8 |
| 17 | Giao dịch: thẻ (tag), liên kết mục tiêu, ảnh hóa đơn, chia sẻ | D2, E2 |
| 18 | Cộng đồng: huy hiệu xác thực, số người đang online | J1 |

---

## 2. Chi tiết từng màn

### A. Xác thực và khởi đầu

| Màn | Dữ liệu / hành động trên Figma | API đã có | Còn thiếu |
|---|---|---|---|
| **A1** Welcome | Chỉ văn bản tĩnh, 2 nút | – | Không cần |
| **A2** Đăng nhập | Ô "Email hoặc Số điện thoại", mật khẩu, "Ghi nhớ", Google, "Quên mật khẩu?" | ✅ `POST auth/login` (email), ✅ `POST auth/refresh`, ✅ `GET auth/google/start`, `callback`, `POST auth/google/exchange` | ❌ Đăng nhập bằng số điện thoại (User chưa có trường phone). Nút Apple (đã ẩn) ❌ |
| **A3** Quên mật khẩu | Nhập email hoặc SĐT, gửi mã | ✅ `POST auth/forgot-password` (chỉ email) | ❌ Quên mật khẩu bằng SĐT, mã SMS |
| **A4** Đặt lại mật khẩu | Mật khẩu mới, kiểm tra độ mạnh | ✅ `POST auth/reset-password` | ⚠️ Cần xác nhận cơ chế là mã hay token trong email |
| **A5** Đăng ký | Họ tên, email hoặc SĐT, mật khẩu, đồng ý điều khoản, Google | ✅ `POST auth/register` (email, tên, mật khẩu) | ❌ Đăng ký bằng SĐT. Apple ❌ |
| **A6** OTP | 6 số, gửi lại sau 00:48, "nhận mã bằng cách khác" | ✅ `POST auth/verify-email`, ✅ `POST auth/resend-verification` | ❌ OTP SMS, ❌ tham số chọn kênh (email/SMS), ❌ gửi lại mã qua kênh khác. Đếm ngược 🖥 |
| **A7** Đồng ý điều khoản | Tóm tắt, hai liên kết "Xem toàn văn", checkbox | ✅ `POST users/me/consents` (kind `Terms`) | ❌ `GET` nội dung Điều khoản và Chính sách kèm `version`, `updatedAt` |
| **A8** Training AI | Hai công tắc: AI cá nhân hóa, đóng góp dữ liệu ẩn danh | ✅ `POST users/me/consents` (`Ai`, `Training`), ✅ `DELETE users/me/consents/{kind}` | Không thiếu |
| **A9** Thiết lập ban đầu | Thu nhập, ngày nhận lương, chọn nguồn tiền, mục tiêu ưu tiên, chi an toàn dự tính | ✅ `PATCH users/me` (thu nhập), ✅ `GET financial-accounts/providers`, ✅ `POST financial-accounts`, ✅ `GET me/spendable` | ❌ Trường "ngày nhận lương hàng tháng". ⚠️ "Mục tiêu ưu tiên" (kiểm soát chi tiêu / tích lũy / trả nợ) có thể đã nằm trong khảo sát B3 |

### B. Trang chủ và cách quản lý

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **B1** Trang chủ | Tên, tổng số dư, danh sách tài khoản, chi an toàn hôm nay, giao dịch gần đây, "+4.2% tuần này", chuông có chấm đỏ | ✅ `GET users/me`, ✅ `GET financial-accounts`, ✅ `GET me/spendable`, ✅ `GET transactions`, ✅ `GET reports/monthly-summary` | ❌ Số thông báo chưa đọc (cần hộp thông báo). ❌ % thay đổi theo tuần |
| **B2** Thông báo | Tab Tất cả/Biến động/Cảnh báo AI/Hệ thống, đánh dấu đã đọc, xóa tất cả | ✅ `GET forecast/alerts` (cảnh báo AI), ✅ `GET reports/insights` + `PATCH reports/insights/{id}/read`, ✅ `POST devices` (đăng ký push) | ❌ **Hộp thông báo hợp nhất**: `GET notifications` (phân trang, lọc theo loại, kèm `isRead`), `GET notifications/unread-count`, `PATCH notifications/{id}/read`, `POST notifications/read-all`, `DELETE notifications`. Controller hiện chỉ có `POST notifications/analyze` (phân tích thông báo ngân hàng) |
| **B3** Khảo sát | 3 câu hỏi, chọn đáp án | ✅ `GET survey`, ✅ `PUT survey/answers`, ✅ `POST survey/skip`, ✅ `DELETE survey` | Không thiếu |
| **B4** Gợi ý phương pháp | Phương pháp phù hợp nhất (95%), các phương án khác, áp dụng | ✅ `POST finance-methods/recommendations`, ✅ `GET recommendations/latest`, ✅ `POST recommendations/{id}/skip`, ✅ `GET finance-methods`, ✅ `POST me/methods` | ⚠️ Điểm "Phù hợp 95%" có trong DTO hay không |
| **B5** Cách của tôi | Phương pháp đang dùng, các hũ, tiến độ chi, lời khuyên AI | ✅ `GET me/methods`, ✅ `PATCH me/methods/{id}/params`, ✅ `DELETE me/methods/{id}`, ✅ `GET me/jars` | ⚠️ Lời khuyên AI theo hũ (có thể lấy từ `GET reports/insights`) |
| **B6** Chi tiết một hũ | Ngân sách hũ, đã chi, còn lại, danh mục liên kết, giao dịch gần đây, **"Chuyển tiền sang hũ khác"** | ✅ `GET me/jars` (đã chi, còn lại, danh mục) | ❌ "Chuyển tiền giữa các hũ": hũ chỉ là tỷ lệ %, không phải ví chứa tiền, nên cần bỏ nút hoặc đổi thành "chỉnh tỷ lệ" bằng `PATCH me/methods/{id}/params` ✅. ⚠️ Lọc giao dịch theo danh mục thuộc hũ |
| **B7** Ngưỡng theo hũ | Ngưỡng cảnh báo riêng từng hũ, "thông báo khi chi > 500k/lần", "khóa gợi ý mua sắm" | ✅ `GET/PUT/DELETE me/alert-thresholds` (T1, T2 chung toàn người dùng hoặc theo phương pháp) | ❌ Ngưỡng riêng theo từng hũ. ❌ Cảnh báo theo số tiền một lần chi. ❌ "Khóa gợi ý" |

### C. Chuyển khoản QR

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **C1** Quét QR | Camera, đèn flash, chọn ảnh, "Mã QR của tôi", chuyển nhanh gần đây | ✅ `POST qr/counterparties/lookup`, ✅ `GET qr/banks`, ✅ `GET qr/counterparties` | ❌ "Mã QR của tôi" (tạo mã nhận tiền). Camera, flash, ảnh 🖥 |
| **C2** Xác nhận chuyển | Số tiền, người nhận, nguồn tiền, nội dung, danh mục, "Ghi nhận và mở app ngân hàng" | ✅ `POST qr/transfers` (ghi ý định chuyển), ✅ `POST qr/transfers/{id}/cancel`, ✅ `GET qr/banks` | Không thiếu. Lưu ý: FinMate không chuyển tiền thay người dùng |
| **C3** Lịch sử QR | Tổng giao dịch QR tháng, % chuyển khoản/thanh toán hóa đơn, danh sách theo ngày, xuất | ✅ `GET qr/transfers` | ❌ Loại "Thanh toán hóa đơn" (chỉ có chuyển khoản). ❌ Xuất PDF/Excel. ⚠️ Thống kê tháng có thể tính phía app từ danh sách |
| **C4** Người nhận đã lưu | Danh sách, tìm kiếm, chuyển nhanh yêu thích, biệt danh | ✅ `GET qr/counterparties`, ✅ `PATCH qr/counterparties/{id}`, ✅ `DELETE qr/counterparties/{id}` | ❌ Cờ yêu thích/ghim. ❌ "Định kỳ mùng 1" |
| **C5** Sửa người nhận | Tên gợi nhớ, danh mục mặc định, ghim, nhắc hạn mức | ✅ `PATCH`, ✅ `DELETE counterparties/{id}` | ❌ Ghim lên "Chuyển nhanh". ❌ Hạn mức cảnh báo mỗi lần chuyển |

### D. Giao dịch

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **D1** Danh sách | Tổng chi/thu tháng, lọc Tất cả/Chi/Thu/Chuyển, nhóm theo ngày | ✅ `GET transactions`, ✅ `GET reports/timeline` (nhóm theo ngày, có tổng chi/thu mỗi ngày) | ⚠️ Tham số lọc theo loại, tài khoản, danh mục, từ khóa của `GET transactions` |
| **D2** Chi tiết | Chi tiết, danh mục, nguồn tiền, **mục tiêu liên kết**, ảnh hóa đơn, chia sẻ, lặp lại định kỳ | ✅ `GET transactions/{id}`, ✅ `PATCH`, ✅ `DELETE`, ✅ `PUT transactions/{id}/group` | ❌ Liên kết giao dịch với mục tiêu. ❌ Lấy ảnh hóa đơn đã quét. ❌ Chia sẻ giao dịch. ⚠️ Tạo định kỳ từ giao dịch (có `POST recurring-items`) |
| **D3** Chuyển ví | Từ/đến, số tiền, ngày, ghi chú | ✅ `POST transactions/transfer` | Không thiếu (phí chuyển ví không có, bỏ) |
| **D4** Quét hóa đơn | Camera, kết quả trích xuất | ✅ `POST transactions/scan-receipt` | Không thiếu |
| **Sheet** Tạo giao dịch | Số tiền, hạng mục AI gợi ý, nguồn tiền, ghi chú, lưu nháp | ✅ `POST transactions`, ✅ `POST transactions/parse`, ✅ `POST transactions/{id}/confirm` (bản nháp) | Không thiếu |
| **Sheet** Bộ lọc | Khoảng thời gian, loại, nguồn tiền, danh mục | ✅ `GET transactions` | ⚠️ Như D1 |

### E. Trợ lý AI

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **E1** Chat | Gửi chữ, giọng nói, quét bill, thẻ giao dịch đã ghi, dự báo | ✅ `POST transactions/chat`, ✅ `POST chat/analyze`, ✅ `POST chat/analyze-voice`, ✅ `POST agent/ask` | Không thiếu. Nút "Gắn thẻ" ❌ (xem E2) |
| **E2** Xem lại giao dịch AI | Số tiền, danh mục, nguồn, độ chính xác, **thẻ #tag**, ghi chú tự động | ✅ `POST transactions/{id}/confirm`, ✅ `PATCH transactions/{id}` | ❌ Thẻ (tag) cho giao dịch |
| **E3** Bộ nhớ AI | Danh sách ghi nhớ, tab Thu nhập/Chi tiêu/Quy tắc, độ tin cậy, thêm tay, xóa | ✅ `GET agent/memory`, ✅ `PUT agent/memory/{key}`, ✅ `DELETE agent/memory/{key}`, ✅ `DELETE agent/memory` | ⚠️ Phân loại theo tab và "độ tin cậy 99%" có trong dữ liệu hay không |

### F. Phân tích

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **F1** Tổng quan | Tab Ngày/Tuần/Tháng/Năm, tổng thu/chi, % so kỳ trước, biểu đồ cột, cơ cấu chi, gợi ý AI | ✅ `GET reports/monthly-summary` (tháng, kèm `ChangePercent`), ✅ `GET reports/category-breakdown` (tháng), ✅ `GET reports/timeline` (có `fromDate`, `toDate`) | ❌ Chuỗi tổng hợp theo giờ/ngày/tuần/tháng/năm (tính từ timeline được nhưng chậm). ❌ % so kỳ trước cho Ngày/Tuần/Năm và cho **thu nhập**. ❌ Tab "Báo cáo thuế" (không có tính năng này) |
| **F2** Báo cáo danh mục | Donut, danh sách danh mục, so với tháng trước, tab Chi tiêu/Thu nhập, xuất PDF | ✅ `GET reports/category-breakdown` (chỉ chi tiêu), ✅ `monthly-summary` | ❌ Tách theo danh mục cho **thu nhập**. ❌ Xuất PDF |
| **F3** Dự báo dòng tiền | Biểu đồ thực tế + dự báo, số dư cuối tháng, kịch bản 5 triệu | ✅ `GET forecast/cashflow`, ✅ `POST forecast/cashflow/scenario`, ✅ `GET reports/forecast` | ⚠️ Khoảng dự báo 30/60 ngày/quý (tham số). ❌ Mục "trả nợ vay VF5" cần khoản vay |
| **F4** Cảnh báo bất thường | Danh sách cảnh báo, phản hồi hữu ích/không chính xác | ✅ `GET forecast/alerts`, ✅ `POST forecast/alerts/{id}/feedback`, ✅ `GET forecast/anomalies`, ✅ `POST anomalies/{id}/feedback` | Không thiếu |
| **F5** Kiểm tra mua sắm | Tên món, số tiền, nguồn tiền, kết quả "nên cân nhắc", tác động mục tiêu | ✅ `POST forecast/purchase-check` | ⚠️ Chi tiết kết quả (điểm bền vững, tác động mục tiêu). ❌ "Dời lịch mua" |
| **F6** Nhận xét AI | Điểm sức khỏe 82/100, tỷ lệ tiết kiệm, quy tắc 50/30/20, nhận xét, đặt hạn mức tự động | ✅ `GET reports/insights`, ✅ `PATCH insights/{id}/read`, ✅ `GET forecast/categories`, ✅ `POST forecast/categories/apply` | ❌ **Điểm sức khỏe tài chính** và các chỉ số (tỷ lệ tiết kiệm, chi cố định %, chi biến đổi %). ❌ Tải bản tóm tắt |

### G. Kế hoạch

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **G1** Hub | Chi an toàn hôm nay, mục tiêu, ngân sách, định kỳ, **khoản vay**, gợi ý AI | ✅ `GET me/spendable`, ✅ `GET budgets`, ✅ `GET saving-goals`, ✅ `GET recurring-items`, ✅ `GET reports/insights` | ❌ Khoản vay |
| **G2** Danh sách mục tiêu | Tổng tích lũy, lọc Ngắn hạn/Dài hạn/Đã đạt, ghi chú AI | ✅ `GET saving-goals`, ✅ `GET saving-goals/{id}/progress` | ❌ Phân loại ngắn/dài hạn. ⚠️ Trạng thái "đã đạt" có trong `Status` |
| **G3** Tạo mục tiêu | Tên, biểu tượng, số tiền, đã có sẵn, hạn, tần suất gửi, khả thi AI | ✅ `POST saving-goals`, ✅ `POST saving-goals/feasibility`, ✅ `PATCH` | ❌ Trường biểu tượng, "đã có sẵn ban đầu", tần suất gửi, lưu nháp |
| **G4** Chi tiết mục tiêu | Tiến độ, biểu đồ tăng trưởng, lịch sử đóng góp, nạp tiền, trích tự động | ✅ `GET saving-goals/{id}/progress`, ✅ `POST saving-goals/{id}/contribute`, ✅ `POST saving-goals/{id}/cancel` | ❌ Cài đặt trích tự động. ⚠️ Danh sách đóng góp theo mục tiêu |
| **G5** Danh sách ngân sách | Tổng ngân sách, theo danh mục, dự báo vượt | ✅ `GET budgets` (tổng và theo danh mục), ✅ `DELETE budgets/{id}`, ✅ `GET forecast/budgets` | Không thiếu |
| **G6** Thiết lập ngân sách | Phạm vi, hạn mức, chu kỳ, đề xuất AI, mốc cảnh báo | ✅ `POST budgets`, ✅ `PATCH budgets/{id}`, ✅ `POST budgets/transfer` | ❌ Chu kỳ **tuần/tùy chỉnh/theo chuyến** (BE chỉ có Monthly). ❌ Mốc cảnh báo riêng theo ngân sách |
| **G7** Chi phí định kỳ | Danh sách, tổng tháng, đánh dấu đã trả, tạm dừng | ✅ `GET recurring-items`, ✅ `POST {id}/confirm`, `reject`, `pause`, `resume` | Không thiếu |
| **G8** Thêm định kỳ | Tên, số tiền, chu kỳ, ngày, nguồn thanh toán, nhắc trước, tự tạo giao dịch | ✅ `POST recurring-items`, ✅ `PATCH`, ✅ `DELETE` | ❌ Nhắc trước N ngày. ❌ Cờ tự động tạo giao dịch |
| **G9** Danh sách khoản vay | Danh sách khoản vay, dư nợ, kỳ tiếp theo | ❌ | ❌ `GET loans` |
| **G10** Thêm/sửa khoản vay | Tên, tiền gốc, lãi suất, kỳ hạn, ngày trả | ❌ | ❌ `POST loans`, `PATCH loans/{id}`, `DELETE loans/{id}` |
| **G11** Chi tiết khoản vay | Lịch trả, tiến độ, dư nợ | ❌ | ❌ `GET loans/{id}`, `GET loans/{id}/schedule` |
| **Sheet** Ghi nhận trả nợ | Kỳ 14/36, gốc/lãi, số tiền thực chi, nguồn trả | ❌ | ❌ `POST loans/{id}/payments`; tự ghi một giao dịch chi ✅ (`POST transactions`) |

### H. Hồ sơ và cài đặt

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **H1** Cài đặt | Tên, PRO, thu nhập, các hàng cài đặt, công tắc thông báo, đăng xuất | ✅ `GET users/me`, ✅ `PATCH users/me`, ✅ `PATCH users/me/notification-prefs`, ✅ `GET subscriptions/me`, ✅ `POST auth/logout`, ✅ `POST auth/logout-all` | ❌ Số điện thoại, ảnh đại diện trong hồ sơ |
| **H2** Sửa hồ sơ | Tên, SĐT, email, thu nhập, ngày nhận lương, "bảo mật 2 lớp" | ✅ `PATCH users/me` (tên, thu nhập) | ❌ Đổi email, đổi SĐT, ảnh đại diện, ngày nhận lương, xác thực 2 lớp |
| **H3** Giao diện | Sáng/Tối/Hệ thống, ẩn số dư, cỡ chữ | 🖥 lưu trên máy | Không thiếu |
| **H4** Ngưỡng cảnh báo | Hai mức, thông báo đẩy, báo cáo cuối ngày 21:00, giao dịch lớn > 2 triệu, âm thanh | ✅ `GET/PUT/DELETE me/alert-thresholds`, ✅ `PATCH users/me/notification-prefs`, ✅ `GET/PUT me/forecast-settings` (giờ yên lặng, ngưỡng số dư thấp) | ❌ Giờ gửi báo cáo cuối ngày. ❌ Cảnh báo giao dịch lớn (số tiền ngưỡng) |
| **H5** Sao lưu và xuất | Xuất theo khoảng thời gian, định dạng Excel/PDF/CSV/JSON, sao lưu Google Drive | ❌ | ❌ `POST me/exports` (format, khoảng ngày, tài khoản), `GET me/exports/{id}` (tải file). Sao lưu lên Google Drive: nên làm phía app, không phải API BE |
| **H6** Nhập dữ liệu | Chọn ngân hàng, tải tệp, khớp cột, loại trùng | ❌ | ❌ `POST me/imports` (upload CSV/XLSX), xem trước và ánh xạ cột, xác nhận nhập, chống trùng theo mã tham chiếu |
| **H7** Tài khoản và nguồn tiền | Tổng tài sản, danh sách tài khoản, mặc định, cập nhật số dư | ✅ `GET financial-accounts`, ✅ `PATCH financial-accounts/{id}`, ✅ `PATCH {id}/monitoring`, ✅ `GET {id}/balance`, ✅ `DELETE {id}` | ❌ Cờ "tài khoản mặc định" |
| **H8** Thêm tài khoản | Loại, ngân hàng, số tài khoản, tên chủ tài khoản, số dư ban đầu, mặc định, đồng bộ | ✅ `POST financial-accounts` (tên, loại, nhà cung cấp, số dư ban đầu), ✅ `GET financial-accounts/providers` | ❌ Số tài khoản, tên chủ tài khoản. ❌ Loại "Thẻ tín dụng" (BE chỉ có Bank, EWallet, Cash). ❌ Mặc định |
| **H9** Điều khoản | Mục lục, nội dung, ngày cập nhật | ❌ | ❌ `GET legal/terms` (xem mục 1) |
| **H10** Chính sách bảo mật | Như trên | ❌ | ❌ `GET legal/privacy` |
| **H11** Quyền đồng ý | 5 quyền, ngày đồng ý, thu hồi | ✅ `GET users/me` (cờ từng quyền), ✅ `POST users/me/consents`, ✅ `DELETE users/me/consents/{kind}` | ❌ Ngày đồng ý từng quyền (hiện chỉ có true/false). ❌ "n khảo sát đang chờ" |
| **H12** Danh mục | Tab Chi tiêu/Thu nhập, nhóm, hạn mức, kéo thả thứ tự | ✅ `GET categories` | ❌ Loại thu/chi, nhóm cha, thứ tự sắp xếp (DTO chỉ có tên, slug, icon, hệ thống). Hạn mức ghép từ `GET budgets` ✅ |
| **H13** Thêm/sửa danh mục | Tên, biểu tượng, màu, nhóm cha, hạn mức gợi ý, yêu thích | ✅ `POST categories`, ✅ `PATCH`, ✅ `DELETE` | ❌ Màu, nhóm cha, loại, yêu thích |
| **H14** Gói đăng ký | Gói Pro/Free, giá năm/tháng, tự gia hạn, hoàn tiền 7 ngày | ✅ `GET subscriptions/plans` (giá tháng, giá năm, tính năng), ✅ `GET subscriptions/me`, ✅ `POST subscriptions/web-session`, ✅ `POST billing/web/checkout` | ❌ Tự động gia hạn qua thẻ hoặc Apple ID. ❌ Chính sách hoàn tiền |
| **H15** Lịch sử thanh toán | Phương thức thanh toán, danh sách hóa đơn, PDF, VAT | ✅ `GET subscriptions/orders` (số hóa đơn, gói, chu kỳ, số tiền, trạng thái), ✅ `GET billing/web/orders/{invoice}` | ❌ Thẻ đã lưu. ❌ Tải hóa đơn PDF. ❌ Yêu cầu xuất hóa đơn VAT |
| **H16** Danh sách ticket | Mã, trạng thái, tiêu đề, chuyên viên, tin mới | ✅ `GET support/tickets` (danh mục, trạng thái, tiêu đề, đánh giá) | ❌ Tên chuyên viên phụ trách. ❌ Cờ có tin mới chưa đọc |
| **H17** Tạo ticket | Phân loại, tiêu đề, mô tả, đính kèm, mức ưu tiên | ✅ `POST support/tickets`, ✅ `POST {id}/messages/{messageId}/attachments` | ❌ Mức ưu tiên. ❌ Gửi nhật ký chẩn đoán |
| **H18** Chi tiết ticket *(chưa có trong Figma)* | Hội thoại, đính kèm, đóng, đánh giá | ✅ `GET support/tickets/{id}`, ✅ `POST {id}/messages`, ✅ `GET {id}/attachments/{attId}`, ✅ `POST {id}/close`, ✅ `POST {id}/rating` | Không thiếu |
| **H19** Quyền truy cập hỗ trợ *(chưa có trong Figma)* | Duyệt, từ chối, thu hồi, nhật ký | ✅ `GET support/tickets/{id}/access-requests`, ✅ `approve`, `deny`, `revoke`, ✅ `GET support/access-log` | Không thiếu |
| **H20** Đổi mật khẩu | Mật khẩu hiện tại/mới, đăng xuất thiết bị khác | ✅ `POST auth/change-password`, ✅ `POST auth/logout-all` | Không thiếu |
| **H21** Xóa tài khoản | Hậu quả (số giao dịch, tài khoản, gói Pro), xác nhận | ✅ `DELETE auth/account` | ❌ Tóm tắt dữ liệu sẽ mất (số giao dịch, danh mục, tài khoản liên kết). ⚠️ Tham số xác nhận (gõ chữ hoặc mật khẩu) |

### I. Nhóm chi tiêu chung

Backend đã có phần nhóm, thành viên, giao dịch, ngân sách, mục tiêu, danh mục và quy tắc chia sẻ. Phần Figma đang **tưởng tượng thêm** công nợ, chia hóa đơn và quỹ ví chung.

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **I1** Danh sách nhóm | Tổng kết tháng, phần cần đóng, cần thanh toán, lọc loại nhóm | ✅ `GET groups` | ❌ Công nợ/phần cần đóng, "Thanh toán ngay". ❌ Số dư quỹ chung |
| **I2** Tạo nhóm | Tên, loại, biểu tượng, loại quỹ, duyệt giao dịch lớn | ✅ `POST groups` (tên, loại) | ❌ Mô hình "quỹ chung/chia hóa đơn". ❌ Ảnh/biểu tượng nhóm. ❌ Duyệt giao dịch lớn |
| **I3** Chi tiết nhóm | Quỹ, giao dịch, ngân sách, mục tiêu, báo cáo, cấn trừ nợ | ✅ `GET groups/{id}`, ✅ `GET groups/{id}/transactions`, `budgets`, `goals`, ✅ `GET reports/monthly`, ✅ `POST goals/{id}/contribute` | ❌ Cấn trừ nợ giữa thành viên. ❌ "Chia tiền bill mới" (split bill) |
| **I4** Thành viên | Danh sách, vai trò, nợ, nhắc nợ | ✅ `GET groups/{id}/members`, ✅ `PATCH members/{userId}`, ✅ `DELETE members/{userId}` | ❌ Số nợ giữa thành viên, "nhắc nợ". ⚠️ Vai trò khác tên: BE là Owner/Manager/Member/Viewer, Figma là Trưởng nhóm/Thủ quỹ/Thành viên |
| **I5** Mời thành viên | Liên kết mời, mã QR, vai trò, tìm theo SĐT/FinMate ID, thu hồi | ✅ `POST groups/{id}/invitations` (email, vai trò, có token), ✅ `GET invitations`, ✅ `DELETE invitations/{invitationId}` | ❌ Tìm người theo SĐT hoặc FinMate ID, danh bạ. ❌ Thu hồi tất cả một lần. Liên kết/QR dựng từ token 🖥 |
| **I6** Nhận lời mời | Xem trước nhóm, chấp nhận, từ chối, nguồn tiền mặc định | ✅ `POST group-invitations/preview`, ✅ `POST group-invitations/accept` | ❌ Từ chối lời mời. ❌ Quỹ chung hiện có trong xem trước. ❌ Chọn nguồn tiền mặc định khi tham gia |
| **I7** Cài đặt nhóm | Thông tin, ngân sách, cảnh báo, chuyển chủ, rời nhóm, giải tán | ✅ `PATCH groups/{id}`, ✅ `PUT groups/{id}/alerts`, ✅ `GET/POST/DELETE share-rules`, ✅ `POST transfer-ownership`, ✅ `POST leave`, ✅ `DELETE groups/{id}` | ❌ Ngày chốt sổ. ❌ Phương thức cấn trừ. ❌ Phê duyệt giao dịch lớn. ❌ Báo cáo tuần. ❌ Xuất sao kê nhóm |

### J. Cộng đồng

| Màn | Dữ liệu / hành động | API đã có | Còn thiếu |
|---|---|---|---|
| **J1** Bảng tin | Chủ đề, bài viết, bình chọn, địa điểm, huy hiệu, "2.4k đang online" | ✅ `GET community/posts`, `topics`, `places`, `regions`, ✅ `PUT posts/{id}/vote`, ✅ `GET community/share-prompt` | ❌ Huy hiệu "Được xác thực / Chuyên gia" (tác giả chỉ có ẩn danh và tên). ❌ Số người đang online |
| **J2–J6** | Chi tiết bài, bình luận, đăng bài, địa điểm, hồ sơ cộng đồng | ✅ `GET posts/{id}`, `comments`, `POST posts`, `images`, `report`, ✅ `GET/PATCH community/me`, ✅ `GET places/{id}` | Không thiếu |

### K. Widget Android

Không cần API riêng. Widget dùng dữ liệu app đã tải: `GET me/spendable`, `GET budgets`, `GET reports/forecast`, `GET transactions`, `GET financial-accounts`. Cập nhật qua push (`POST devices` ✅).

---

## 3. Việc nên làm trước (đề xuất)

1. **Quyết định bỏ hay giữ** các tính năng chỉ có trên Figma mà BE chưa có: Báo cáo thuế (F1), chuyển tiền giữa hũ (B6), công nợ/chia hóa đơn/quỹ ví nhóm (nhóm I), huy hiệu cộng đồng (J1), tự gia hạn bằng thẻ (H14).
2. **BE ưu tiên làm** (nhiều màn phụ thuộc): văn bản pháp lý (A7, H9, H10), hộp thông báo (B1, B2), xuất/nhập dữ liệu (H5, H6), khoản vay (G9–G11).
3. **Thiếu một phần, sửa nhỏ ở BE:** danh mục (loại, màu, nhóm cha), tài khoản (mặc định, số tài khoản), mục tiêu (biểu tượng, tần suất), hồ sơ (ngày nhận lương, ảnh đại diện).
4. **Định danh bằng số điện thoại và OTP SMS:** bạn đã nói đang phát triển, nên cần BE chốt contract trước khi FE làm.

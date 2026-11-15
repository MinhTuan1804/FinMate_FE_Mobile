# Yêu cầu API cho BE (từ thiết kế Figma FinMate)

Bản rút gọn của `docs/figma-api-gap.md`. Chỉ liệt kê API **còn thiếu**. Các API khác đã có và đủ dùng.
Ký hiệu: **P1** cần sớm (nhiều màn phụ thuộc) | **P2** thiếu một phần, sửa nhỏ | **Chưa cần làm bây giờ** (để sau hoặc chưa chắc giữ trong thiết kế).

---

## P1: cần sớm

**1. Văn bản pháp lý** (A7, H9, H10)
- `GET legal/terms` và `GET legal/privacy`: trả `{ version, updatedAt, sections[{title, body}] }`.
- Gắn với phiên bản consent hiện có (`ConsentVersions`).

**2. Số điện thoại và OTP SMS** (A2, A3, A5, A6, H1, H2)
- Thêm trường `phone` cho User, xác thực số điện thoại.
- Đăng ký, đăng nhập, quên mật khẩu chấp nhận email **hoặc** số điện thoại.
- Gửi OTP theo kênh người dùng chọn (`channel = email | sms`), có "gửi lại qua kênh khác".

**3. Hộp thông báo** (B1, B2)
- `GET notifications` (phân trang, lọc `type = balance | ai_alert | system`, có `isRead`).
- `GET notifications/unread-count`, `PATCH notifications/{id}/read`, `POST notifications/read-all`, `DELETE notifications`.
- Gộp từ `forecast/alerts`, `reports/insights` và thông báo biến động số dư.

**4. Xuất, sao lưu và nhập dữ liệu** (H5, H6; C3, F2 cũng cần xuất)
- `POST me/exports` (`format`: xlsx/csv/pdf/json, khoảng ngày, danh sách tài khoản), `GET me/exports/{id}` (tải file).
- `POST me/imports` (upload CSV/XLSX), trả bản xem trước và gợi ý ánh xạ cột, rồi xác nhận nhập. Chống trùng theo mã tham chiếu ngân hàng.

---

## P2: thiếu một phần

| Màn | Bổ sung |
|---|---|
| H12, H13 Danh mục | Trường `type` (thu/chi), `color`, `parentId`/nhóm, `sortOrder`, `isFavorite` |
| H7, H8 Tài khoản | `isDefault`; `accountNumber`, `holderName`; loại `CreditCard` |
| G2–G4 Mục tiêu | `icon`, `initialSavedCents`, tần suất góp, cài đặt trích tự động, phân loại ngắn/dài hạn |
| H2, A9 Hồ sơ | `avatar` (upload), `incomeDay` (ngày nhận lương), đổi email/SĐT |
| F1, F2, F6 Báo cáo | Chuỗi tổng hợp theo giờ/ngày/tuần/năm; % so kỳ trước cho ngày/tuần/năm và cho thu nhập; breakdown **thu nhập** theo danh mục; điểm sức khỏe tài chính (tỷ lệ tiết kiệm, chi cố định %, chi biến đổi %) |
| G7, G8 Định kỳ | `remindDaysBefore`, cờ `autoCreateTransaction` |
| B7, G6 Ngưỡng | Ngưỡng cảnh báo riêng theo hũ / theo ngân sách; cảnh báo theo số tiền một lần chi |
| H4 Thông báo | Giờ gửi báo cáo cuối ngày; ngưỡng giao dịch lớn |
| D2, E2 Giao dịch | `tags[]`; liên kết giao dịch với mục tiêu; `GET` ảnh hóa đơn đã quét |
| C1, C4, C5 QR | "Mã QR của tôi" (tạo mã nhận tiền); cờ yêu thích/ghim cho người nhận |
| H14, H15 Gói | Tải hóa đơn PDF; yêu cầu hóa đơn VAT; (tự gia hạn nếu giữ) |
| H16, H17 Hỗ trợ | Tên chuyên viên phụ trách, cờ có tin mới, `priority` |
| H11 Quyền | Ngày đồng ý/thu hồi từng quyền (hiện chỉ có true/false) |
| H21 Xóa tài khoản | Trả tóm tắt dữ liệu sẽ mất (số giao dịch, danh mục, tài khoản) |

---

## Chưa cần làm bây giờ

Thiết kế có nhưng BE chưa có. FE sẽ bỏ khỏi giao diện nếu không làm:
- **Khoản vay** (G1, G9–G11, F3, sheet trả nợ): `GET/POST loans`, `GET/PATCH/DELETE loans/{id}`, `GET loans/{id}/schedule`, `POST loans/{id}/payments`. Để sau, chưa nằm trong phạm vi đợt này.
- **F1** Báo cáo thuế.
- **B6** Chuyển tiền giữa các hũ (hũ hiện là tỷ lệ %, không phải ví).
- **Nhóm chi tiêu (I1–I7):** công nợ/cấn trừ, chia hóa đơn (split bill), quỹ ví chung, phê duyệt giao dịch lớn, ngày chốt sổ, tìm thành viên theo SĐT/ID, từ chối lời mời.
- **J1** Huy hiệu "xác thực", số người đang online.
- **H14** Tự gia hạn bằng thẻ/Apple ID, hoàn tiền 7 ngày.
- Chu kỳ ngân sách tuần/tùy chỉnh/theo chuyến (BE chỉ có tháng).

---

## Cần BE xác nhận (⚠️)

- `GET transactions` có lọc theo loại, tài khoản, danh mục, từ khóa không (D1, sheet bộ lọc).
- `POST forecast/cashflow` có tham số khoảng dự báo 30/60 ngày/quý không (F3).
- Reset mật khẩu dùng mã hay token trong email (A4).
- Bộ nhớ AI có phân loại theo nhóm và độ tin cậy không (E3).
- Điểm "Phù hợp 95%" của phương pháp gợi ý có trong DTO không (B4).

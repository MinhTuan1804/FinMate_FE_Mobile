# Kế hoạch dùng Stitch để dựng UI/UX mobile FinMate

> Nguồn danh sách màn: `docs/screen-map.txt` (mã A1…J6).
> Phong cách: lấy từ ảnh tham chiếu (Zenvest) – nền trời sương mờ, thẻ kính mờ, nút đen dạng viên thuốc, biểu đồ nét mảnh. Màu dịu, không chói.
> Bảng màu bám theo `lib/core/theme/app_colors.dart` (Serene Liquid Glass) để thiết kế ra là code được ngay, không phải đổi màu lần hai.
> `docs/stitch-prompt-finmate.md` là bản cũ (navy/blue, cấm glass). Dùng lại từ file đó: nội dung từng màn (Phần 2) và dữ liệu mẫu (Phần 3). KHÔNG dùng lại bảng màu và mục "Do NOT use glassmorphism" của nó.

---

## 1. Ngôn ngữ thiết kế rút ra từ ảnh

| Yếu tố | Mô tả | Token trong app |
|---|---|---|
| Nền | Gradient trời sương xanh nhạt, có vệt mây mềm, không trắng thuần | `canvasLightStart/Middle/End` (#DCE7F5 → #E8EFF8 → #F3F6FB) |
| Thẻ | Kính mờ trắng ngà, viền sáng 1px, bo góc lớn (24–32) | `glassFillLight`, `glassBorderLight` |
| Thẻ số dư | Thẻ kính có vệt màu tán sắc pastel (hồng bụi, đào, xanh trời) | `tertiary #E8B2C4`, `accentWarm #F3C6A8`, `secondary #7CA9D6` |
| Nút chính | Viên thuốc đen than, chữ sáng, full width | `primary #111827` |
| Nút phụ | Viên thuốc kính sáng, chữ đen | `surfaceLightSubtle #E6EEF8` |
| Biểu đồ | Cột mảnh, đường cong mảnh, tooltip viên thuốc đen | `chartPalette` |
| Thanh nav | Kính mờ nổi, icon line, tab đang chọn tô đậm và hiện nhãn | – |
| Thu/chi | Chữ nhỏ màu dịu: thu xanh lục, chi đỏ, chuyển khoản xanh thép | `safe #059669`, `danger #DC2626`, `info #42638E` |
| Chữ | Số tiền rất lớn, đậm; nhãn nhỏ xám xanh | `textPrimaryLight`, `textMutedLight` |

Quy tắc "không chói":
- Không trắng thuần `#FFFFFF`, không đen thuần `#000000` làm nền lớn.
- Chỉ 1 màu nhấn bão hòa thấp mỗi màn. Màu cảnh báo chỉ dùng cho trạng thái, không dùng làm nền lớn.
- Không neon, không gradient tím-xanh mặc định, không đổ bóng đậm. Bóng chỉ nhẹ, màu xanh xám.
- Độ mờ kính 55–85% và luôn có phương án nền đặc (Reduce Transparency).
- Tương phản chữ đạt WCAG AA. Không chỉ dùng màu để truyền nghĩa, luôn kèm dấu +/− hoặc icon.
- Icon: một bộ line (Lucide), nét 2px, không emoji.

Dark mode: dùng bộ Obsidian (`backgroundDark #0C1220`, `surfaceDark #151F32`, nhấn `#7CA9D6`).

---

## 2. Điều hướng đề xuất (CẦN BẠN XÁC NHẬN)

Screen-map có 6 tab nhưng thanh nav tối đa 5 mục. Đề xuất:

```
Trang chủ · Giao dịch · [QR giữa] · Kế hoạch · Phân tích
```
- Trợ lý AI: mở từ thanh "Hỏi FinMate" trên Trang chủ và nút nổi.
- Hồ sơ/Cài đặt: mở từ avatar góc phải header Trang chủ.
- Nhóm chung, Cộng đồng: mở từ Cài đặt (hoặc từ Trang chủ, xem screen-map mục "Việc cần chốt").

Nếu app hiện đang dùng nav khác (`lib/features/dashboard/presentation/widgets/app_bottom_nav.dart`), sửa mục này cho khớp trước khi tạo màn.

---

## 3. Quy trình làm việc trên Stitch

### Bước 0 – Chuẩn bị
1. Tạo 1 project Stitch tên "FinMate Mobile", chọn thiết bị Mobile.
2. Tải lên ảnh tham chiếu Zenvest làm ảnh phong cách.
3. Chuẩn bị bộ dữ liệu mẫu cố định (người dùng "Minh Tuấn", số dư, giao dịch) lấy từ `stitch-prompt-finmate.md` Phần 3. Mọi màn dùng chung bộ này để số liệu nhất quán. Dữ liệu chỉ để minh họa thiết kế.

### Bước 1 – Chốt design system bằng 3 màn mẫu (bắt buộc làm trước)
Dán Prompt nền (mục 4), rồi tạo đúng 3 màn: **B1 Trang chủ, F1 Phân tích, H1 Cài đặt**. Đây là 3 màn đại diện cho 3 kiểu bố cục: dashboard, biểu đồ, danh sách cài đặt.
- Xem lại cả sáng và tối.
- Chỉnh bằng prompt tiếp theo cho đến khi hài lòng (độ mờ kính, độ tương phản, cỡ chữ số).
- **Chỉ khi 3 màn này đạt mới tạo các màn còn lại.** Sửa phong cách sau khi đã có 75 màn rất tốn công.

### Bước 2 – Tạo theo lô
Mỗi lô 4–8 màn cùng nhóm, dán prompt nền (hoặc dùng lại cùng phiên) + prompt riêng từng màn (mục 5). Sau mỗi lô: kiểm tra theo checklist mục 6.

Thứ tự lô (khớp mức ưu tiên trong screen-map):

| Lô | Màn | Ghi chú |
|---|---|---|
| L0 | B1, F1, H1 | Màn mẫu chốt phong cách |
| L1 | A1–A9 | Xác thực và khởi đầu |
| L2 | H2–H21 | Cài đặt (nhóm làm trước) |
| L3 | G1–G11 | Kế hoạch, gồm Khoản vay |
| L4 | D1–D4, E1–E3 | Giao dịch và Trợ lý AI |
| L5 | F2–F6, B2–B7 | Phân tích, Thông báo, Cách quản lý |
| L6 | C1–C5 | QR |
| L7 | I1–I7, J1–J6 | Nhóm chung, Cộng đồng (làm sau) |
| L8 | Sheet và dialog | Mục 5.9 |
| L9 | Widget màn hình chính (W1–W4) | Mục 5.10, thiết kế như bề mặt riêng ngoài app |

### Bước 3 – Nối prototype
Nối theo cây cha/con trong `screen-map.txt`. Làm 4 luồng bấm được:
1. Người dùng mới: A1 → A5 → A6 → A7 → A8 → A9 → B1.
2. Ghi giao dịch: B1 → E1 → E2 → D1.
3. Kế hoạch: G1 → G2 → G3 → G4.
4. Cài đặt: B1 (avatar) → H1 → H7 → H8; H1 → H11; H1 → H9/H10.

### Bước 4 – Rà soát và chốt
- Dùng checklist mục 6 cho từng màn. Màn lệch thì sửa bằng prompt, không tạo lại.
- Đánh dấu màn đã chốt trong cột trạng thái ở mục 7.

### Bước 5 – Bàn giao sang code
- Xuất ảnh/HTML từ Stitch làm tham chiếu thị giác, KHÔNG sao chép code của Stitch vào dự án.
- Dựng lại bằng Flutter theo token trong `lib/core/theme/` (màu, khoảng cách, font, bo góc), tái sử dụng widget có sẵn.
- Mỗi màn khi làm code phải chạy các skill UI theo `CLAUDE.md` (`ui-ux-pro-max`, `taste-skill`).
- Màn nào chờ BE (G9–G11, H5, H6, H9, H10) thì làm khung UI trước và nối API sau.

---

## 4. Prompt nền (dán vào Stitch trước tiên)

```
Design a complete mobile app UI (iOS/Android, 390x844, portrait) called "FinMate":
a Vietnamese personal-finance app with an AI assistant. All UI copy is in Vietnamese.
Money is Vietnamese dong, vi-VN format with dot thousands separator and the "₫" sign after
a space, e.g. "55.000 ₫". Never show decimals. Dates dd/MM/yyyy, times HH:mm.

VISUAL STYLE - "Serene Liquid Glass" (follow the attached reference image closely):
- Calm, airy, modern fintech. Soft misty sky-blue gradient canvas with faint cloud shapes.
  Never pure white (#FFFFFF) or pure black (#000000) as a large background.
- Cards are frosted-glass panels: translucent pearl fill (about 72% opacity), 1px light rim,
  large corner radius (24-32), very soft blue-grey shadow only on floating elements.
- The balance card has a subtle iridescent streak (dusty rose, peach, sky blue) like the
  reference, low saturation. This is the ONLY place with multiple accent colors.
- Primary button: full-width pill, deep charcoal (#111827) with light text. Secondary button:
  pill with soft pale-blue fill (#E6EEF8) and dark text.
- Numbers are the hero: very large, bold, tabular digits. Labels small, muted slate (#64748B).
- Charts: thin lines and slim bars, one highlighted bar, a small dark pill tooltip on the
  selected point, soft grid, no heavy fills.
- Bottom navigation: floating frosted pill bar with line icons; selected tab is filled and shows
  its label; a round centre button for QR.
- Easy on the eyes: low saturation everywhere, no neon, no harsh glare, no purple-blue gradient
  backgrounds, no stock people illustrations, no emoji as icons, no card inside a card.

COLOR TOKENS (use only these):
Canvas gradient #DCE7F5 -> #E8EFF8 -> #F3F6FB. Glass fill #F4F7FC at 72%. Subtle fill #E6EEF8.
Primary ink #111827. Sky blue #7CA9D6. Dusty rose #E8B2C4. Warm peach #F3C6A8. Slate blue #42638E.
Text primary #111827, secondary #475569, muted #64748B.
Income/safe #059669. Warning #D97706. Expense/danger #DC2626. Transfer/info #42638E.
Dark mode: canvas #0B111E -> #0F172A -> #152036, surface #151F32, glass #151F32 at 65%,
accent sky blue #7CA9D6, text #F1F5F9, muted #64748B.

TYPOGRAPHY: Plus Jakarta Sans (the app's font; must render Vietnamese diacritics). Display 32/700,
H1 24/700, H2 20/600, Body 16/400, Caption 13/400, Overline 12/700 caps.

LAYOUT: 8-pt grid, 20px side padding, touch targets at least 48px. Icons: one consistent line
set (Lucide style, 2px stroke, 20-24px).

EVERY SCREEN must show where relevant: loading (skeleton), empty, error with "Thử lại",
disabled and focus states. Provide light and dark. Meaning is never color-only: pair color with
"+" / "-" or an icon. WCAG AA contrast.

NO gamification (points, XP, badges, streaks). Do not invent features that are not described.
Use only the sample data given in the prompt; never real personal data.

STRICT CONTENT RULE: use ONLY the buttons, tiles, labels, tabs, account names and numbers that
the prompt of that screen lists. Do NOT add generic fintech items from your own habits (for
example "Top up", "Nạp tiền", "Rút tiền", "Send/Receive", "Pay bills", virtual cards, other
wallets such as MoMo, savings "piggy bank" tiles, percent-change badges). If a screen prompt
lists 4 items, show exactly those 4 with exactly those names. The reference image is for
visual style only, never for content or feature names.
```

---

## 5. Prompt riêng từng nhóm màn

Cách dùng: dán sau Prompt nền. Mỗi dòng là một màn. Nội dung chi tiết từng màn (trường, trạng thái, văn bản) đã có trong `stitch-prompt-finmate.md` Phần 2, tra theo mã S cũ trong ngoặc. Khi trùng, ưu tiên ngôn ngữ thiết kế ở mục 1 và 4.

Mẫu prompt cho một màn:
```
Screen "<tên màn>" (code <mã>). Parent: <màn cha>. Purpose: <mục đích một câu>.
Content: <các khối từ trên xuống>. States: loading, empty, error, <trạng thái riêng>.
Actions: <nút chính>, <nút phụ>. Sample data: <dữ liệu mẫu>.
Keep the Serene Liquid Glass style; light and dark versions.
```

### 5.1 Lô L0 – Ba màn mẫu chốt phong cách
- **B1 Trang chủ**: header "Xin chào, Minh Tuấn" + chuông + avatar; thẻ số dư kính với vệt tán sắc và 2–3 chip tài khoản; hàng ĐÚNG 4 hành động nhanh có tên cố định: "Ghi chép" (mở sheet tạo giao dịch), "Chuyển ví" (chuyển tiền giữa ví của tôi, D3), "Quét hóa đơn" (D4), "Giao dịch" (mở D1). KHÔNG có "Nạp tiền", "Rút tiền", "Quét QR", "Lịch sử" (nút QR đã nằm ở giữa thanh nav); tài khoản mẫu chỉ có "Vietcombank" và "Ví tiền mặt" (không MoMo hay ví khác); thanh "Hỏi FinMate" kèm icon quét/mic; danh sách "Giao dịch gần đây" trong tấm kính trượt lên như ảnh trái. Nav dưới. (S06)
- **F1 Phân tích**: bộ chọn kỳ Ngày/Tuần/Tháng/Năm; thẻ "Thu nhập" và "Chi tiêu" mỗi thẻ có số lớn, % so kỳ trước, biểu đồ cột mảnh có tooltip đen; bảng danh mục bên dưới như ảnh giữa. (S15)
- **H1 Cài đặt**: thẻ người dùng (avatar, tên, thu nhập hàng tháng, nút Sửa); các nhóm hàng cài đặt trong tấm kính (Giao diện, Ngưỡng cảnh báo, Sao lưu, Nhập dữ liệu, Tài khoản, Điều khoản, Chính sách bảo mật, Quyền đồng ý…); 2 toggle; nút Đăng xuất viên thuốc viền. Khớp wireframe 16. (S17)

### 5.2 Lô L1 – A1–A9
- A1 Welcome, A2 Đăng nhập, A3 Quên mật khẩu, A4 Đặt lại mật khẩu, A5 Đăng ký, A6 OTP, A7 Đồng ý Điều khoản (liên kết sang H9/H10), A8 Đồng ý Training AI (công tắc đồng ý/từ chối rõ, nói rõ dữ liệu dùng làm gì), A9 Thiết lập ban đầu (3 bước, nhập thu nhập, chọn nguồn).
- Form: nhãn luôn hiện, lỗi ngay dưới ô, nút chính viên thuốc đen. (S01–S05)

### 5.3 Lô L2 – H2–H21 (Cài đặt)
- H2 Sửa hồ sơ và thu nhập
- H3 Giao diện (3 thẻ xem trước Sáng/Tối/Hệ thống, cỡ chữ, ẩn số dư) (S23)
- H4 Ngưỡng cảnh báo (thanh có 2 tay kéo) (S24)
- H5 Sao lưu và Xuất, H6 Nhập dữ liệu (4 bước) (S25, S26)
- H7 Tài khoản và Nguồn tiền, H8 Thêm/sửa tài khoản (S18)
- H9 Điều khoản, H10 Chính sách bảo mật: dùng chung một mẫu màn đọc văn bản (mục lục chip, tiêu đề đánh số, nội dung placeholder). Không bịa điều khoản pháp lý (S19, S20)
- H11 Quyền đồng ý: danh sách 5 quyền (Điều khoản, AI, Training, Khảo sát AI, Cộng đồng), mỗi quyền có mô tả một dòng, công tắc, ngày đồng ý, cảnh báo khi thu hồi
- H12 Danh mục, H13 Thêm/sửa danh mục (chọn icon từ bộ Lucide, chọn màu từ bảng pastel)
- H14 Gói đăng ký (so sánh gói, gói hiện tại), H15 Lịch sử thanh toán
- H16 Danh sách ticket, H17 Tạo ticket, H18 Chi tiết ticket kiểu chat, H19 Duyệt quyền truy cập của nhân viên hỗ trợ (cho phép / từ chối / thu hồi, kèm thời hạn)
- H20 Đổi mật khẩu, H21 Xóa tài khoản (cảnh báo rõ, nhập xác nhận)

### 5.4 Lô L3 – G1–G11 (Kế hoạch)
- G1 hub với các thẻ kính: Mục tiêu, Ngân sách, Định kỳ, Khoản vay, kèm thẻ "Chi an toàn hôm nay" (S13)
- G2–G4 Mục tiêu: danh sách thẻ có vòng tiến độ, form tạo/sửa có hiển thị "khả thi", chi tiết có biểu đồ tiến độ và nút Nạp tiền (S14)
- G5–G6 Ngân sách: thanh tiến độ xanh/hổ phách/đỏ theo ngưỡng
- G7–G8 Định kỳ: danh sách, trạng thái chờ xác nhận/tạm dừng
- G9–G11 Khoản vay (chờ BE chốt contract): danh sách, thêm/sửa (tên khoản, số tiền gốc, lãi suất, kỳ hạn, ngày trả), chi tiết có lịch trả và tiến độ trả nợ. Dùng trường tạm, ghi chú "chờ BE".

### 5.5 Lô L4 – D1–D4, E1–E3
- D1 Giao dịch nhóm theo ngày; D2 chi tiết/sửa; D3 chuyển ví; D4 quét hóa đơn (khung camera + kết quả)
- E1 Chat kiểu Messenger (nhắn, nói, quét bill trong cùng một thanh nhập); E2 xem lại giao dịch AI trích xuất; E3 Bộ nhớ AI (danh sách ghi nhớ, xóa từng mục, xóa tất cả) (S08, S11, S12)

### 5.6 Lô L5 – F2–F6, B2–B7
- F2 Báo cáo danh mục (donut + danh sách), F3 Dự báo dòng tiền (đường thực tế liền, dự báo nét đứt), F4 Cảnh báo và bất thường (có phản hồi hữu ích/không), F5 Kiểm tra mua sắm (nhập số tiền, kết quả "an toàn/nên cân nhắc"), F6 Nhận xét AI (S16)
- B2 Thông báo; B3–B5 Khảo sát, Gợi ý, Cách của tôi; B6 Chi tiết một cách (tham số, hũ chi tiêu); B7 Ngưỡng cảnh báo

### 5.7 Lô L6 – C1–C5 (QR)
- C1 Quét QR (nền camera tối, khung quét, giữ độ tương phản cao), C2 Xác nhận chuyển khoản, C3 Lịch sử QR, C4 Người nhận đã lưu, C5 Sửa người nhận

### 5.8 Lô L7 – I1–I7, J1–J6 (làm sau)
- Nhóm chung: danh sách, tạo, chi tiết (tab Giao dịch/Ngân sách/Mục tiêu/Báo cáo), thành viên, mời, nhận lời mời, cài đặt nhóm
- Cộng đồng: bảng tin, chi tiết bài, đăng bài, địa điểm, chi tiết địa điểm, hồ sơ cộng đồng (nhắc cần đồng ý Community trước khi đăng)

### 5.9 Lô L8 – Sheet và dialog
Tạo giao dịch, Sửa nháp, Chọn ngân hàng, Bộ lọc giao dịch, Đóng góp mục tiêu, Ghi nhận trả nợ, Xác nhận xóa tài khoản, Phản hồi cảnh báo, Đánh giá ticket, Báo cáo bài viết. Kính mờ, bo góc trên 28, thanh kéo ở trên.

### 5.10 Lô L9 – Widget màn hình chính (W1–W4)

Widget không phải màn trong app: nó nằm trên màn hình chính của điện thoại, nên thiết kế trên khung hình nền (wallpaper) giả lập, tách khỏi 75 màn ở trên. Mã W1–W4 ghi thêm vào `screen-map.txt` (nhóm K).

| Mã | Widget | Kích thước | Chạm vào |
|---|---|---|---|
| W1 | Chi an toàn hôm nay | Nhỏ 2×2 | Mở Trang chủ (B1) |
| W2 | Tổng quan + hành động nhanh | Vừa 4×2 | Nút "Ghi chép" mở sheet tạo giao dịch; nút "Hỏi FinMate" mở Chat (E1) |
| W3 | Bảng tổng hợp | Lớn 4×4 | Từng dòng mở màn tương ứng; mic mở E1 và bắt đầu nghe; quét mở E1 và chọn nguồn ảnh |
| W4 | Màn cấu hình widget và ảnh xem trước trong bộ chọn widget | – | Công tắc "Ẩn số dư", chọn cỡ, "Hoàn tất" |

Phong cách widget (cùng ngôn ngữ Serene Liquid Glass, đã điều chỉnh cho widget):
- Widget không làm mờ nền (blur) thật được như trong app. Thiết kế bằng nền kính ngà đặc 85–92% opacity, viền sáng 1px, bo góc 24–28. Đây là giới hạn của nền tảng, không cố mô phỏng blur.
- Mỗi widget chỉ có 1 con số nổi bật (hero). Chữ tối thiểu 12sp, vùng chạm tối thiểu 48dp.
- Vòng tiến độ ngân sách: xanh lục `#059669` dưới 80%, hổ phách `#D97706` từ 80–100%, đỏ `#DC2626` khi vượt; nền vòng là xanh trời nhạt `#E6EEF8`.
- Theo sáng/tối của hệ thống, mỗi widget thiết kế đủ hai bản.
- Mỗi cỡ thiết kế đủ trạng thái: bình thường, cảnh báo (≥80%), vượt ngân sách, chưa đặt ngân sách ("Đặt ngay"), chưa đăng nhập ("Đăng nhập để xem"), đang cập nhật/dữ liệu cũ ("Cập nhật lúc 14:05"), chế độ riêng tư (số dư hiện "••••••" kèm icon eye-off).
- Dữ liệu mẫu dùng bộ chung: ngân sách tháng 15.000.000 ₫, đã chi 45.000 ₫, số dư 34.955.000 ₫, chi an toàn hôm nay 120.000 ₫.

Prompt cho Stitch (dán sau Prompt nền; thiết kế như bề mặt riêng, KHÔNG nằm trong khung app):
```
Design Android home-screen widgets for FinMate (Material 3 / Glance style), shown on a plain
soft-blue wallpaper mock for context. Same Serene Liquid Glass look as the app but adapted for
widgets: frosted pearl surface at about 88% opacity (no real blur), 1px light rim, corner radius
24-28, soft blue-grey shadow, charcoal #111827 pill buttons, muted slate labels. Follow system
light/dark; deliver both. Vietnamese copy, vi-VN money format.

SMALL 2x2 - "Chi an toàn hôm nay": one big number "120.000 ₫", caption "Chi an toàn hôm nay",
a thin circular ring showing monthly budget used (e.g. 85%). Ring color green below 80%, amber at
80-100%, red when over (then the number becomes "Vượt 320.000 ₫"). Tap opens Trang chủ.

MEDIUM 4x2 - left: "Tổng số dư" with amount and "Đã chi tháng này: 45.000 ₫"; right: the ring;
bottom: two pills "Ghi chép" and "Hỏi FinMate" (sparkles icon).

LARGE 4x4 - everything in MEDIUM, plus a "Dự báo cuối tháng" row (projected spend, small
sparkline, confidence chip Thấp/Trung bình/Cao), the 3 most recent transactions (category icon,
description, signed colored amount: green "+", red "−"), and a footer with two round icon buttons:
mic and scan.

STATES for every size: normal, warning (80%+), over budget, no budget ("Chưa đặt ngân sách" +
"Đặt ngay"), signed out ("Đăng nhập để xem"), stale ("Cập nhật lúc 14:05"), privacy mode
(balances as "••••••" with eye-off icon).

ALSO DESIGN: (1) the widget configuration screen shown when placing the widget: switch "Ẩn số dư",
size preview, button "Hoàn tất"; (2) a widget-picker preview thumbnail for each size.
One hero number per widget, minimum 12sp text, 48dp touch targets. No gamification, no extra
features, only the sample data given.
```

Quy tắc dữ liệu (cho bước code sau này): widget không gọi API trực tiếp; app đẩy dữ liệu ra widget định kỳ và khi có giao dịch mới. Cờ "Ẩn số dư" dùng chung với màn H3 Giao diện. Deep link có sẵn: Trang chủ, Chat, `/assistant`, `/assistant?start=voice`, `/assistant?start=scan`. Sheet Ghi chép cần deep link riêng. App hiện chưa có code widget và chưa cài thư viện widget (ví dụ `home_widget`); sẽ hỏi bạn trước khi cài.

---

## 6. Checklist kiểm tra mỗi màn

- [ ] Đúng phong cách: nền sương, thẻ kính, nút đen viên thuốc, không chói.
- [ ] Chỉ dùng màu trong bảng token, không màu lạ.
- [ ] Chữ đủ tương phản AA, số tiền lớn rõ, định dạng `55.000 ₫`.
- [ ] Có đủ trạng thái: loading, empty, error, disabled, focus.
- [ ] Có bản sáng và tối.
- [ ] Vùng chạm tối thiểu 48px, không icon trơn thiếu nhãn.
- [ ] Màn cha/con khớp `screen-map.txt`, có nút quay lại.
- [ ] Văn bản tiếng Việt đúng dấu, không lorem ipsum, không số liệu thật.
- [ ] Không thêm tính năng ngoài danh sách.

---

## 7. Theo dõi tiến độ

| Lô | Màn | Trạng thái |
|---|---|---|
| L0 | B1, F1, H1 | chưa làm |
| L1 | A1–A9 | chưa làm |
| L2 | H2–H21 | chưa làm |
| L3 | G1–G11 | chưa làm |
| L4 | D1–D4, E1–E3 | chưa làm |
| L5 | F2–F6, B2–B7 | chưa làm |
| L6 | C1–C5 | chưa làm |
| L7 | I1–I7, J1–J6 | chưa làm |
| L8 | Sheet/dialog | chưa làm |
| L9 | Widget W1–W4 | chưa làm |

---

## 8. Rủi ro và cách giảm

| Rủi ro | Cách giảm |
|---|---|
| Stitch lệch phong cách giữa các màn | Luôn dán Prompt nền, tái dùng ảnh tham chiếu, sửa bằng prompt thay vì tạo lại |
| Kính mờ gây khó đọc | Giữ độ mờ 72–85% cho thẻ chứa chữ, kiểm tra tương phản, có phương án nền đặc |
| Stitch tự thêm nút/tính năng lạ (vd. "Nạp tiền", ví MoMo) vì bắt chước ảnh tham chiếu và thói quen app tài chính | Mỗi màn liệt kê tên nút cố định + luật "STRICT CONTENT RULE" trong Prompt nền; ảnh tham chiếu chỉ dùng cho phong cách, ghi rõ trong prompt; thấy tính năng lạ thì sửa bằng một prompt chỉnh, không tạo lại |
| Stitch sinh dữ liệu tài chính bịa | Ép dùng bộ dữ liệu mẫu cố định, ghi rõ "minh họa" |
| Thiết kế vượt khả năng làm trong Flutter | Chỉ dùng bo góc, blur, gradient có sẵn trong Flutter; tránh hiệu ứng khúc xạ phức tạp |
| Màn chờ BE (khoản vay, xuất/nhập, điều khoản) đổi sau | Làm khung UI trước, ghi trường tạm, chỉnh khi có contract |
| Widget không blur được như trong app | Thiết kế bằng nền kính ngà đặc 85–92%, không mô phỏng blur; kiểm tra trên nền màn hình sáng, tối và nhiều màu |
| Quá nhiều màn | Làm theo lô, chốt 3 màn mẫu trước, để Nhóm chung và Cộng đồng sau cùng |

---

## 9. Điểm cần bạn quyết định trước khi bắt đầu

1. Thanh nav dưới: chốt cấu hình ở mục 2 (đề xuất 4 tab + nút QR giữa; Trợ lý mở từ Trang chủ).
2. Nhóm chung (I) và Cộng đồng (J): có nằm trong phạm vi bản mobile này không.
3. Có xuất sang Figma để chỉnh tay sau khi chốt thiết kế trên Stitch không.
4. Có làm dark mode cho mọi màn ngay từ đầu hay chỉ light trước.
5. Widget: chỉ Android hay cả iOS (WidgetKit). Kế hoạch hiện thiết kế kiểu Android; iOS cần thêm bộ kích thước riêng.

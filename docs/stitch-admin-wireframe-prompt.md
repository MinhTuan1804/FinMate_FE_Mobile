# Admin FinMate – Phân tích trang & prompt Wireframe (Stitch)

> Phần 1 là phân tích cần những page nào, mỗi page làm gì, dữ liệu lấy ở đâu (đối chiếu swagger của backend local ngày 26/10/2026). Phần 2 là prompt wireframe để dán vào Stitch. Phần 3 là những điểm cần bạn quyết định.
> Lưu ý: swagger không mô tả cấu trúc response của các API admin (đều để trống) và tôi không có tài khoản Admin để gọi thử, nên **tên trường dữ liệu admin dưới đây là đề xuất, chưa kiểm chứng**. Chỉ tên endpoint, tham số lọc và request body là lấy từ swagger.

---

## PHẦN 1 – PHÂN TÍCH

### 1.1 Danh sách trang đề xuất (11 trang + 1 màn đăng nhập; trang Cấu hình có 3 tab)

| # | Trang | Mục đích | Chức năng chính | Backend hiện có |
|---|---|---|---|---|
| 0 | Đăng nhập Admin | Vào trang quản trị | Email + mật khẩu; chỉ tài khoản vai trò Admin được vào; báo "Không có quyền" nếu là User; đăng xuất | `POST /auth/login` (dùng chung với app) |
| 1 | Dashboard thống kê | Nhìn nhanh sức khỏe hệ thống | Thẻ KPI, biểu đồ theo thời gian, chọn khoảng ngày | Chỉ có `GET /admin/ai-stats?from&to`. Các số liệu khác **chưa có API tổng hợp** |
| 2 | Audit log | Truy vết hành động | Bảng log, lọc theo người dùng / loại sự kiện / khoảng ngày, xem chi tiết, phân trang | `GET /admin/audit-logs?userId&eventType&from&to&cursor&limit` |
| 3 | Quản lý người dùng | Quản lý tài khoản | Tìm kiếm, lọc vai trò / bị khóa / đã xóa, xem chi tiết, **khóa / mở khóa** (kèm lý do), **thêm tài khoản**, đổi vai trò | List, detail, `PATCH lock {isLocked, reason}`, `PATCH role {role, reason}`. **Không có API admin tạo tài khoản** |
| 4 | Phân quyền | Quản lý vai trò | Danh sách quản trị viên, bảng quyền theo vai trò, thăng/hạ quyền có xác nhận và lý do | Chỉ có 2 vai trò: `User`, `Admin` (`PATCH /admin/users/{id}/role`). Chưa có phân quyền chi tiết |
| 5 | Yêu cầu xóa dữ liệu | Xử lý yêu cầu quyền riêng tư của người dùng | Danh sách theo trạng thái, xem chi tiết, hủy yêu cầu | `GET /admin/data-deletion-requests?status`, `POST …/{id}/cancel` |
| 6 | Danh mục | Quản lý danh mục giao dịch dùng chung cho mọi app | Tìm, lọc loại, thêm, sửa (tên, slug, biểu tượng, màu), bật/tắt, sắp xếp thứ tự, xem số giao dịch đang dùng, phiên bản danh mục cho app tải về | `GET/POST/PATCH /admin/categories`, `PATCH …/{id}/activation`. Số giao dịch đang dùng và phiên bản: **chưa có** |
| 7 | Ngân hàng & ví (2 tab) | Tab Nhà cung cấp: danh sách ngân hàng/ví app cho chọn. Tab Định dạng thông báo: cách AI đọc thông báo của từng ngân hàng | Nhà cung cấp: thêm, sửa, bật/tắt. Định dạng: tạo/sửa/nhân bản, thêm trường, mẫu regex, mẫu câu, chạy thử một đoạn thông báo, kiểm tra, kích hoạt, lưu trữ | Nhà cung cấp: `/admin/provider-configs`. Định dạng: AI service `/admin/provider-formats…` (formats, fields, patterns, samples, try, check, clone, activate, archive) |
| 8 | Cấu hình › tab Hệ thống | Thông số chạy toàn hệ thống | Ngưỡng cảnh báo mặc định, phiên bản app tối thiểu / bắt buộc cập nhật, chế độ bảo trì, thông số đồng bộ local-first, bật/tắt tính năng | **Chưa có API nào** (cần BE thêm) |
| 8 | Cấu hình › tab AI | Chỉnh "bộ não" AI không cần deploy lại | Tài liệu cấu hình AI có phiên bản (nháp → xem thử → kích hoạt, về mặc định), luật AI (câu chỉ dẫn, thương hiệu, từ khóa, bộ nhớ hàng hóa), lịch sử và khôi phục, khung "Thử câu" | `/admin/ai-config/documents…`, `/admin/ai-rules/…` (ai-instructions, brands, keywords, item-cache, history/revert, preview, meta) |
| 8 | Cấu hình › tab Rasa | Quản lý riêng Rasa: thông tin, câu mẫu, câu trả lời, bộ nhớ, huấn luyện | Xem trạng thái mô hình; sửa ý định và câu mẫu; sửa mẫu câu trả lời và câu dự phòng; quản lý bộ nhớ (hàng hóa → danh mục, thương hiệu, lịch sử hội thoại, nhập/xuất); huấn luyện lại; chat thử | Phần "bộ nhớ" khớp `ai-rules/item-cache`, `brands`. Rasa có API riêng (đã kiểm tra: `GET /version` 3.6.21, `GET /status` trả `model_file`, `num_active_training_jobs`; còn có huấn luyện, nạp mô hình, phân tích câu). Câu mẫu và câu trả lời là file huấn luyện nên **không có API sửa** |
| 9 | Đồng bộ dữ liệu (local-first) | Theo dõi việc app đẩy dữ liệu offline lên server | Số giao dịch chờ đồng bộ, lỗi và xung đột theo người dùng, lần đồng bộ gần nhất, xem chi tiết, hỗ trợ xử lý | **Chưa có API**: server chỉ thấy giao dịch đã nhận (có `clientRequestId`); số chờ trên máy cần app báo về |
| 10 | Học AI | Hàng đợi dữ liệu để cải thiện AI | Tab Câu chưa hiểu (câu AI không nhận ra → gán ý định, thêm vào câu mẫu), tab Mẫu hóa đơn (xem, gán nhãn, bỏ, xóa mẫu), tab Phản hồi của người dùng | AI service chỉ có ghi: `POST /chat/unclear`, `/bill/samples` (+ `label`, `discard`, `erase`), `/feedback`, `/bill/learn`. **Không có API liệt kê**, cần BE/AI service thêm |
| 11 | Hồ sơ admin | Tài khoản của chính quản trị viên | Đổi mật khẩu, đăng xuất tất cả thiết bị | `POST /auth/change-password`, `POST /auth/logout-all` |

Gợi ý tôi **thêm** so với danh sách của bạn: trang **Yêu cầu xóa dữ liệu** (backend đã có API, liên quan quyền riêng tư người dùng) và **Hồ sơ admin** (nhỏ). Bạn có thể bỏ nếu không cần.
Tôi **không** đưa vào: trang Nhiệm vụ (`/admin/missions`) vì thuộc gamification đã bị loại.

### 1.2 Dashboard cần thống kê những gì

Chia 5 nhóm; mỗi nhóm là một hàng thẻ KPI + biểu đồ. Tất cả lọc theo khoảng ngày (Hôm nay · 7 ngày · 30 ngày · Tùy chọn) và so với kỳ trước.

| Nhóm | Chỉ số | Biểu đồ | Nguồn |
|---|---|---|---|
| **Người dùng** | Tổng người dùng; người dùng mới theo ngày; người dùng hoạt động (DAU / MAU); số tài khoản đang bị khóa; chưa xác thực email | Đường (người dùng mới), thẻ số | Chưa có API tổng hợp; tạm đếm từ `GET /admin/users` |
| **Giao dịch** | Tổng số giao dịch theo kỳ; chia theo nguồn (Thủ công, Thông báo, Giọng nói, Hóa đơn, Chat); chia theo loại (chi, thu, chuyển) | Cột chồng theo ngày, tròn theo nguồn | Chưa có API quản trị; cần BE |
| **AI** | Số lượt gọi (chat, parse, quét hóa đơn, giọng nói); tỷ lệ thành công; độ trễ trung bình; tỷ lệ tự ghi so với cần xác nhận; OCR đọc được / không; độ tin cậy trung bình; lượt lỗi hoặc dự phòng | Đường theo ngày, tròn thành công/lỗi, bảng top câu AI hiểu sai | `GET /admin/ai-stats` (cấu trúc chưa kiểm chứng) |
| **Hệ thống** | Trạng thái dịch vụ: Backend, AI service, OCR service, Rasa, Database (xanh/vàng/đỏ); thời gian phản hồi | Thẻ trạng thái | Chưa thấy endpoint health cho admin |
| **Bảo mật & vận hành** | Đăng nhập thất bại; tài khoản bị khóa gần đây; yêu cầu xóa dữ liệu đang chờ; 10 sự kiện audit mới nhất | Danh sách rút gọn, liên kết sang Audit log và Yêu cầu xóa | `GET /admin/audit-logs`, `data-deletion-requests` |

---

## PHẦN 2 – PROMPT WIREFRAME ADMIN (dán vào Stitch)

```
Create a LOW-FIDELITY WIREFRAME set (not a finished UI) for the ADMIN web console of "FinMate",
a Vietnamese personal-finance app with an AI assistant. Desktop web 1440×900. All labels in
Vietnamese. The admin is for internal staff only.

STYLE OF THE WIREFRAME
- Grayscale only (white, light gray, mid gray, dark gray lines). No brand colors, no photos,
  no gradients. Rectangles, rounded boxes, "X" boxes for charts. Placeholder data only
  ("000", "Nguyễn Văn A", "email@example.com"). No long paragraphs (use gray bars).
- Same layout shell on every page: fixed LEFT SIDEBAR (logo box + menu items with icon boxes),
  TOP BAR (page title, breadcrumb, global date-range picker where relevant, admin avatar menu
  with "Hồ sơ" and "Đăng xuất"), content area on the right. Mark the active menu item.
- Label every screen with a number + name ("01 · Dashboard") and draw arrows for navigation.
- Components kept consistent: data table (header row, 8 gray rows, row actions "⋯", pagination
  "Trang trước / Trang sau" cursor style), filter bar, KPI card (label, big number, small
  delta "▲ 0%"), side drawer for details, confirm dialog, toast.
- Show the states per page in small extra frames: loading (skeleton bars), empty, error with
  [Thử lại], and "Không có quyền" (403) for the whole console.

SIDEBAR MENU (in this order)
 1 Dashboard · 2 Người dùng · 3 Phân quyền · 4 Audit log · 5 Yêu cầu xóa dữ liệu ·
 6 Danh mục · 7 Ngân hàng & ví · 8 Cấu hình (3 sub-tabs: Hệ thống, AI, Rasa) ·
 9 Đồng bộ dữ liệu · 10 Học AI · bottom: Hồ sơ admin, Đăng xuất.

FLOW – draw the pages in this order with arrows between them:

00 ĐĂNG NHẬP ADMIN: centered card with logo box, inputs [Email] [Mật khẩu], [Đăng nhập].
   Error frame "Email hoặc mật khẩu không đúng". Frame "Bạn không có quyền truy cập trang quản
   trị" (when a normal user signs in). Success → 01.

01 DASHBOARD THỐNG KÊ: date-range chips [Hôm nay][7 ngày][30 ngày][Tùy chọn] at top right.
   Five sections stacked, each with a title and a row of KPI cards + 1–2 chart boxes:
   (a) Người dùng: KPI [Tổng người dùng] [Người dùng mới] [Hoạt động DAU/MAU] [Đang bị khóa]
       [Chưa xác thực email]; chart: line "Người dùng mới theo ngày".
   (b) Giao dịch: KPI [Tổng giao dịch] [Chi] [Thu] [Chuyển]; charts: stacked bars "Theo ngày",
       donut "Theo nguồn: Thủ công / Thông báo / Giọng nói / Hóa đơn / Chat".
   (c) AI: KPI [Lượt gọi AI] [Tỷ lệ thành công] [Độ trễ TB] [Tự ghi vs cần xác nhận]
       [OCR đọc được] [Độ tin cậy TB]; charts: line "Lượt gọi theo ngày" with a success/fail
       split, donut "Thành công / Lỗi", small table "Câu AI hiểu sai nhiều nhất" (5 rows).
   (d) Hệ thống: 5 status pills [Backend][AI service][OCR service][Rasa][Database] each with a
       status dot and response time.
   (e) Bảo mật & vận hành: list "10 sự kiện audit mới nhất" with link [Xem tất cả] → 04;
       card "Yêu cầu xóa dữ liệu đang chờ: 0" with link → 05; card "Đăng nhập thất bại: 0".

02 NGƯỜI DÙNG (list): filter bar [Tìm theo tên/email] [Vai trò ⌄] [Trạng thái: Tất cả/Đang
   hoạt động/Bị khóa ⌄] [Hiện tài khoản đã xóa ☐], buttons [Thêm tài khoản] and [Xuất]. Table
   columns: Tên · Email · Vai trò · Trạng thái (badge) · Xác thực email · Ngày tạo ·
   Lần đăng nhập cuối · ⋯. Row menu: Xem chi tiết · Khóa / Mở khóa · Đổi vai trò.
   Frames:
   02a Drawer "Chi tiết người dùng": avatar box, thông tin, trạng thái, số tài khoản tài chính,
       số giao dịch, 5 sự kiện audit gần nhất (link → 04 filtered by this user), buttons
       [Khóa tài khoản] / [Mở khóa] and [Đổi vai trò].
   02b Dialog "Khóa tài khoản": text, required textarea [Lý do], [Hủy] [Khóa]. Same dialog for
       "Mở khóa".
   02c Dialog "Thêm tài khoản": inputs Tên hiển thị, Email, Mật khẩu tạm, Vai trò (User/Admin),
       checkbox "Gửi email mời", [Hủy] [Tạo].
   02d Dialog "Đổi vai trò" (shortcut to 03's confirm).

03 PHÂN QUYỀN: two columns.
   Left: card "Quản trị viên" – table of admins (Tên, Email, Vai trò, Ngày được cấp quyền, ⋯ Hạ quyền)
   and button [Thêm quản trị viên] (search a user, choose role).
   Right: card "Ma trận quyền theo vai trò" – grid with roles as columns (User, Admin) and
   permissions as rows (Xem dashboard, Quản lý người dùng, Khóa / mở khóa, Đổi vai trò,
   Xem audit log, Xử lý yêu cầu xóa dữ liệu, Sửa cấu hình hệ thống, Sửa cấu hình AI) with
   ✓ / – cells (read-only; note "Hiện hệ thống có 2 vai trò").
   Confirm dialog "Đổi vai trò" with required [Lý do] and a warning line when removing the last admin.

04 AUDIT LOG: filter bar [Người dùng] [Loại sự kiện ⌄] [Từ ngày] [Đến ngày] [Áp dụng]
   [Xóa lọc] and [Xuất CSV]. Table: Thời gian · Người thực hiện · Loại sự kiện (badge) · Đối
   tượng · Kết quả · IP · ⋯. Click row → drawer "Chi tiết sự kiện": các trường + khối JSON
   "Trước / Sau" (two gray code boxes), link to the user. Cursor pagination.

05 YÊU CẦU XÓA DỮ LIỆU: tabs/filter by status [Tất cả][Đang chờ][Đã hủy][Hoàn tất]. Table:
   Người dùng · Ngày yêu cầu · Hạn xử lý · Trạng thái · ⋯ [Hủy yêu cầu]. Drawer with the request
   detail and a confirm dialog "Hủy yêu cầu xóa" with reason.

06 DANH MỤC (page riêng): toolbar [Tìm danh mục] [Loại: Tất cả/Chi/Thu ⌄] [Hiện danh mục đã tắt ☐]
   and buttons [Thêm danh mục] and [Đồng bộ sang AI] (pushes the category list to the AI service; show last
   sync time and a success/error toast). Table: Biểu tượng · Tên · Slug · Loại (Chi/Thu) · Số giao dịch đang
   dùng · Thứ tự · Bật/Tắt switch · ✎. Drag handle to reorder. Row ✎ opens a drawer "Sửa danh mục"
   (Tên, Slug, Loại, Biểu tượng picker, Màu, Mô tả) with [Lưu] [Hủy]. Turning a category off shows a
   confirm dialog "Danh mục đang có N giao dịch, vẫn tắt?". Small info card on top: "Phiên bản
   danh mục: v12 · cập nhật lúc 14:05" (apps download this version and keep it offline).
   Empty / loading / error frames.

07 NGÂN HÀNG & VÍ (page riêng, hai tab: [Nhà cung cấp] [Định dạng thông báo]):
   07A Tab "Nhà cung cấp": table (Mã · Tên hiển thị · Package app · Loại Bank/EWallet/Cash ·
       Bật/Tắt switch · ✎), [Thêm nhà cung cấp], checkbox "Hiện đã tắt", dialog form (Mã, Tên hiển
       thị, Package app Android, Loại).
   07B Tab "Định dạng thông báo" (how the AI reads each bank's notification): list of formats
       (Ngân hàng · Phiên bản · Trạng thái Nháp/Đang dùng/Lưu trữ · Cập nhật lúc) with [Thêm định
       dạng] [Nhân bản]. Open one → editor page with 4 sections: "Trường" (table: tên trường,
       kiểu, bắt buộc, ✎ 🗑, [Thêm trường]); "Mẫu nhận diện" (table of patterns with a code box,
       ✎ 🗑, [Thêm mẫu]); "Câu thông báo mẫu" (list of sample notification texts, [Thêm mẫu],
       🗑); "Chạy thử" (big textarea "Dán thông báo ngân hàng" + [Phân tích] → result card showing
       the extracted fields, plus a [Kiểm tra định dạng] button listing warnings). Header buttons:
       [Lưu] [Kích hoạt] [Lưu trữ].

08 CẤU HÌNH (one page, THREE sub-tabs at the top: [Cấu hình hệ thống] [Cấu hình AI] [Rasa]):
   08A Tab "Cấu hình hệ thống": cards with simple label + input + [Lưu]:
       - "Ngưỡng cảnh báo mặc định": two number inputs (Sắp chạm 80%, Vượt 100%).
       - "Phiên bản ứng dụng": [Phiên bản tối thiểu] and [Phiên bản mới nhất] + switch
         "Buộc cập nhật".
       - "Chế độ bảo trì": switch + message textarea shown to users.
       - "Đồng bộ dữ liệu (local-first)": [Chu kỳ đồng bộ nền] (phút), [Số lần thử lại],
         [Thời gian lưu hàng đợi tối đa] (ngày).
       - "Dịch vụ AI": 5 rows [Backend] [AI service] [OCR service] [STT / giọng nói] [Rasa], each
         with status dot, response time, version (Rasa shows model file name and "đang huấn luyện: 0");
         buttons [Tải lại cấu hình OCR] and [Tải lại tri thức OCR] with confirm dialogs.
       - "Tính năng": switches [Chat AI] [Giọng nói] [Quét hóa đơn] [Đọc thông báo ngân hàng].
   08B Tab "Cấu hình AI": left vertical sub-menu, right content:
       1 "Tài liệu cấu hình AI": list of documents (tên, phiên bản đang dùng, cập nhật lúc).
         Open one → editor page: left = text editor box (gray lines), right = panel with
         "Phiên bản" list (v3 đang dùng, v2, v1), buttons [Lưu nháp] [Xem thử] [Kích hoạt]
         [Về mặc định]; "Xem thử" opens a test box (input câu → output AI hiểu thế nào).
       2 "Luật AI": sub-tabs [Câu chỉ dẫn] [Thương hiệu] [Từ khóa] [Bộ nhớ hàng hóa]; each a
         table with switch Bật/Tắt, [Thêm], and a dialog form.
       3 "Thử câu nói": big input + [Phân tích] → result card (ý định, số tiền, danh mục, độ tin
         cậy).
       4 "Lịch sử thay đổi": timeline table (Thời gian · Người sửa · Mục · Thay đổi) with
         [Khôi phục] on each row and a confirm dialog.
   08C Tab "Rasa" (its own tab, left vertical sub-menu, right content):
       1 "Thông tin": status pill (Đang chạy / Lỗi), phiên bản mô hình, ngày huấn luyện gần nhất,
         số intent, số entity, số câu mẫu, địa chỉ dịch vụ (read-only), [Làm mới trạng thái].
       2 "Ý định & câu mẫu": left list of intents (add_expense, ask_summary, …) with count; right
         panel = list of example sentences with [Thêm câu], edit, delete, search, and entity
         highlights shown as gray chips.
       3 "Câu trả lời": table of response templates (Tên · Ý định · Số biến thể · Bật/Tắt · ✎).
         Edit drawer: list of answer variants (text boxes with {số_tiền} {danh_mục} placeholders),
         [Thêm biến thể], preview box "Xem thử câu trả lời", and the fallback answer for when AI
         does not understand ("Mình chưa hiểu, bạn thử lại nhé").
       4 "Bộ nhớ": three cards/sub-tabs: [Hàng hóa → danh mục] (table: Từ khóa/hàng hóa ·
         Danh mục · Số lần dùng · Cập nhật lúc · ✎ 🗑, with search, [Thêm], [Nhập CSV],
         [Xuất CSV], [Xóa toàn bộ] with confirm), [Thương hiệu] (table), [Hội thoại]
         (retention setting "Giữ lịch sử chat N ngày" + button [Xóa bộ nhớ hội thoại] with confirm).
       5 "Huấn luyện": [Huấn luyện lại] button with confirm dialog, progress bar frame, training
         history table (Thời gian · Người chạy · Kết quả · Phiên bản), [Kích hoạt phiên bản] /
         [Quay lại phiên bản trước].
       6 "Thử nghiệm": a small chat box (input + bubble replies) showing the detected intent,
         entities and confidence next to each answer.

09 ĐỒNG BỘ DỮ LIỆU (local-first): top KPI cards [Giao dịch chờ đồng bộ] [Người dùng có hàng đợi]
   [Lỗi đồng bộ 24h] [Xung đột chưa xử lý]; date-range chips. Table by user: Người dùng · Số giao
   dịch chờ · Lần đồng bộ gần nhất · Phiên bản app · Lỗi gần nhất · Trạng thái (badge) · ⋯.
   Drawer "Chi tiết đồng bộ": timeline of attempts (Thời gian tạo trên máy · Thời gian server
   nhận · Kết quả), error message box, buttons [Gửi yêu cầu đồng bộ lại] and [Xem audit log]
   (→ 04 filtered). Frames: empty ("Không có hàng đợi tồn đọng"), error. Info note: "Giao dịch
   offline được dedupe bằng mã yêu cầu của app, gửi lại không tạo trùng."

10 HỌC AI (hàng đợi cải thiện AI), three tabs [Câu chưa hiểu] [Mẫu hóa đơn] [Phản hồi người dùng]:
   - Câu chưa hiểu: table (Câu người dùng · Số lần gặp · Lần cuối · Ý định AI đoán · ⋯). Row action
     [Gán ý định] opens a drawer: dropdown ý định, entity chips, [Thêm vào câu mẫu Rasa] and [Bỏ qua].
     Bulk delete, [Xóa dữ liệu của người dùng] with confirm.
   - Mẫu hóa đơn: grid/table of scanned bill samples (thumbnail X-box, cửa hàng AI đọc, số tiền, danh
     mục AI đoán, độ tin cậy, trạng thái Chưa gán nhãn/Đã gán/Bỏ). Drawer: image X-box on the left,
     form on the right (cửa hàng, tổng tiền, danh mục) with [Gán nhãn] [Bỏ mẫu] [Xóa].
   - Phản hồi người dùng: table (Thời gian · Loại phản hồi 👍/👎 · Nội dung gốc · Kết quả AI · Ghi chú).
   Info note: "Dữ liệu chỉ dùng để cải thiện AI và xóa được theo yêu cầu của người dùng."

11 HỒ SƠ ADMIN: card with name/email, form [Đổi mật khẩu] (mật khẩu cũ, mới, nhập lại), button
   [Đăng xuất tất cả thiết bị] with confirm dialog.

AT THE END add one overview page: a flow map with all page numbers as small boxes and arrows:
00→01; sidebar links 01/02/03/04/05/06/07/08/09/10/11; 01→04 and 01→05 (shortcuts); 02a→04 (filtered);
02→02a/02b/02c/02d; 03→confirm; 07→07A/07B; 08→08A/08B/08C; 10→Rasa câu mẫu (08C). Do not add pages that are not listed.
```

---

## PHẦN 3 – ĐIỂM CẦN BẠN QUYẾT ĐỊNH

1. **Rasa:** đã tách thành **tab riêng** trong Cấu hình (Thông tin, Ý định & câu mẫu, Câu trả lời, Bộ nhớ, Huấn luyện, Thử nghiệm). Backend mới có API cho phần "bộ nhớ" (hàng hóa → danh mục, thương hiệu). Các phần còn lại cần BE thêm API hoặc đọc trực tiếp từ dịch vụ Rasa.
1b. **Danh mục và Ngân hàng & ví:** tách thành hai trang riêng ở sidebar (trước nằm trong tab Hệ thống). Số giao dịch đang dùng và phiên bản danh mục chưa có API.
1c. **Local-first:** đã thêm trang **Đồng bộ dữ liệu**, khung thông số đồng bộ trong tab Hệ thống và dòng "Phiên bản danh mục" ở trang Danh mục. Server chưa có API để biết hàng đợi trên máy: cần app báo trạng thái đồng bộ về (endpoint mới) hoặc chỉ hiện những gì server đã nhận.
2. **Thêm tài khoản:** backend **chưa có API admin tạo tài khoản** (chỉ có đăng ký công khai). Wireframe vẫn vẽ để chốt chức năng; cần BE thêm endpoint hoặc dùng luồng "gửi lời mời".
3. **Phân quyền:** backend chỉ có hai vai trò `User` và `Admin`, nên ma trận quyền chỉ để xem. Phân quyền chi tiết (ví dụ vai trò Hỗ trợ chỉ xem) cần BE bổ sung.
4. **Dashboard:** chỉ nhóm AI có API (`/admin/ai-stats`). Các nhóm người dùng, giao dịch, trạng thái hệ thống cần BE thêm API tổng hợp (hoặc tính tạm phía admin). Cấu trúc response admin chưa kiểm chứng; cần một tài khoản Admin để gọi thử rồi cập nhật tên trường.
5. **Trang tôi thêm vào:** "Yêu cầu xóa dữ liệu" và "Hồ sơ admin". Bỏ nếu bạn không muốn.
6. **Công nghệ admin:** wireframe này vẽ theo web desktop. Cho tôi biết admin xây bằng gì (web riêng hay Flutter Web) nếu muốn tôi bắt đầu code.

---

## PHẦN 4 – KẾT QUẢ RÀ SOÁT API (backend + AI service, 26/10/2026)

Nguồn: swagger của backend (`:8080`), OpenAPI của AI service (`:8000`), và các lời gọi chỉ-đọc tới Rasa, OCR, STT trong mạng docker.

| Nhóm API cần quản lý | Có trong prompt? | Ghi chú |
|---|---|---|
| Backend: users, lock, role, audit-logs, ai-stats, categories, provider-configs, ai-config, ai-rules, data-deletion-requests | Có (trang 01–08) | Khớp danh sách đã làm |
| Backend: `admin/missions` | **Cố ý bỏ** | Thuộc gamification đã loại |
| AI service: `admin/provider-formats` (định dạng thông báo ngân hàng: trường, mẫu, câu mẫu, thử, kiểm tra, nhân bản, kích hoạt, lưu trữ) | **Mới thêm** (07B) | Phần lớn nhất chưa có trong prompt trước |
| AI service: `admin/categories/sync` | **Mới thêm** (nút "Đồng bộ sang AI" ở trang Danh mục) | |
| AI service: `chat/unclear`, `bill/samples`, `bill/learn`, `feedback` | **Mới thêm** (trang 10 Học AI) | Chỉ có API ghi/xóa, **thiếu API liệt kê** |
| OCR service: `admin/reload-knowledge`, `admin/reload-config` | **Mới thêm** (tab Hệ thống › Dịch vụ AI) | |
| Rasa: `/status`, `/version`, huấn luyện, phân tích câu | Đã có ở tab Rasa | Rasa 3.6.21, mô hình `finmate-nlu-v11`; câu mẫu là file huấn luyện nên không sửa qua API |
| STT service: `/transcribe`, `/health` | Chỉ hiện trạng thái | Không có gì để quản lý ngoài sức khỏe |
| Backend: `users/me/consents`, `devices`, `notifications` | Không đưa vào | Là API người dùng; nếu cần admin xem sự đồng ý của người dùng thì thêm sau |

Cần lưu ý thêm:
- `GET /api/v1/health` của AI service trả `"models": {"classifier": null, "categorizer": null}`, nghĩa là hai mô hình này chưa được nạp (có thể là chủ ý). Dashboard nên hiện cờ cảnh báo này.
- Backend và AI service đều có bộ `admin/categories`, `admin/provider-configs`/`provider-formats`, `admin/rules`, `admin/config` song song; backend là cổng cho admin, AI service là nơi lưu thật. Admin nên gọi qua backend và cần xác nhận hai bên đồng bộ.
- Backend có thêm `POST /transactions/voice` và `POST /chat/analyze-voice`, STT service chạy riêng (`/transcribe`).

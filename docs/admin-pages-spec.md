# Đặc tả giao việc – Trang Admin FinMate

> Tài liệu này dành cho **AI agent lập trình** xây trang quản trị (Admin) của FinMate. Nó nói rõ **có bao nhiêu trang, mỗi trang làm gì, gọi API nào, luật nghiệp vụ và tiêu chí hoàn thành**. Không phải tài liệu thiết kế wireframe (wireframe nằm ở `docs/stitch-admin-wireframe-prompt.md`).
> Nguồn dữ liệu API: swagger backend `http://localhost:8080/swagger/v1/swagger.json` và OpenAPI AI service `http://localhost:8000/openapi.json` (rà soát 28/10/2026).

---

## 0. Đọc trước khi làm

### 0.1 Tổng quan: 15 trang

| # | Trang | Route đề xuất | Trạng thái backend |
|---|---|---|---|
| 1 | Đăng nhập Admin | `/login` | Sẵn sàng |
| 2 | Dashboard thống kê | `/` | **Một phần** (chỉ nhóm AI có API) |
| 3 | Quản lý người dùng | `/users` | **Một phần** (thiếu API tạo tài khoản) |
| 4 | Phân quyền | `/roles` | **Một phần** (chỉ có 2 vai trò `User`, `Admin`) |
| 5 | Audit log | `/audit-logs` | Sẵn sàng (cấu trúc response chưa kiểm chứng) |
| 6 | Yêu cầu xóa dữ liệu | `/data-deletion` | Sẵn sàng (cấu trúc response chưa kiểm chứng) |
| 7 | Danh mục | `/categories` | Sẵn sàng; thiếu số giao dịch đang dùng |
| 8 | Ngân hàng & ví (2 tab) | `/providers` | Tab Nhà cung cấp sẵn sàng; tab Định dạng thông báo chỉ có ở AI service |
| 9 | Phương pháp tài chính | `/finance-methods` | Sẵn sàng |
| 10 | Mẫu mục tiêu | `/goal-templates` | Sẵn sàng |
| 11 | Khảo sát | `/survey` | Sẵn sàng |
| 12 | Cấu hình (3 tab: Hệ thống · AI · Rasa) | `/settings` | Tab AI sẵn sàng; tab Hệ thống và Rasa **thiếu API** |
| 13 | Đồng bộ dữ liệu (local-first) | `/sync` | **Chưa có API** |
| 14 | Học AI | `/ai-learning` | **Chỉ có API ghi, thiếu API liệt kê** |
| 15 | Hồ sơ admin | `/profile` | Sẵn sàng |

**Không làm (đã quyết định bỏ):** trang Nhiệm vụ (`/admin/missions`) vì gamification đã bị loại khỏi sản phẩm. API vẫn tồn tại; nếu chủ dự án đổi ý thì làm sau.

### 0.2 Quy ước chung (áp dụng mọi trang)

- **Giao diện:** web desktop (1280–1440 px), có sidebar trái và thanh trên. Toàn bộ chữ tiếng Việt. Tiền định dạng `vi-VN` (`55.000 ₫`), ngày `dd/MM/yyyy HH:mm`, múi giờ người dùng.
- **Công nghệ:** chưa chốt. Agent **phải hỏi chủ dự án** chọn gì (React/Vue/Flutter Web…) trước khi tạo dự án. Không tự cài thư viện lớn khi chưa hỏi.
- **Xác thực:** `POST /api/v1/auth/login` (cùng endpoint với app). Sau đăng nhập gọi `GET /api/v1/users/me` và kiểm tra `role == "Admin"`; nếu không phải Admin thì hiện "Bạn không có quyền truy cập trang quản trị" và xóa token. Token lưu an toàn, **không in token hay mật khẩu ra log**. Dùng `POST /auth/refresh` khi 401, `POST /auth/logout` khi đăng xuất.
- **Phong bì phản hồi:** `{ success, data, error: { code, message, details }, meta }`. Hiển thị `error.message` cho người dùng. Phân trang theo **cursor** (`cursor`, `limit`, con trỏ tiếp theo nằm ở `meta`).
- **Hành động nhạy cảm** (khóa, đổi vai trò, xóa, kích hoạt phiên bản, huấn luyện, đồng bộ): luôn có hộp thoại xác nhận; nếu API có trường `reason` thì **bắt buộc nhập lý do**.
- **Mọi màn phải có trạng thái:** đang tải (skeleton), rỗng, lỗi kèm nút "Thử lại", và 403 (không có quyền). Nút bị khóa khi đang gửi để tránh bấm hai lần.
- **Trợ năng:** có nhãn cho ô nhập, dùng được bằng bàn phím, độ tương phản chuẩn WCAG AA; không dùng màu làm tín hiệu duy nhất.
- **Bảo mật:** không hard-code khóa/token; địa chỉ API đọc từ biến môi trường; không log dữ liệu cá nhân hay số dư; không render HTML thô từ dữ liệu người dùng (chống XSS); mọi thao tác ghi đều đi qua API (không ghi trực tiếp DB).
- **Cấu trúc response admin chưa được kiểm chứng:** swagger không mô tả response của các API admin (để trống) và chưa có tài khoản Admin để gọi thử. Agent phải **xin một tài khoản Admin dev**, gọi từng endpoint, lưu response thật làm fixture trong thư mục test rồi mới viết model. Không đoán tên trường.
- **Kiểm chứng trước khi báo xong:** chạy build, lint, test thật; mỗi trang có test cho trạng thái chính. Dữ liệu giả chỉ để trong thư mục mock/fixture.

### 0.3 Quy ước đọc tài liệu này

- `[API]` là endpoint có thật trong swagger; `[THIẾU]` là chỗ backend chưa có, agent **không tự bịa** mà ghi lại và chờ chủ dự án quyết định (làm tạm phía admin hoặc nhờ backend).
- Tên trường request lấy đúng từ swagger (dấu `*` là bắt buộc).

---

## 1. Đăng nhập Admin (`/login`)

**Mục đích:** cổng vào duy nhất; chỉ vai trò Admin được qua.

**API:** `POST /auth/login` → `GET /users/me` → kiểm tra `role`. `POST /auth/logout`, `POST /auth/refresh`.

**Giao diện:** thẻ giữa màn hình có logo, ô Email, Mật khẩu (nút hiện/ẩn), nút "Đăng nhập".

**Luật & trạng thái:**
- Sai thông tin: hiện thông điệp của server (ví dụ "Email hoặc mật khẩu không đúng.").
- Đăng nhập được nhưng không phải Admin: hiện "Bạn không có quyền truy cập trang quản trị", xóa token.
- Tài khoản bị khóa/chưa xác thực email: hiện đúng `error.message`.
- Hết phiên: tự chuyển về `/login` kèm thông báo "Phiên đăng nhập đã hết hạn".

**Hoàn thành khi:** đăng nhập Admin vào được Dashboard; User thường bị chặn; F5 giữ được phiên; đăng xuất xóa token.

---

## 2. Dashboard thống kê (`/`)

**Mục đích:** nhìn nhanh sức khỏe hệ thống. Bộ lọc khoảng ngày: Hôm nay · 7 ngày · 30 ngày · Tùy chọn; mỗi KPI so với kỳ trước.

**5 nhóm số liệu:**

| Nhóm | Chỉ số | Nguồn |
|---|---|---|
| Người dùng | Tổng, mới theo ngày, DAU/MAU, đang bị khóa, chưa xác thực email | `[THIẾU]` API tổng hợp. Tạm: đếm từ `GET /admin/users?isLocked=…` (ghi rõ là tạm) |
| Giao dịch | Tổng số giao dịch, chia theo loại (chi/thu/chuyển) và theo nguồn (Thủ công, Thông báo, Giọng nói, Hóa đơn, Chat) | `[THIẾU]` |
| AI | Lượt gọi (chat/parse/quét hóa đơn/giọng nói), tỷ lệ thành công, độ trễ TB, tỷ lệ tự ghi so với cần xác nhận, OCR đọc được, độ tin cậy TB | `[API]` `GET /admin/ai-stats?from&to` (response chưa kiểm chứng) |
| Hệ thống | Trạng thái Backend, AI service, OCR, STT, Rasa, Database (xanh/vàng/đỏ + thời gian phản hồi); cờ cảnh báo nếu mô hình `classifier`/`categorizer` chưa nạp | `[THIẾU]` endpoint gộp. AI service có `GET /api/v1/health` (trả `models.classifier`, `models.categorizer`); Rasa có `/status`, `/version`; OCR và STT có `/health` |
| Bảo mật & vận hành | 10 sự kiện audit mới nhất, số yêu cầu xóa dữ liệu đang chờ, đăng nhập thất bại | `[API]` `GET /admin/audit-logs?limit=10`, `GET /admin/data-deletion-requests?status=…` |

**Giao diện:** thẻ KPI (nhãn, số lớn, mũi tên thay đổi %), biểu đồ đường/cột/tròn theo từng nhóm; danh sách rút gọn có liên kết "Xem tất cả" sang Audit log và Yêu cầu xóa.

**Luật:** nhóm nào chưa có API thì hiển thị khung với thông báo "Chưa có dữ liệu" (không bịa số).

**Hoàn thành khi:** nhóm AI và Bảo mật hiển thị dữ liệu thật; các nhóm thiếu API có trạng thái "chưa hỗ trợ" rõ ràng; đổi khoảng ngày làm mới dữ liệu.

---

## 3. Quản lý người dùng (`/users`)

**Mục đích:** tìm và quản lý tài khoản; khóa/mở khóa; thêm tài khoản; đổi vai trò.

**API:**
- `GET /admin/users?search&role&isLocked&includeDeleted&cursor&limit`
- `GET /admin/users/{id}` (chi tiết)
- `PATCH /admin/users/{id}/lock` body `{ isLocked: boolean, reason: string }`
- `PATCH /admin/users/{id}/role` body `{ role: "User"|"Admin", reason: string }`
- Thêm tài khoản: `[THIẾU]` không có endpoint admin tạo tài khoản (chỉ có `POST /auth/register` công khai).

**Giao diện:**
- Thanh lọc: ô tìm tên/email, Vai trò, Trạng thái (Tất cả/Đang hoạt động/Bị khóa), "Hiện tài khoản đã xóa".
- Bảng: Tên · Email · Vai trò · Trạng thái (badge) · Xác thực email · Ngày tạo · ⋯. Phân trang cursor.
- Ngăn chi tiết (drawer): thông tin, trạng thái, số liệu liên quan nếu API trả về, 5 sự kiện audit gần nhất (liên kết sang Audit log lọc theo người dùng), nút Khóa/Mở khóa, Đổi vai trò.
- Hộp thoại Khóa/Mở khóa (bắt buộc `reason`), Đổi vai trò (bắt buộc `reason`), Thêm tài khoản (Tên, Email, Mật khẩu tạm, Vai trò, "Gửi email mời").

**Luật nghiệp vụ:**
- Không cho tự khóa chính mình, không cho hạ quyền chính mình nếu là Admin cuối cùng.
- Sau khi khóa/mở khóa/đổi vai trò: làm mới dòng, hiện toast, và thao tác này xuất hiện trong Audit log.
- Nút "Thêm tài khoản": trong lúc `[THIẾU]`, hiển thị nút bị vô hiệu kèm chú thích "Cần backend bổ sung" (không gọi `register` thay thế).

**Hoàn thành khi:** tìm, lọc, phân trang chạy đúng; khóa/mở khóa và đổi vai trò hoạt động với lý do; lỗi hiển thị `error.message`.

---

## 4. Phân quyền (`/roles`)

**Mục đích:** xem ai là quản trị viên và vai trò nào có quyền gì.

**API:** `GET /admin/users?role=Admin`; đổi vai trò dùng `PATCH /admin/users/{id}/role`.

**Giao diện:**
- Bên trái: bảng quản trị viên (Tên, Email, Vai trò, Ngày được cấp, ⋯ Hạ quyền) và nút "Thêm quản trị viên" (tìm một người dùng rồi nâng lên Admin, bắt buộc lý do).
- Bên phải: ma trận quyền (chỉ xem) với cột `User`, `Admin`, hàng là các quyền (Xem dashboard, Quản lý người dùng, Khóa/mở khóa, Đổi vai trò, Xem audit log, Xử lý yêu cầu xóa dữ liệu, Sửa cấu hình hệ thống, Sửa cấu hình AI).

**Luật:** cảnh báo khi hạ quyền Admin cuối cùng (chặn). Hiện chú thích "Hệ thống hiện có 2 vai trò". Phân quyền chi tiết hơn là `[THIẾU]` (cần backend thêm vai trò mới).

**Hoàn thành khi:** thăng/hạ quyền hoạt động, có xác nhận và lý do; ma trận hiển thị đúng.

---

## 5. Audit log (`/audit-logs`)

**Mục đích:** truy vết mọi hành động quan trọng.

**API:** `GET /admin/audit-logs?userId&eventType&from&to&cursor&limit`.

**Giao diện:** thanh lọc (Người dùng, Loại sự kiện, Từ ngày, Đến ngày, Áp dụng, Xóa lọc); bảng (Thời gian · Người thực hiện · Loại sự kiện · Đối tượng · Kết quả · ⋯); bấm dòng mở ngăn chi tiết với các trường và khối "Trước / Sau" nếu có; nút "Xuất CSV" (tạo phía admin từ dữ liệu đã tải, báo rõ phạm vi).

**Luật:** nhận tham số lọc từ URL (để trang Người dùng và Dashboard liên kết sang). Không hiển thị mật khẩu/token nếu log lỡ chứa; che dữ liệu nhạy cảm.

**Hoàn thành khi:** lọc, phân trang, xem chi tiết, liên kết từ Người dùng và Dashboard hoạt động.

---

## 6. Yêu cầu xóa dữ liệu (`/data-deletion`)

**Mục đích:** xử lý yêu cầu quyền riêng tư của người dùng.

**API:** `GET /admin/data-deletion-requests?status&cursor&limit`; `POST /admin/data-deletion-requests/{id}/cancel` body `{ reason: string }`.

**Giao diện:** bộ lọc trạng thái (lấy giá trị thật từ `DataDeletionStatus` trong swagger); bảng (Người dùng · Ngày yêu cầu · Hạn xử lý · Trạng thái · ⋯); ngăn chi tiết; hộp thoại "Hủy yêu cầu xóa" bắt buộc lý do.

**Luật:** chỉ yêu cầu đang chờ mới hủy được; sau khi hủy làm mới dòng và ghi nhận trong Audit log.

**Hoàn thành khi:** liệt kê theo trạng thái và hủy có lý do hoạt động.

---

## 7. Danh mục (`/categories`)

**Mục đích:** quản lý danh mục giao dịch dùng chung cho mọi app.

**API (backend):**
- `GET /admin/categories?includeInactive`
- `POST /admin/categories` body `{ name, slug, iconName }`
- `PATCH /admin/categories/{id}` cùng trường
- `PATCH /admin/categories/{id}/activation` body `{ isActive }`
- **Đồng bộ sang AI:** AI service `PUT /api/v1/admin/categories/sync` body `{ categories*: [{ slug*, label*, kind*: "expense"|"income", is_active }], taxonomy_version, reason }`. `[THIẾU]` cách admin gọi AI service (qua backend hay trực tiếp) cần chủ dự án quyết định.

**Giao diện:** thanh công cụ (tìm, lọc loại, "Hiện danh mục đã tắt", nút Thêm, nút "Đồng bộ sang AI"); bảng (Biểu tượng · Tên · Slug · Loại · Bật/Tắt · ✎); drawer Sửa danh mục (Tên, Slug, Biểu tượng); thẻ nhỏ "Đồng bộ AI lần cuối …".

**Luật:** `slug` duy nhất, chữ thường không dấu; tắt danh mục: hỏi xác nhận; `[THIẾU]` số giao dịch đang dùng và phiên bản danh mục cho app local-first (ghi vào danh sách chờ backend).

**Hoàn thành khi:** thêm/sửa/bật-tắt hoạt động; nút đồng bộ AI có kết quả rõ ràng (hoặc bị vô hiệu kèm lý do nếu chưa có đường gọi).

---

## 8. Ngân hàng & ví (`/providers`, 2 tab)

**Tab A – Nhà cung cấp** (ngân hàng/ví mà app cho người dùng chọn):
- `GET /admin/provider-configs?includeInactive`
- `POST /admin/provider-configs` body `{ providerKey, displayName, packageName, accountType: "Bank"|"EWallet"|"Cash" }`
- `PATCH /admin/provider-configs/{id}` (cùng trường), `PATCH …/{id}/activation` body `{ isActive }`
- Giao diện: bảng + dialog thêm/sửa + switch bật/tắt + "Hiện đã tắt". `providerKey` duy nhất.

**Tab B – Định dạng thông báo** (cách AI đọc thông báo ngân hàng) — chỉ có ở **AI service**, đường gọi từ admin `[THIẾU]` cần chốt:
- Danh sách/chi tiết: `GET /admin/provider-formats`, `GET/PATCH /admin/provider-formats/{format_id}` (PATCH `{ priority, notes }`)
- Tạo: `POST /admin/provider-formats` body `{ provider_key*, package_name*, priority, notes, reason }`; nhân bản `POST …/clone` `{ package_name*, reason }`
- Trường: `POST …/{format_id}/fields` `{ field_key*, maps_to, data_type: text|amount|datetime, is_required, source_kind: regex_group|literal, source_ref*, normalizer, is_sensitive }`; `PATCH/DELETE …/fields/{field_id}`
- Mẫu nhận diện: `POST …/patterns` `{ pattern_name*, regex*, transaction_type, priority, sample_text, is_active, notes }`; `PATCH/DELETE …/patterns/{pattern_id}`
- Câu mẫu: `POST …/samples` `{ sample_text*, expected_fields* }`; `DELETE …/samples/{sample_id}`
- Chạy thử: `POST …/try` `{ text* }`; kiểm tra: `GET …/check`
- Vòng đời: `POST …/activate` và `…/archive` đều `{ reason }`
- Giao diện: danh sách định dạng (Ngân hàng · Phiên bản · Trạng thái Nháp/Đang dùng/Lưu trữ) → trang soạn thảo 4 phần (Trường · Mẫu nhận diện · Câu thông báo mẫu · Chạy thử) và nút Lưu/Kích hoạt/Lưu trữ.
- Luật: không kích hoạt nếu `check` báo lỗi; `regex` phải được kiểm hợp lệ trước khi gửi; trường `is_sensitive` hiển thị biểu tượng khóa và che trong kết quả chạy thử.

**Hoàn thành khi:** Tab A đầy đủ; Tab B làm được nếu đường gọi AI service đã chốt, nếu chưa thì tab hiển thị "Chờ cấu hình kết nối AI service" và ghi vào danh sách chờ.

---

## 9. Phương pháp tài chính (`/finance-methods`)

**Mục đích:** quản lý các "phương pháp quản lý tài chính" mà app gợi ý cho người dùng sau khảo sát.

**API:**
- `GET /admin/finance-methods?includeInactive`
- `POST /admin/finance-methods` body `{ code, name, summary, role: "Primary"|"Supporting"|"Both", goalMode: "ReserveFirst"|"Envelope"|"AvailableToSpend"|"TrackOnly", paramDefs, eligibility, whyText, starterSteps, sortOrder }`
- `PATCH /admin/finance-methods/{id}` (cùng trường), `PATCH …/{id}/activation` body `{ isActive }`
- Liên kết mẫu mục tiêu: `GET /admin/finance-methods/{id}/goal-templates`, `PUT …/goal-templates` body `{ links: [{ templateCode, conditions, sortOrder }] }`

**Giao diện:** bảng (Mã · Tên · Vai trò · Chế độ mục tiêu · Thứ tự · Bật/Tắt · ✎); drawer/trang sửa với các phần: Thông tin (code, name, summary, whyText), Vai trò và chế độ mục tiêu (select), Tham số (`paramDefs`), Điều kiện áp dụng (`eligibility`), Các bước bắt đầu (`starterSteps`, danh sách sắp xếp được), Mẫu mục tiêu liên kết (chọn nhiều + điều kiện + thứ tự). `paramDefs`, `eligibility`, `starterSteps` là JSON: dùng trình soạn có kiểm tra định dạng, kèm xem trước.

**Luật:** `code` duy nhất; tắt phương pháp đang được gợi ý thì cảnh báo; kéo thả đổi `sortOrder`. Cấu trúc JSON chi tiết của ba trường trên **chưa có trong swagger** → agent lấy mẫu từ dữ liệu thật hoặc hỏi backend.

**Hoàn thành khi:** thêm/sửa/bật-tắt/liên kết mẫu mục tiêu hoạt động và lưu đúng.

---

## 10. Mẫu mục tiêu (`/goal-templates`)

**Mục đích:** quản lý mẫu mục tiêu tiết kiệm mà các phương pháp tài chính dùng.

**API:** `GET /admin/goal-templates?includeInactive`; `POST` và `PATCH /admin/goal-templates/{id}` body `{ code, name, description, defaultParams }`; `PATCH …/{id}/activation` `{ isActive }`.

**Giao diện:** bảng (Mã · Tên · Mô tả · Bật/Tắt · Được dùng bởi N phương pháp · ✎) và drawer sửa (code, name, description, `defaultParams` dạng JSON có kiểm tra).

**Luật:** `code` duy nhất; cảnh báo khi tắt mẫu đang được phương pháp đang bật liên kết. `[THIẾU]` đếm "được dùng bởi" nếu API không trả; tính tạm từ trang Phương pháp tài chính.

**Hoàn thành khi:** thêm/sửa/bật-tắt hoạt động.

---

## 11. Khảo sát (`/survey`)

**Mục đích:** quản lý câu hỏi khảo sát ban đầu; câu trả lời tạo "tín hiệu" để gợi ý phương pháp tài chính.

**API:**
- `GET /admin/survey-questions?includeInactive`
- `POST /admin/survey-questions` body `{ code, groupCode, text, showIf, sortOrder, options: [{ code, text, signals, sortOrder }] }`
- `PATCH /admin/survey-questions/{id}` body `{ code, groupCode, text, showIf, clearShowIf, sortOrder }`; `PATCH …/{id}/activation` `{ isActive }`
- Lựa chọn: `POST …/{id}/options` `{ code, text, signals, sortOrder }`; `PATCH …/options/{optionId}`; `PATCH …/options/{optionId}/activation`

**Giao diện:** danh sách câu hỏi nhóm theo `groupCode` (sắp xếp được); mỗi câu mở rộng ra danh sách lựa chọn; drawer sửa câu hỏi (nội dung, nhóm, điều kiện hiện `showIf`, nút xóa điều kiện qua `clearShowIf`); drawer sửa lựa chọn (mã, nội dung, `signals`, thứ tự); xem trước "Người dùng sẽ thấy câu hỏi này như sau".

**Luật:** `code` duy nhất; không tắt hết lựa chọn của một câu; `showIf` và `signals` là JSON: dùng trình soạn có kiểm tra. Cấu trúc chi tiết chưa có trong swagger → lấy từ dữ liệu thật.

**Hoàn thành khi:** tạo/sửa câu hỏi, lựa chọn, bật-tắt và sắp xếp hoạt động.

---

## 12. Cấu hình (`/settings`, 3 tab)

### 12A. Tab Hệ thống — `[THIẾU]` API
Các thẻ cấu hình (mỗi thẻ có nhãn, ô nhập, nút Lưu):
- Ngưỡng cảnh báo mặc định: "Sắp chạm" (mặc định 80%) và "Vượt" (100%).
- Phiên bản ứng dụng: tối thiểu, mới nhất, công tắc "Buộc cập nhật".
- Chế độ bảo trì: công tắc + thông báo hiển thị cho người dùng.
- Đồng bộ local-first: chu kỳ nền (phút), số lần thử lại, thời gian lưu hàng đợi tối đa (ngày).
- Tính năng: bật/tắt Chat AI, Giọng nói, Quét hóa đơn, Đọc thông báo ngân hàng.
- Dịch vụ AI: trạng thái 5 dịch vụ + nút "Tải lại cấu hình OCR" và "Tải lại tri thức OCR" (OCR service có `POST /admin/reload-config` và `POST /admin/reload-knowledge`; đường gọi từ admin cần chốt).

**Không có endpoint cấu hình hệ thống nào hiện tại.** Agent dựng giao diện nhưng đánh dấu "Chưa kết nối"; không lưu giả. Ghi yêu cầu cho backend vào mục 17.

### 12B. Tab Cấu hình AI — `[API]` có sẵn (qua backend)
Thanh điều hướng dọc với 4 phần:
1. **Tài liệu cấu hình AI:** `GET /admin/ai-config/documents`, `GET …/{name}` (đang dùng), `GET …/{name}/default`, `GET …/{name}/versions`, `GET …/versions/{version}`, `POST …/{name}/drafts` (AI service nhận `{ content*: object, note* }`), `POST …/versions/{version}/preview`, `POST …/versions/{version}/activate` (AI service nhận `{ expected_active_version*: integer, force }`). Giao diện: danh sách tài liệu → trình soạn (trái: nội dung, phải: danh sách phiên bản) với nút Lưu nháp, Xem thử, Kích hoạt, Về mặc định. Luật: kích hoạt gửi kèm `expected_active_version` để tránh ghi đè người khác; nếu lệch thì báo và tải lại, chỉ cho `force` khi người dùng xác nhận rõ.
2. **Luật AI:** bốn danh sách có Bật/Tắt:
   - Câu chỉ dẫn: `GET/POST /admin/ai-rules/ai-instructions` `{ instruction_text*, reason }`, `POST …/{id}/activate`.
   - Thương hiệu: `GET /admin/ai-rules/brands`, `PUT …/brands/{brandKey}` `{ category_slug*, display_name, whole_word, reason }`, `PATCH …/active` `{ is_active*, reason }`.
   - Từ khóa: `GET/POST /admin/ai-rules/keywords` `{ kind*, category_slug*, keyword*, reason }`, `PATCH …/{id}/active`.
   - Bộ nhớ hàng hóa: `GET/PUT/DELETE /admin/ai-rules/item-cache` (PUT `{ name*, category_slug*, reason }`) có tìm kiếm, thêm, sửa, xóa, xóa toàn bộ (xác nhận).
   - `GET /admin/ai-rules/meta` cho các lựa chọn (loại từ khóa, danh mục…).
3. **Thử câu nói:** `POST /admin/ai-rules/preview` body gồm `merchant_name`, `lines[]`, `item_name`, `proposed_brands[]`, `proposed_keywords[]` → hiển thị kết quả phân loại trước khi lưu.
4. **Lịch sử thay đổi:** `GET /admin/ai-rules/history`, `POST …/history/{id}/revert` (xác nhận, ghi lý do).

Mọi thay đổi luật có ô "Lý do" (khớp trường `reason`). Ghi chú: swagger backend không mô tả request body của nhóm này (để trống); tên trường ở trên lấy từ AI service, agent cần xác nhận lại bằng cách gọi thật.

### 12C. Tab Rasa — phần lớn `[THIẾU]` API
Điều hướng dọc: Thông tin · Ý định & câu mẫu · Câu trả lời · Bộ nhớ · Huấn luyện · Thử nghiệm.
- **Thông tin:** Rasa có `GET /version` (đã kiểm tra: 3.6.21) và `GET /status` (đã kiểm tra: `model_file`, `model_id`, `num_active_training_jobs`). Rasa nằm trong mạng docker nội bộ (cổng 5005, không mở ra ngoài) → admin phải gọi qua backend. `[THIẾU]` proxy.
- **Ý định & câu mẫu, Câu trả lời:** là file dữ liệu huấn luyện của Rasa, **không có API sửa**. `[THIẾU]` backend/AI service cần cung cấp.
- **Bộ nhớ:** khớp `ai-rules/item-cache` và `brands` ở mục 12B (làm được ngay): bảng hàng hóa → danh mục (tìm, thêm, sửa, xóa, nhập/xuất CSV phía admin), thương hiệu; cài đặt giữ lịch sử hội thoại `[THIẾU]`.
- **Huấn luyện / Thử nghiệm:** Rasa có API huấn luyện và phân tích câu nhưng cần proxy; `[THIẾU]`.

**Hoàn thành khi (cả trang):** Tab AI chạy đầy đủ với dữ liệu thật; Tab Hệ thống và Rasa dựng giao diện, phần chưa có API hiển thị trạng thái "Chưa kết nối" rõ ràng.

---

## 13. Đồng bộ dữ liệu — local-first (`/sync`) — `[THIẾU]` API

**Mục đích:** theo dõi việc app (lưu offline trước, đẩy lên sau) đồng bộ với server. App FinMate lưu giao dịch trên máy và gửi qua hàng đợi, gửi lại dùng cùng `clientRequestId` nên không tạo trùng.

**Dữ liệu mong muốn:** số giao dịch chờ đồng bộ, người dùng có hàng đợi, lỗi đồng bộ 24h, xung đột chưa xử lý; bảng theo người dùng (số chờ, lần đồng bộ gần nhất, phiên bản app, lỗi gần nhất, trạng thái); ngăn chi tiết với các lần thử (giờ tạo trên máy, giờ server nhận, kết quả) và nút "Gửi yêu cầu đồng bộ lại".

**Thực tế:** server chỉ thấy giao dịch đã nhận, không biết hàng đợi còn nằm trên máy. Cần app báo trạng thái đồng bộ về qua endpoint mới. Agent **chỉ dựng giao diện và trạng thái "Chưa kết nối"**, không bịa số liệu.

---

## 14. Học AI (`/ai-learning`) — chỉ có API ghi

**Mục đích:** hàng đợi dữ liệu để cải thiện AI. 3 tab:
1. **Câu chưa hiểu** (AI service `POST /chat/unclear`, `POST /chat/unclear/erase`): bảng câu, số lần gặp, ý định AI đoán; hành động Gán ý định → "Thêm vào câu mẫu Rasa" hoặc Bỏ qua; xóa theo người dùng.
2. **Mẫu hóa đơn** (`POST /bill/samples`, `POST /bill/samples/{scan_id}/label`, `…/discard`, `POST /bill/samples/erase`, `POST /bill/learn`): lưới mẫu (ảnh, cửa hàng AI đọc, tổng tiền, danh mục đoán, độ tin cậy, trạng thái); drawer gán nhãn (cửa hàng, tổng tiền, danh mục) / bỏ / xóa.
3. **Phản hồi người dùng** (`POST /feedback`): bảng phản hồi 👍/👎 kèm nội dung và kết quả AI.

**Thực tế:** AI service **không có API liệt kê** các dữ liệu trên (chỉ ghi và xóa). Agent dựng giao diện với trạng thái "Chưa kết nối" và ghi yêu cầu API liệt kê vào danh sách chờ backend. Ghi chú trên giao diện: "Dữ liệu chỉ dùng để cải thiện AI và xóa được theo yêu cầu của người dùng."

---

## 15. Hồ sơ admin (`/profile`)

**API:** `GET /users/me`; `POST /auth/change-password`; `POST /auth/logout-all`; `POST /auth/logout`.

**Giao diện:** thẻ tên/email/vai trò; form Đổi mật khẩu (mật khẩu cũ, mới, nhập lại; kiểm tra độ mạnh: ≥ 8 ký tự, chữ hoa, chữ thường, số, ký tự đặc biệt); nút "Đăng xuất tất cả thiết bị" có xác nhận.

**Hoàn thành khi:** đổi mật khẩu thành công thì buộc đăng nhập lại; lỗi hiển thị `error.message`.

---

## 16. Bảng tổng hợp API theo trang

| Trang | Backend (`/api/v1/admin/…`) | AI service / dịch vụ khác |
|---|---|---|
| 2 Dashboard | `ai-stats`, `audit-logs`, `data-deletion-requests`, `users` | AI `GET /health`, Rasa `/status`, OCR/STT `/health` |
| 3 Người dùng | `users`, `users/{id}`, `users/{id}/lock`, `users/{id}/role` | – |
| 4 Phân quyền | `users?role=Admin`, `users/{id}/role` | – |
| 5 Audit log | `audit-logs` | – |
| 6 Xóa dữ liệu | `data-deletion-requests`, `…/{id}/cancel` | – |
| 7 Danh mục | `categories`, `…/{id}`, `…/{id}/activation` | AI `PUT /admin/categories/sync` |
| 8 Ngân hàng & ví | `provider-configs`, `…/{id}`, `…/{id}/activation` | AI `admin/provider-formats…` |
| 9 Phương pháp TC | `finance-methods`, `…/{id}`, `…/activation`, `…/{id}/goal-templates` | – |
| 10 Mẫu mục tiêu | `goal-templates`, `…/{id}`, `…/activation` | – |
| 11 Khảo sát | `survey-questions`, `…/{id}`, `…/activation`, `…/options…` | – |
| 12 Cấu hình | `ai-config/documents…`, `ai-rules/…` | OCR `admin/reload-*`; Rasa status/train/parse |
| 13 Đồng bộ | – | – |
| 14 Học AI | – | AI `chat/unclear`, `bill/samples`, `bill/learn`, `feedback` (chỉ ghi) |
| 15 Hồ sơ | `auth/change-password`, `auth/logout-all` (ngoài `/admin`) | – |

---

## 17. Việc chờ backend / chủ dự án quyết định (agent không tự bịa)

1. **Tài khoản Admin dev** để gọi thử API và lấy response thật (swagger không mô tả response admin).
2. **Tạo tài khoản bởi admin:** chưa có endpoint.
3. **Phân quyền chi tiết:** backend chỉ có `User`, `Admin`.
4. **API tổng hợp cho Dashboard:** người dùng, giao dịch, trạng thái hệ thống.
5. **Đường gọi AI service / Rasa / OCR từ admin:** qua backend (khuyến nghị) hay trực tiếp; cách xác thực.
6. **Cấu hình hệ thống** (ngưỡng mặc định, phiên bản app, bảo trì, đồng bộ, tính năng): chưa có API.
7. **Rasa:** proxy trạng thái, huấn luyện, phân tích câu; API sửa câu mẫu và câu trả lời.
8. **Học AI:** API liệt kê câu chưa hiểu, mẫu hóa đơn, phản hồi.
9. **Đồng bộ local-first:** endpoint app báo trạng thái hàng đợi.
10. **Danh mục:** số giao dịch đang dùng, phiên bản danh mục.
11. **Công nghệ frontend** chưa chốt.
12. **Trang Nhiệm vụ** (gamification) bỏ hay giữ.

## 18. Thứ tự làm đề xuất

1. Khung ứng dụng: đăng nhập, kiểm tra Admin, sidebar, lớp gọi API, xử lý lỗi (Trang 1, 15).
2. Quản lý người dùng và Audit log (3, 5, 4, 6) — API sẵn, giá trị cao.
3. Danh mục, Ngân hàng & ví tab A, Phương pháp tài chính, Mẫu mục tiêu, Khảo sát (7, 8A, 9, 10, 11) — cùng khuôn CRUD, dùng lại một bộ thành phần bảng + drawer.
4. Cấu hình AI (12B) và Bộ nhớ Rasa — API sẵn nhưng nhiều chi tiết.
5. Dashboard (2) với nhóm AI + Bảo mật trước.
6. Phần `[THIẾU]`: dựng giao diện "Chưa kết nối" cho 8B, 12A, 12C, 13, 14; nối API khi backend sẵn sàng.

**Thành phần dùng chung nên làm một lần:** bảng dữ liệu có cursor + lọc + ngăn chi tiết, hộp thoại xác nhận có ô lý do, switch bật/tắt kèm xác nhận, trình soạn JSON có kiểm tra, thẻ KPI, khung "Chưa kết nối".

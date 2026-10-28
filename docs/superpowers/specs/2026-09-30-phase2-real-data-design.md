# Đợt 2 – Kết nối dữ liệu thật với FinMate.API

Ngày: 2026-09-30 · Trạng thái: chờ duyệt

## 1. Mục tiêu và tiêu chí thành công

Thay toàn bộ dữ liệu giả và hợp đồng API sai của FE bằng dữ liệu thật từ backend (`localhost:8080`), để một người dùng mới có thể: đăng nhập → tạo ví → ghi giao dịch → thấy số dư, ngân sách, mục tiêu, báo cáo đúng.

Thành công khi:
- Không còn số liệu tài chính cứng hoặc bịa trong code chạy thật; không có dữ liệu → hiện trạng thái trống, lỗi → hiện lỗi.
- Mọi request khớp hợp đồng backend (đã kiểm chứng bằng gọi thật, xem mục 2).
- Đăng xuất không để lại dữ liệu của người trước; giao dịch tạo lúc offline được đồng bộ khi có mạng.
- `flutter analyze` sạch, toàn bộ test pass, mỗi bước có test cho hợp đồng mới.

Ngoài phạm vi: ghi âm giọng nói và OCR thật (ẩn tab, "Sắp ra mắt"), thông báo đẩy, quản trị (admin), đổi giao diện/theme (đợt 3).

## 2. Hợp đồng backend đã kiểm chứng (gọi thật bằng user thử)

Envelope: `{success, data, error:{code,message,details}, meta:{cursor}}`. Lỗi nghiệp vụ nằm ở `error` (object). Lỗi validation 400 (ASP.NET ProblemDetails) có `errors` là **map**, không phải danh sách.

| Endpoint | Ghi chú response |
|---|---|
| `POST auth/login` | `data: {accessToken, refreshToken, expiresAt}` — **không có `user`**. Chưa xác thực email → 401 `AUTH_EMAIL_NOT_VERIFIED`. |
| `POST auth/register` | `data`: hồ sơ user (id, email, displayName, role, monthlyIncomeCents, pushEnabled, budgetAlertsEnabled, missionRemindersEnabled). |
| `GET users/me` | Như trên; **không có `emailVerifiedAt`**, cờ thông báo nằm phẳng (không lồng `notificationPrefs`). |
| `GET financial-accounts` | `[{id, accountType: Bank/EWallet/Cash, accountName, packageName, isMonitored, balanceCents, providerDisplayName, createdAt}]`. Người dùng mới: `[]`. |
| `POST financial-accounts` | `{accountName, accountType, providerConfigId?, initialBalanceCents}`. Mỗi provider chỉ theo dõi một tài khoản (`FINANCIAL_ACCOUNT_PACKAGE_DUPLICATE`). |
| `GET financial-accounts/providers` | `[{id, providerKey, displayName, packageName, accountType}]` (MB Bank, MoMo, Vietcombank, VNPay, ZaloPay). |
| `GET categories` | `[{id, name, slug, iconName (tên Material), isSystem}]`. Slug: food, transport, shopping, bills, entertainment, health, education, family, housing, income, other. |
| `GET transactions?limit&cursor&type&accountId&categoryId&fromDate&toDate` | `[{id, financialAccountId, counterAccountId, categoryId, categoryName, amountCents, transactionType: Debit/Credit/Transfer, source, status: Draft/Confirmed, merchantName, description, transactedAt, balanceAfterCents, createdAt}]`, phân trang `meta.cursor`. |
| `POST transactions` | `{financialAccountId, categoryId?, amountCents, transactionType, transactedAt, merchantName?, description?, clientRequestId?, source: Manual/...}` |
| `POST transactions/transfer` | `{fromAccountId, toAccountId, amountCents, transactedAt, description?, clientRequestId?}` |
| `POST transactions/{id}/confirm` | Body `{categoryId?}`. |
| `POST transactions/parse` | `{text}`. AI service đang tắt → `NOTIFICATION_AI_SERVICE_UNAVAILABLE`. **Chưa kiểm chứng response thành công.** |
| `GET budgets?year&month` | `{periodStart, periodEnd, totalBudget:{budgetId, categoryId:null,..., limitCents, spentCents, remainingCents, percentUsed, isOverLimit}|null, categoryBudgets:[{...categoryName, categorySlug}]}` |
| `POST budgets` | `{categoryId?, limitCents}` (categoryId null = ngân sách tổng). `PATCH budgets/{id}` `{limitCents}`. |
| `GET saving-goals` | `[{id, name, targetCents, savedCents, remainingCents, percentComplete, status: active/..., deadline, completedAt, celebration}]` |
| `POST saving-goals` | `{name, targetCents, deadline?}`. `POST saving-goals/{id}/contribute` `{amountCents, note?}` → trả goal kèm `celebration {leveledUp, level, unlockedItemNames}`. |
| `GET reports/monthly-summary` | `{totalSpentCents, totalIncomeCents, netCents, transactionCount, prevMonthSpentCents, changePercent|null}` |
| `GET reports/category-breakdown` | `{totalSpentCents, items:[{categoryId, categoryName, categorySlug, spentCents, percent}]}` |
| `GET reports/forecast` | `{spentSoFarCents, projectedSpendCents, daysElapsed, daysInMonth, basedOnDays, confidence, advice|null}` |
| `GET gamification/profile` | `{level, expPoints, expForCurrentLevel, expForNextLevel, expToNextLevel, currentStreakDays, longestStreakDays, lastActivityDate}` |
| `GET gamification/mascot` | `{items:[{id, code, name, itemType: hat/accessory/background/outfit, isOwned, isEquipped, unlockType, unlockHint}]}`; `PUT gamification/mascot/outfit` `{itemIds}` |

Số tiền là `int64` đồng VND (tên trường `...Cents` nhưng không có phần lẻ).

## 3. Bước 2.0 – Sửa lỗi đợt 1 lộ ra khi đối chiếu backend (làm trước, nhỏ)

Nếu không sửa, đăng nhập thật không dùng được:
1. `login` không có `user` → lưu token rồi gọi `GET users/me`.
2. `UserProfile.fromJson`: bỏ phụ thuộc `emailVerifiedAt` (backend không trả); `users/me` thành công ⇒ đã xác thực (login chặn user chưa xác thực). Đọc cờ thông báo phẳng.
3. Đăng nhập gặp `AUTH_EMAIL_NOT_VERIFIED` → chuyển sang màn OTP (kèm email) thay vì hiện lỗi.
4. `ApiResponse`/`_handleError`: hiểu `meta.cursor`, và `errors` dạng map (validation) → thông điệp chung "Dữ liệu không hợp lệ" kèm chi tiết trường đầu tiên.

## 4. Kiến trúc dữ liệu (áp dụng cho 2a–2d)

Nguyên tắc: mỗi feature có repository trả entity thuần Dart; controller giữ `AsyncValue`; màn hình chỉ hiển thị. Repository **không** nuốt lỗi và **không** bịa dữ liệu.

- **Entity mới:** `FinancialAccount`, `Category`, `Budget` (thay `BudgetEntity`), `SavingGoal`, `MonthlySummary`, `CategoryBreakdown`, `Forecast`, `MascotItem`, `GamificationProfile`. `TransactionEntity` đổi sang hợp đồng thật (`TransactionType` giữ enum `income/expense/transfer` ở tầng UI, map với `Credit/Debit/Transfer` ở tầng data).
- **Provider gốc:** `accountsProvider` và `categoriesProvider` (tải một lần, cache trong bộ nhớ, làm mới khi tạo tài khoản). Mọi dropdown tài khoản/danh mục đọc từ đây.
- **Reset khi đổi người dùng:** tất cả provider dữ liệu `watch` một `sessionProvider` (userId hiện tại) để tự tạo lại khi đăng nhập/đăng xuất; đăng xuất và hết phiên xóa các bảng SQLite (`LocalTransactions`, `SyncQueue`). Nếu còn giao dịch chưa đồng bộ, hỏi xác nhận trước khi đăng xuất.
- **Icon danh mục:** `iconName` của backend là tên Material; ánh xạ sang icon Lucide bằng một bảng nhỏ trong FE (fallback `tag`). Không dùng icon Material do backend trả.

## 5. Các bước

### 2a. Tài khoản và danh mục
- Repository/provider cho `financial-accounts`, `providers`, `categories`.
- Onboarding bước 2: thay danh sách ứng dụng giả bằng providers thật; bước 3: tạo ví "Tiền mặt" (số dư đầu kỳ nhập được) và các tài khoản người dùng chọn; lưu `monthlyIncomeCents` và **ngân sách tổng** (`POST budgets` với hạn mức đã nhập – hiện đang bị bỏ).
- Nếu người dùng chưa có tài khoản nào khi mở tạo giao dịch → hướng dẫn tạo ví trước.

### 2b. Giao dịch
- Repository đọc/ghi đúng hợp đồng; danh sách phân trang cursor ("tải thêm" khi cuộn). Bộ lọc gửi lên server (`type`, ngày).
- Chỉ dùng cache local khi lỗi mạng (`NetworkException`); 401/4xx/5xx được báo cho người dùng.
- Tạo giao dịch: ghi local → gửi kèm `clientRequestId`; mất mạng → xếp hàng; server báo lỗi nghiệp vụ → hiện lỗi và không xếp hàng.
- `SyncService`: chạy khi mở app, sau đăng nhập, và mỗi khi có thao tác mới; gửi body đúng hợp đồng, thành công → thay dòng local bằng dòng server; giới hạn 5 lần thử, quá hạn đánh dấu "lỗi" để người dùng thấy.
- NLP: nối `transactions/parse` thật; bỏ toàn bộ bản xem trước bịa (lỗi thì báo lỗi). Tab **Giọng nói** và **Hóa đơn** hiện "Sắp ra mắt" (vô hiệu).
- Màn xác nhận: `confirm` gửi `{categoryId}` theo hợp đồng; các trường khác chỉnh trước bằng `PATCH transactions/{id}` nếu cần (cần kiểm chứng khi AI service bật).

### 2c. Kế hoạch
- Ngân sách: `GET budgets`, tạo/sửa (`POST`/`PATCH limitCents`), chọn danh mục từ `categoriesProvider`. Hạn mức ngày an toàn tính từ `totalBudget.remainingCents` và số ngày còn lại. Không có ngân sách tổng → hiện lời mời tạo.
- Mục tiêu: `GET/POST saving-goals`, `contribute` với số tiền người dùng nhập (chọn tài khoản nếu backend yêu cầu), chọn hạn chót bằng date picker. Hiện `celebration` (lên cấp, vật phẩm mở khóa) sau khi nạp.

### 2d. Trang chủ, Phân tích, Mascot
- Trang chủ: tổng số dư = tổng `balanceCents` của các tài khoản; thu/chi tháng từ `monthly-summary`; giao dịch gần đây từ 4 giao dịch mới nhất.
- Phân tích: biểu đồ tròn từ `category-breakdown`, đường dự báo từ `forecast` (thiếu dữ liệu → trạng thái trống), so sánh kỳ trước từ `changePercent`. Chọn kỳ tuần/năm dùng `fromDate/toDate` của `reports/timeline` nếu backend hỗ trợ; nếu không, giữ nút chọn kỳ nhưng chỉ bật "Tháng này".
- Mascot: vật phẩm và trang phục từ server (`PUT outfit`); biểu cảm vẫn tính ở FE từ `percentUsed` của ngân sách tổng; sửa lỗi provider tự reset khi kế hoạch tải lại (tách trạng thái ngân sách khỏi trạng thái trang phục).

## 6. Xử lý lỗi và kiểm thử

- Lỗi hiển thị bằng `errorMessage()`; màn hình luôn có nhánh loading/empty/error kèm nút "Thử lại".
- Test theo lớp: parse entity từ JSON thật (dùng các response ở mục 2 làm fixture), repository với adapter Dio giả (đường dẫn, body, lỗi mạng vs lỗi server), `SyncService` (thành công, mạng lỗi, quá số lần thử), widget test cho trạng thái trống/lỗi, test đăng xuất xóa dữ liệu.
- Kiểm chứng cuối bước bằng gọi thật lên backend local với user thử.

## 7. Rủi ro và điểm chưa biết

- Response của `parse`, `confirm`, `scan-receipt` chưa kiểm chứng: `finmate_be-ai-service-1` khởi động rồi thoát (exit 1) vì thiếu biến môi trường `INTERNAL_API_KEY` (lỗi cấu hình phía backend, ngoài FE). Khi container chạy được thì kiểm chứng lại ở bước 2b; đến lúc đó FE xử lý `NOTIFICATION_AI_SERVICE_UNAVAILABLE` bằng thông báo lỗi rõ ràng và cho nhập tay.
- `reports/timeline` chưa xem response (chỉ liệt kê endpoint).
- Xóa dữ liệu local khi đăng xuất có thể làm mất giao dịch offline chưa đồng bộ → có hộp thoại xác nhận (mục 4).
- User thử `fm-probe-…@example.com` đã được tạo trong DB local (kèm 2 tài khoản, vài giao dịch, ngân sách, mục tiêu) để dò hợp đồng; có thể xóa qua `DELETE auth/account` khi xong.

# Đợt 2 – Kết nối dữ liệu thật: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FE Flutter dùng đúng hợp đồng FinMate.API và dữ liệu thật; không còn số liệu tài chính giả.

**Architecture:** Mỗi feature có repository (gọi `ApiClient`, không nuốt lỗi) → controller `StateNotifier<AsyncValue<…>>` → màn hình. Provider dữ liệu `watch(currentUserIdProvider)` để tự tạo lại khi đổi user; đăng xuất/hết phiên xóa SQLite. Offline: đọc cache và xếp hàng ghi chỉ khi `NetworkException`.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), go_router, Dio, Drift, lucide_icons_flutter, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-30-phase2-real-data-design.md` (hợp đồng backend ở mục 2). Response thật đã lưu làm fixture tại `test/fixtures/api/*.json` (login, users_me, accounts, account_providers, categories, transactions, budgets, saving_goals, monthly_summary, category_breakdown, forecast, mascot, gamification_profile, timeline, login_not_verified, validation_error).

## Global Constraints

- Thư mục không phải git repo → **không có bước commit**; kiểm chứng bằng `flutter analyze --no-pub` (kết quả `No issues found!`) và `flutter test --no-pub` (`All tests passed!`) sau **mỗi** task.
- Envelope backend: `{success, data, error:{code,message,details}, meta:{cursor}}`; lỗi nghiệp vụ ở `error` (object); validation 400 có `errors` là map.
- Số tiền là `int64` đồng VND, đặt tên `...Cents`; trong FE dùng `BigInt` (theo code hiện có); parse bằng `parseCents(Object?)` (Task 1), format bằng `formatVnd(BigInt)`.
- Không dữ liệu tài chính giả/cứng trong code chạy thật; không có dữ liệu → trạng thái trống; lỗi → thông báo qua `errorMessage(e)` + nút "Thử lại".
- Loại giao dịch trong UI giữ enum `TransactionType {income, expense, transfer}`; map API: `Credit/Debit/Transfer`.
- Icon chỉ dùng `lucide_icons_flutter`; danh mục ánh xạ `slug → LucideIcons` (không dùng `iconName` Material của backend). UI dùng `AppColors/AppSpacing/AppTypography`; chuỗi tiếng Việt. Skill `ui-ux-pro-max`/`taste-skill` chưa cài → giữ nguyên hệ thiết kế hiện có, không thêm phong cách mới.
- Giữ tên lớp hiện có (`BudgetEntity`, `SavingsGoalEntity`, `TransactionEntity`, `MascotState`); đổi trường theo hợp đồng và cập nhật test cũ tương ứng.
- Tất cả request đi qua `ApiClient.get/post/patch/put` (để có `_handleError`), không dùng `apiClient.dio` trực tiếp.

## Review Focus

- Trường tùy chọn là `null` (`categoryName`, `deadline`, `changePercent`, `totalBudget`, `advice`) → không crash, hiển thị hợp lý (Task 3, 7, 8, 9).
- Người dùng chưa có tài khoản nào mở "Ghi chép" → được hướng dẫn tạo ví thay vì lỗi (Task 6).
- Đăng xuất khi còn giao dịch chờ đồng bộ, rồi đăng nhập user khác → không thấy dữ liệu người trước (Task 2, 4).
- Nhập số tiền `0`, rỗng, có dấu chấm ngăn cách, số rất lớn (>9,2 tỷ tỷ) → không tạo giao dịch sai (Task 6, 7).
- Múi giờ: server trả `+07:00`/UTC; nhóm giao dịch theo ngày **giờ địa phương** (Task 6).

---

### Task 1: Hợp đồng auth + nền tảng dùng chung (bước 2.0)

**Files:**
- Modify: `lib/features/auth/domain/entities/user_profile.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/core/network/api_client.dart`, `lib/core/network/api_response.dart`, `lib/features/auth/presentation/screens/login_screen.dart`
- Create: `lib/core/format/money.dart`
- Test: `test/features/auth/user_profile_test.dart`, `test/core/api_client_test.dart` (bổ sung), `test/features/auth/auth_test.dart` (bổ sung)

**Interfaces:**
- Produces: `BigInt parseCents(Object? v)` (nhận `int`, `num`, `String`, `null`→`BigInt.zero`) và `String formatVnd(BigInt cents)` → `'150.000 ₫'`, cả hai trong `core/format/money.dart`.
- Produces: `ApiMeta.nextCursor` đọc `json['cursor'] ?? json['nextCursor']`.
- Produces: `ApiClient.put<T>(String path, {dynamic data, required T Function(dynamic) fromJsonT})`.

- [ ] **Step 1: Test** `UserProfile.fromJson(users_me.json['data'])`: `isEmailVerified == true`, `notificationPrefs.pushEnabled == true`, `monthlyIncomeCents == null`; `AuthRepository.login` với adapter giả (login.json rồi users_me.json) trả `UserProfile` và lưu token vào `InMemoryTokenStorage`; `parseCents(45000)`, `parseCents('45000')`, `parseCents(null)`; `formatVnd(BigInt.from(150000)) == '150.000 ₫'`.
- [ ] **Step 2: Test** `ApiClient` với `validation_error.json` (400): ném `ApiException` có `message` bắt đầu `'Dữ liệu không hợp lệ'`; `ApiMeta.fromJson({'cursor':'c1'}).nextCursor == 'c1'`; login screen: `login_not_verified.json` → điều hướng `/verify-otp` với `extra == email` (dùng `GoRouter` thử như `auth_test.dart`).
- [ ] **Step 3: Chạy test, xác nhận FAIL.**
- [ ] **Step 4: Implement** — `UserProfile.fromJson`: `isEmailVerified: true` (login đã chặn user chưa xác thực), prefs đọc trực tiếp `pushEnabled/budgetAlertsEnabled/missionRemindersEnabled` (phẳng), `monthlyIncomeCents` qua `(json[...] as num?)?.toInt()`. `AuthRepository.login`: post → lưu `accessToken/refreshToken` → `return getMe()`; `googleLogin` cùng cách. `_handleError`: nếu `data['errors']` là `Map` → `BusinessRuleException(code:'VALIDATION', message:'Dữ liệu không hợp lệ: <thông điệp đầu tiên>')`. `LoginScreen._submit`: nếu lỗi là `ApiException` có `code == 'AUTH_EMAIL_NOT_VERIFIED'` → `context.push('/verify-otp', extra: email)` và không hiện banner lỗi.
- [ ] **Step 5: Chạy analyze + toàn bộ test, xác nhận pass.**

### Task 2: Phạm vi phiên & dọn dữ liệu khi đăng xuất

**Files:**
- Modify: `lib/core/database/app_database.dart`, `lib/features/auth/presentation/controllers/auth_controller.dart`, `lib/features/gamification/presentation/screens/profile_screen.dart`
- Test: `test/core/database_test.dart` (bổ sung), `test/features/auth/auth_test.dart` (bổ sung)

**Interfaces:**
- Produces: `AppDatabase.clearAll(): Future<void>` (xóa `localTransactions` và `syncQueue`); `AppDatabase.pendingSyncCount(): Future<int>`.
- Produces: `final currentUserIdProvider = Provider<String?>` trong `auth_controller.dart` = `ref.watch(authControllerProvider.select((s) => s.valueOrNull?.id))`.
- Produces: `AuthController({required repository, Future<void> Function()? onSignedOut})`; `logout()` và `handleSessionExpired()` đều `await onSignedOut?.call()` rồi đặt state `data(null)`. `authControllerProvider` truyền `onSignedOut: () => ref.read(databaseProvider).clearAll()`.

- [ ] **Step 1: Test** `clearAll` làm `getAllTransactions()` và `getPendingSyncItems()` rỗng; `AuthController.logout()` và `handleSessionExpired()` gọi `onSignedOut` đúng 1 lần.
- [ ] **Step 2: Chạy test, xác nhận FAIL.**
- [ ] **Step 3: Implement** các chữ ký trên. `ProfileScreen`: nút đăng xuất — nếu `pendingSyncCount() > 0` hiện `AlertDialog` "Còn N giao dịch chưa đồng bộ, đăng xuất sẽ mất chúng" (Hủy / Vẫn đăng xuất) rồi mới `logout()`.
- [ ] **Step 4: Chạy analyze + toàn bộ test, xác nhận pass.**

### Task 3: Tài khoản tài chính & danh mục (2a – dữ liệu)

**Files:**
- Create: `lib/features/accounts/domain/financial_account.dart`, `lib/features/accounts/data/accounts_repository.dart`, `lib/features/accounts/presentation/controllers/accounts_controller.dart`, `lib/features/categories/domain/category.dart`, `lib/features/categories/data/categories_repository.dart`, `lib/features/categories/presentation/categories_provider.dart`, `lib/features/categories/presentation/category_icons.dart`
- Test: `test/features/accounts/accounts_test.dart`, `test/features/categories/categories_test.dart`

**Interfaces:**
- Produces: `enum AccountType { bank, eWallet, cash }` với `apiValue` (`'Bank'|'EWallet'|'Cash'`), `label` (`'Ngân hàng'|'Ví điện tử'|'Tiền mặt'`), `static AccountType fromApi(String)`.
- Produces: `FinancialAccount{String id; AccountType type; String name; String? providerName; bool isMonitored; BigInt balanceCents}` + `fromJson`; `AccountProviderInfo{String id, providerKey, displayName, packageName; AccountType type}` + `fromJson`.
- Produces: `AccountsRepository{getAccounts()→List<FinancialAccount>; getProviders()→List<AccountProviderInfo>; createAccount({required String name, required AccountType type, String? providerConfigId, BigInt? initialBalanceCents})→FinancialAccount}`; `accountsRepositoryProvider`.
- Produces: `accountsControllerProvider: StateNotifierProvider<AccountsController, AsyncValue<List<FinancialAccount>>>` (watch `currentUserIdProvider`; `load()`, `Future<FinancialAccount> create(...)` rồi `load()`), `accountProvidersProvider: FutureProvider<List<AccountProviderInfo>>`.
- Produces: `Category{String id, name, slug; String iconName; bool isSystem}` + `fromJson`; `categoriesProvider: FutureProvider<List<Category>>` (watch `currentUserIdProvider`); `IconData categoryIcon(String? slug)` ánh xạ food→`utensils`, transport→`car`, shopping→`shoppingBag`, bills→`receipt`, entertainment→`clapperboard`, health→`heartPulse`, education→`graduationCap`, family→`users`, housing→`house`, income→`banknote`, mặc định→`tag` (xác minh mỗi tên có trong `LucideIcons`).

- [ ] **Step 1: Test** parse `accounts.json` (2 tài khoản, `type` đúng, `balanceCents` là `BigInt`), `account_providers.json` (5 provider), `categories.json` (11 danh mục, có `food`); `categoryIcon('food')` khác `categoryIcon(null)`; repository với adapter giả gửi `POST /api/v1/financial-accounts` body `{accountName, accountType:'Cash', initialBalanceCents}` (không gửi `providerConfigId` khi null); lỗi `FINANCIAL_ACCOUNT_PACKAGE_DUPLICATE` được ném lại; `AccountsController` đổi `currentUserIdProvider` → tải lại.
- [ ] **Step 2: Chạy test, xác nhận FAIL.** **Step 3: Implement** theo chữ ký trên (dùng `parseCents`). **Step 4: analyze + toàn bộ test, pass.**

### Task 4: Onboarding thật (2a – giao diện)

**Files:**
- Modify: `lib/features/onboarding/presentation/screens/initial_setup_screen.dart`
- Create: `lib/features/onboarding/presentation/controllers/onboarding_controller.dart`
- Test: `test/features/onboarding/onboarding_test.dart`

**Interfaces:**
- Consumes: `AccountsController.create`, `accountProvidersProvider`, `AuthController.updateMonthlyIncome(int)`.
- Produces: `OnboardingInput{int monthlyIncomeCents; BigInt cashBalanceCents; Set<String> providerConfigIds}`; `OnboardingController.complete(OnboardingInput)`: (1) `updateMonthlyIncome`; (2) nếu chưa có tài khoản `Cash` thì tạo "Ví tiền mặt" với `cashBalanceCents`; (3) tạo tài khoản cho từng provider được chọn mà chưa có (tên = `displayName`, loại theo provider); chạy lại được (idempotent), lỗi giữa chừng được ném lại.

- [ ] **Step 1: Test** với repository giả: chạy `complete` hai lần chỉ tạo mỗi tài khoản một lần; lỗi ở bước 3 ném `ApiException` và không đăng xuất; chọn provider rỗng vẫn tạo ví tiền mặt.
- [ ] **Step 2: Chạy, FAIL.** **Step 3: Implement.** Màn hình: bước 2 hiển thị provider thật (`SwitchListTile`, trạng thái loading/lỗi/thử lại) thay `_monitoredApps` cứng; bước 3 thêm ô "Số dư ví tiền mặt hiện có"; nút "Hoàn tất" gọi `complete`, lỗi → SnackBar `errorMessage`. Xóa ô "Hạn mức chi tiêu" (`_budgetController`) khỏi bước 3 vì chưa có nơi lưu (Task 7 thêm lại ô "Ngân sách tháng" cùng chỗ lưu) — không để ô nhập nào bị bỏ qua. Nút "Bật" quyền chưa có chức năng → thay bằng chú thích "Sẽ được yêu cầu khi tính năng sẵn sàng" (không nút chết).
- [ ] **Step 4: analyze + toàn bộ test, pass.**

### Task 5: Giao dịch – hợp đồng, DB local, đồng bộ (2b – dữ liệu)

**Files:**
- Modify: `lib/features/transactions/domain/entities/transaction_entity.dart`, `lib/features/transactions/data/transaction_repository.dart`, `lib/core/database/app_database.dart`, `lib/core/database/sync_service.dart`
- Create: `lib/features/transactions/domain/entities/transaction_page.dart`
- Test: `test/features/transactions/transaction_repository_test.dart`, `test/core/sync_service_test.dart`; cập nhật `test/features/transactions/transaction_test.dart`, `test/core/database_test.dart`

**Interfaces:**
- Produces: `TransactionType.apiValue` (`Credit|Debit|Transfer`), `TransactionType.fromApi(String)`; `enum TransactionStatus { draft, confirmed }`.
- Produces: `TransactionEntity{String id; BigInt amountCents; TransactionType type; String? categoryId, categoryName, merchantName, description(non-null, ''); DateTime date; String accountId; String? toAccountId; TransactionStatus status; bool isSynced; String? clientRequestId; BigInt? balanceAfterCents}` với `bool get isInternalTransfer => type == transfer`, `formattedAmount`, `fromJson(server)` (`transactedAt`→`date`, `counterAccountId`→`toAccountId`, `DateTime.parse(...).toLocal()`), `copyWith`, và `Map<String,dynamic> toRequestJson()` → `{financialAccountId, categoryId?, amountCents:<int>, transactionType, transactedAt:<UTC ISO>, merchantName?, description?, clientRequestId, source:'Manual'}` (transfer: `{fromAccountId,toAccountId,amountCents,transactedAt,description,clientRequestId}`).
- Produces: `TransactionPage{List<TransactionEntity> items; String? nextCursor}`.
- Produces: `TransactionRepository.getTransactions({TransactionType? type, DateTime? fromDate, DateTime? toDate, String? cursor, int limit = 20}) → TransactionPage`; `createTransaction({required String accountId, String? categoryId, required BigInt amountCents, required TransactionType type, String? merchantName, String description = '', required DateTime date}) → TransactionEntity`; `transferInternal({required BigInt amountCents, required String fromAccountId, toAccountId, String description = '', required DateTime date}) → TransactionEntity`.
- Produces: `AppDatabase.deleteTransactionByClientRequestId(String)`, `AppDatabase.markSyncFailed(String clientRequestId)`, hằng `SyncService.maxRetries = 5`, `SyncService.processQueue() → Future<int>`.
- Ràng buộc hành vi: `getTransactions` chỉ trả cache local khi bắt `NetworkException`; `ApiException` khác (401/4xx/5xx) được ném lại. `create/transfer`: ghi local (`syncStatus='pending'`) → POST kèm `clientRequestId`; thành công → thay dòng local bằng dòng server (`synced`); `NetworkException` → `enqueueSync` (payload = `toRequestJson()`, endpoint `/api/v1/transactions` hoặc `/api/v1/transactions/transfer`) và trả entity `isSynced:false`; `ApiException` khác → xóa dòng local và ném lại. `processQueue`: `NetworkException` → dừng, không tăng `retryCount`; `ApiException` → `incrementRetryCount`, đạt `maxRetries` → `markSyncFailed` và bỏ qua từ đó; thành công → `removeSyncItem`, xóa dòng local theo `clientRequestId`, `insertLocalTransaction` bản server.

- [ ] **Step 1: Test** parse `transactions.json` (3 giao dịch: Debit có `categoryName:'Ăn uống'`, Credit, Transfer; `nextCursor == null`); `toRequestJson()` đúng khóa/giá trị (`amountCents` là số nguyên, `transactionType:'Debit'`); repository (adapter giả): 401 → ném `ApiException` (không trả cache); mất mạng → trả dòng từ DB; create mất mạng → có 1 item trong `SyncQueue` và `isSynced == false`; create bị `400` → không còn dòng local; `processQueue`: mạng chết → `retryCount` không đổi; 400 ×5 → dòng local `syncStatus == 'failed'`; thành công → hàng đợi rỗng và dòng local mang `id` của server.
- [ ] **Step 2: Chạy, FAIL.** **Step 3: Implement.** Dùng `apiClient.get/post` (không dùng `dio`). Cập nhật test cũ (`transaction_test.dart`: `category` → `categoryName`, bỏ `'acc-wallet-1'` cứng, `Transfer` không có category). **Step 4: analyze + toàn bộ test, pass.**

### Task 6: Giao dịch – controller & màn hình (2b – giao diện)

**Files:**
- Modify: `lib/features/transactions/presentation/controllers/transaction_controller.dart`, `.../screens/transactions_screen.dart`, `.../widgets/create_transaction_bottom_sheet.dart`, `.../screens/transaction_preview_screen.dart`, `lib/features/transactions/domain/entities/transaction_preview.dart`
- Test: cập nhật `test/features/transactions/transaction_test.dart`, `test/features/dashboard/dashboard_test.dart`; thêm `test/features/transactions/transaction_controller_test.dart`

**Interfaces:**
- Consumes: Task 3 (`accountsControllerProvider`, `categoriesProvider`, `categoryIcon`), Task 5 (`TransactionRepository`, `SyncService`).
- Produces: `TransactionController` giữ `AsyncValue<List<TransactionEntity>>` và thêm `bool get hasMore`, `Future<void> loadMore()`, `Future<void> setFilter({TransactionType? type})`, `Future<void> loadTransactions()` (gọi `syncService.processQueue()` best-effort trước khi tải trang đầu); các hàm `createTransaction/transferInternal/confirmDraft` theo chữ ký Task 5. `transactionControllerProvider` watch `currentUserIdProvider`.
- Produces: `TransactionPreview{String draftId; String rawText; BigInt? amountCents; TransactionType type; String? categoryId; String? accountId; String? description; DateTime? date; double confidenceScore; List<String> missingFields}` với `fromJson` **chịu lỗi** (chấp nhận `draftId|id`, `transactionType|type` dạng `Debit/Credit/expense/income`, `confidenceScore|confidence`, thiếu trường → mặc định, không ném). Chưa kiểm chứng response thật (AI service tắt): ghi rõ trong comment.

- [ ] **Step 1: Test** controller: `setFilter(type: expense)` gọi repository với `type == debit` và thay danh sách; `loadMore` nối trang tiếp theo khi `nextCursor != null`, `hasMore == false` khi `null`; đổi user → danh sách reset. Widget: `TransactionsScreen` hiển thị nhóm ngày theo **giờ địa phương** (giao dịch `2026-09-30T20:59:40Z` nhóm đúng ngày local), tên danh mục từ `categoryName`, biểu tượng `cloudOff` khi `!isSynced`; sheet "Ghi chép" khi `accounts == []` hiện "Bạn chưa có tài khoản" + nút tạo ví (mở dialog tạo ví tiền mặt), không hiện form; số tiền `0`/rỗng bị chặn với SnackBar; chuỗi `"1.500.000"` parse ra `BigInt 1500000`; số > `9223372036854775807` bị từ chối (không ném); lỗi lưu hiện SnackBar `errorMessage`.
- [ ] **Step 2: Chạy, FAIL.**
- [ ] **Step 3: Implement.** Sheet: dropdown tài khoản/danh mục từ provider (bỏ danh sách cứng), `Padding(bottom: MediaQuery.viewInsets.bottom)` và bỏ hack `+100`; loại `Chi tiêu→debit`, `Thu nhập→credit`, `Chuyển tiền→transfer` (không có danh mục); mọi `await` trong `try/catch`; tab **AI Text** gọi `parseNlp`, lỗi (`NOTIFICATION_AI_SERVICE_UNAVAILABLE` hoặc khác) → SnackBar và giữ nguyên nội dung nhập (xóa hoàn toàn preview bịa); tab **Giọng nói** và **Hóa đơn** vô hiệu với chữ "Sắp ra mắt" (xóa nội dung giả `Uống cafe Highland…`, `Hóa đơn VinMart+`). Màn xem trước: đọc danh mục/tài khoản từ provider, chip danh mục gợi ý không dùng emoji `⭐` (dùng biểu tượng `LucideIcons.star` ở `avatar` của chip), xác nhận qua `confirmDraft` (`POST /transactions/{id}/confirm` `{categoryId}`). Đọc `UpdateTransactionRequest` trong `http://localhost:8080/swagger/v1/swagger.json`: nếu người dùng sửa số tiền/mô tả/tài khoản thì `PATCH /transactions/{id}` các trường đã sửa **trước** khi confirm. Màn danh sách: bộ lọc gọi `setFilter`, cuộn tới cuối gọi `loadMore`, nút lọc chết → xóa.
- [ ] **Step 4: analyze + toàn bộ test, pass.**

### Task 7: Kế hoạch – ngân sách & mục tiêu (2c)

**Files:**
- Modify: `lib/features/planning/domain/entities/budget_entity.dart`, `.../savings_goal_entity.dart`, `lib/features/planning/data/planning_repository.dart`, `.../controllers/planning_controller.dart`, `.../screens/planning_screen.dart`, `lib/features/onboarding/presentation/controllers/onboarding_controller.dart`
- Test: viết lại `test/features/planning/planning_test.dart`; thêm `test/features/planning/planning_repository_test.dart`

**Interfaces:**
- Produces: `BudgetEntity{String id; String? categoryId; String category (categoryName ?? 'Tổng thể'); BigInt limitAmountCents, spentAmountCents; int month, year}` — giữ getter `spendingPercentage` (tính từ chi/hạn mức), `statusLevel` (<70 safe, 70–89 warning, ≥90 danger), `statusColor`, `isOverspent`, `remainingAmountCents`, `dailySafeSpendingLimit({required int daysRemaining})`, `formatted*`; `factory BudgetEntity.fromJson(Map, {required int month, required int year})` đọc `budgetId`, `categoryId`, `categoryName`, `limitCents`, `spentCents`.
- Produces: `SavingsGoalEntity{String id; String title; BigInt targetAmountCents, currentAmountCents; DateTime? targetDate; String status}` với `progressPercentage`, `bool get isCompleted`, `bool get isOverdue`, `BigInt? requiredPerMonth({DateTime? asOf})` (= còn thiếu / số tháng còn lại, tối thiểu 1; `null` nếu không có hạn chót hoặc đã hoàn thành), `statusLabel` (`'Hoàn thành'|'Trễ hạn'|'Cần ~<formatVnd>/tháng'|'Không hạn chót'`), `statusColor`; `fromJson` đọc `name,targetCents,savedCents,deadline,status`. Xóa `monthlyContributionCents` và `GoalFeasibility`.
- Produces: `GoalContribution{SavingsGoalEntity goal; int? newLevel; List<String> unlockedItems}`; `PlanningRepository{getBudgets({month,year})→({BudgetEntity? total, List<BudgetEntity> categories}); createBudget({String? categoryId, required BigInt limitCents}); updateBudgetLimit(String id, BigInt limitCents); getGoals(); createGoal({required String name, required BigInt targetCents, DateTime? deadline}); contribute(String goalId, BigInt amountCents, {String? note})→GoalContribution}`; endpoints `/api/v1/budgets`, `/api/v1/saving-goals`, `/api/v1/saving-goals/{id}/contribute`.
- Produces: `PlanningState{BudgetEntity? overallBudget; List<BudgetEntity> categoryBudgets; List<SavingsGoalEntity> savingsGoals; int daysRemainingInMonth}`, `dailySafeLimit` từ `overallBudget`; `planningControllerProvider` watch `currentUserIdProvider`; `createOrUpdateBudget`, `createSavingsGoal`, `contributeToGoal` **ném lỗi lại**.

- [ ] **Step 1: Test** parse `budgets.json` (rỗng ban đầu và biến thể có `totalBudget` + 1 danh mục), `saving_goals.json` (`deadline == null` không crash; `requiredPerMonth == null`); giữ các test BR-43/BR-50 với constructor mới; repository (adapter giả): `createBudget` gửi `{limitCents:<int>}` khi `categoryId == null`; `contribute` gửi `{amountCents}` tới `/saving-goals/<id>/contribute` và đọc `celebration.leveledUp/level/unlockedItemNames`; lỗi mạng ném `NetworkException` (không trả dữ liệu mẫu); màn hình: không có ngân sách tổng → hiện lời mời "Tạo ngân sách tháng" (không hiện "0 ₫ / ngày"); nạp tiền mở dialog nhập số tiền (bỏ 1.000.000 cứng), lỗi hiện SnackBar, thành công hiện thông báo lên cấp nếu có.
- [ ] **Step 2: Chạy, FAIL.**
- [ ] **Step 3: Implement.** Xóa toàn bộ dữ liệu mẫu trong repository. Dialog thêm ngân sách: dropdown từ `categoriesProvider` (tùy chọn "Tổng thể" = `categoryId null`), số tiền, `await` rồi mới đóng, lỗi hiện SnackBar; dialog mục tiêu: tên, mục tiêu, `showDatePicker` cho hạn chót (tùy chọn); nội dung dialog bọc `SingleChildScrollView`; dispose các `TextEditingController` của dialog. `OnboardingInput` thêm `BigInt? monthlyBudgetCents`; `OnboardingController.complete` thêm: nếu > 0 và chưa có ngân sách tổng → `createBudget(categoryId: null, limitCents)`; màn onboarding bước 3 thêm ô "Ngân sách tháng" (tùy chọn) nối vào đó, kèm test onboarding tạo ngân sách tổng.
- [ ] **Step 4: analyze + toàn bộ test, pass.**

### Task 8: Báo cáo – Trang chủ & Phân tích (2d – phần 1)

**Files:**
- Create: `lib/features/analytics/domain/report_models.dart`, `lib/features/analytics/data/reports_repository.dart`, `lib/features/analytics/presentation/reports_providers.dart`
- Modify: `lib/features/dashboard/presentation/screens/home_screen.dart`, `lib/features/analytics/presentation/screens/analytics_screen.dart`
- Test: `test/features/analytics/reports_test.dart`; cập nhật `test/features/dashboard/dashboard_test.dart`

**Interfaces:**
- Produces: `MonthlySummary{BigInt totalSpentCents, totalIncomeCents, netCents, prevMonthSpentCents; int transactionCount; double? changePercent}`; `CategoryBreakdown{BigInt totalSpentCents; List<CategoryShare> items}` với `CategoryShare{String? categoryId; String name; String slug; BigInt spentCents; double percent}`; `Forecast{BigInt spentSoFarCents, projectedSpendCents; int daysElapsed, daysInMonth; String confidence; String? advice}`; mỗi lớp có `fromJson`.
- Produces: `ReportsRepository{getMonthlySummary({required int year, required int month}); getCategoryBreakdown({...}); getForecast()}`; `monthlySummaryProvider`, `categoryBreakdownProvider`, `forecastProvider` (`FutureProvider`, watch `currentUserIdProvider`).

- [ ] **Step 1: Test** parse `monthly_summary.json` (`changePercent == null`, tổng chi 45.000), `category_breakdown.json` (1 mục `food` 100%), `forecast.json` (`advice == null`, `confidence == 'medium'`); widget Home: tổng số dư = tổng `balanceCents` các tài khoản (ví dụ 30.955.000 + 4.000.000 = `34.955.000 ₫`), thu/chi lấy từ `monthlySummary`, không tài khoản nào → hiện `0 ₫` kèm gợi ý tạo tài khoản, lỗi báo cáo → hiện thông báo + "Thử lại" (không số giả); Analytics: `items == []` → trạng thái trống "Chưa có chi tiêu tháng này"; `changePercent == null` → ẩn thẻ so sánh; giảm/tăng đúng chiều và màu.
- [ ] **Step 2: Chạy, FAIL.**
- [ ] **Step 3: Implement.** Home: xóa hằng `24500000/18500000/9200000`; sửa chữ "Chưa có giao dịch nào hôm nay" thành "Chưa có giao dịch nào"; chuông thông báo chưa có chức năng → xóa nút. Analytics: biểu đồ tròn từ `items` (bảng màu 6 màu lấy từ `AppColors` + màu hiện có, lặp vòng), chú giải từ dữ liệu (`formatVnd`), thẻ dự báo (đã chi / dự kiến cuối tháng / hạn mức ngân sách tổng nếu có) thay biểu đồ đường giả; bộ chọn kỳ: chỉ "Tháng này" bật, "Tuần này"/"Năm nay" hiển thị vô hiệu kèm "Sắp có"; nút chia sẻ chết → xóa.
- [ ] **Step 4: analyze + toàn bộ test, pass.**

### Task 9: Mascot & hồ sơ gamification (2d – phần 2)

**Files:**
- Modify: `lib/features/gamification/domain/entities/mascot_state.dart`, `.../controllers/mascot_controller.dart`, `.../widgets/mascot_widget.dart`, `.../screens/profile_screen.dart`
- Create: `lib/features/gamification/data/gamification_repository.dart`
- Test: cập nhật `test/features/gamification/mascot_test.dart`; thêm `test/features/gamification/gamification_repository_test.dart`

**Interfaces:**
- Produces: `MascotItem{String id, code, name, itemType; bool isOwned, isEquipped; String? unlockHint}` + `fromJson`; `GamificationProfile{int level, expPoints, expForNextLevel, currentStreakDays, longestStreakDays}` + `fromJson`; `GamificationRepository{getProfile(); getMascotItems()→List<MascotItem>; equip(List<String> itemIds)}` (`PUT /api/v1/gamification/mascot/outfit` body `{itemIds}`).
- Produces: `MascotState{MascotEmotion emotion; String dialogue; int level; int experiencePoints; List<MascotItem> equippedItems}`; `MascotState.fromBudgetPercentage(double pct, {int level = 1, int exp = 0, List<MascotItem> equipped = const []})` (ngưỡng 70/90 và lời thoại giữ nguyên); xóa enum `MascotOutfit`.
- Produces: `mascotItemsProvider: FutureProvider<List<MascotItem>>` và `gamificationProfileProvider` (watch `currentUserIdProvider`); `MascotController` **không** tạo lại khi kế hoạch đổi: nhận `percentage` ban đầu bằng `ref.read` và cập nhật bằng `ref.listen(planningControllerProvider, …)` gọi `updateSpendingPercentage`; khi chưa có ngân sách tổng dùng `0.0` (trạng thái vui, không giả `50`).

- [ ] **Step 1: Test** parse `mascot.json` (có 11 vật phẩm; `isEquipped` phân loại đúng) và `gamification_profile.json` (`level == 3`); test mascot cũ (happy/concerned/panic) vẫn pass với chữ ký mới; test controller: đổi planning state **không** làm mất `equippedItems`/`level`; `equip` gửi đúng `{itemIds:[…]}`.
- [ ] **Step 2: Chạy, FAIL.**
- [ ] **Step 3: Implement.** Hồ sơ: chip vật phẩm từ `mascotItemsProvider` (chỉ `isOwned` bấm được, vật phẩm khóa hiện `unlockHint`, mỗi `itemType` một vật phẩm trang bị), thẻ cấp/exp/chuỗi ngày từ `gamificationProfileProvider`; xóa huy hiệu cứng ("Tiết kiệm/Kỷ luật 7N/Thợ săn chi") và chữ "Thành viên Chuẩn" nếu không có dữ liệu thật; email/tên không dùng giá trị mặc định giả `'user@finmate.com'`.
- [ ] **Step 4: analyze + toàn bộ test, pass.**

### Task 10: Kiểm chứng với backend thật

**Files:**
- Create: `test/live/contract_live_test.dart` (bỏ qua nếu thiếu biến môi trường)

- [ ] **Step 1:** Viết test đọc `FINMATE_BASE_URL`, `FINMATE_TEST_EMAIL`, `FINMATE_TEST_PASSWORD` từ `Platform.environment`; thiếu → `skip`. Nội dung: đăng nhập qua `AuthRepository`, rồi `AccountsRepository.getAccounts/getProviders`, `categories`, `TransactionRepository.getTransactions`, `PlanningRepository.getBudgets/getGoals`, `ReportsRepository.*`, `GamificationRepository.*` đều parse không ném; tạo 1 giao dịch `Debit` 1.000 ₫ vào tài khoản đầu tiên rồi kiểm tra nó xuất hiện ở trang đầu.
- [ ] **Step 2:** Chạy với user thử (đọc thông tin từ thư mục tạm, không in ra): `flutter test test/live/contract_live_test.dart` với `FINMATE_*` đặt qua môi trường; Expected: tất cả pass. Nếu backend trả trường khác giả định, sửa entity tương ứng và bổ sung fixture.
- [ ] **Step 3:** `flutter analyze --no-pub` sạch và `flutter test --no-pub` (không biến môi trường) pass, test live được ghi nhận là skipped.
- [ ] **Step 4:** Báo người dùng: đã thay đổi gì, những gì chưa kiểm chứng (AI parse/confirm nếu `ai-service` chưa chạy), và hỏi có xóa user thử (`DELETE /auth/account`) không.

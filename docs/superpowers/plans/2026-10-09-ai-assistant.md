# Trợ lý AI (Chatbot + Giọng nói + Quét hóa đơn) và gỡ Gamification – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Người dùng ghi chép/hỏi chi tiêu bằng chatbot, giọng nói và chụp hóa đơn, nối API AI của backend; toàn bộ gamification bị gỡ khỏi app.

**Architecture:** Module mới `features/assistant/` (domain, data, presentation) dùng lại `ApiClient`, `TransactionRepository`, accounts/categories providers. Chat là trung tâm; màn voice và scan trả kết quả (chuỗi / `DraftTransaction`) về chat; mọi bản nháp được rà soát ở một màn chung rồi lưu bằng `POST /transactions` (hoặc `/transfer`). `speech_to_text` và `image_picker` được bọc sau hai interface để test không cần plugin.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), go_router, Dio, Drift, `image_picker`, `speech_to_text`, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-09-ai-assistant-design.md` (hợp đồng backend ở mục 2; gỡ gamification ở mục 4).

## Global Constraints

- Thư mục không phải git repo → **không có bước commit**; sau **mỗi** task chạy `flutter analyze --no-pub` (kết quả `No issues found!`) và `flutter test --no-pub` (`All tests passed!`).
- Phong bì backend: `{success, data, error:{code,message,details}, meta}`; mọi request qua `ApiClient`, không dùng `dio` trực tiếp ngoài `core/network`.
- Số tiền là `BigInt`; nhập tay qua `parseAmountInput` (tối đa **999.999.999.999 ₫**); hiển thị bằng `formatVnd`.
- Không dữ liệu AI/tài chính giả: lỗi (mạng, 4xx, 5xx, `NOTIFICATION_AI_SERVICE_UNAVAILABLE`) được ném lại và hiện bằng `errorMessage(e)`.
- Icon chỉ dùng `lucide_icons_flutter`; chuỗi UI tiếng Việt; dùng `AppColors/AppSpacing/AppTypography`. Skill `ui-ux-pro-max`/`taste-skill` chưa cài → giữ nguyên hệ thiết kế hiện có.
- Locale giọng nói `vi_VN`; ảnh hóa đơn nén tối đa **1600px**, chất lượng **85**; cảnh báo độ tin cậy khi `confidence < 0.85`.
- `source` khi lưu: chat → `Manual`, giọng nói → `Voice`, hóa đơn → `Receipt`.
- Người dùng đã đồng ý thêm `image_picker` và `speech_to_text` (không thêm thư viện khác).
- Fixture response thật đặt ở `test/fixtures/api/*.json` (đọc bằng `fixture()`/`fixtureData()` trong `test/fixtures/fixture.dart`).

## Review Focus

- Phản hồi chat lạ: `action` không biết, `saved` nhưng `transaction == null`, `confirm` nhưng `draft == null` → không crash, hiện thông điệp chung (Task 2, 5).
- Bản nháp thiếu số tiền/loại/tài khoản, số tiền `0` hoặc quá cap → nút Lưu bị chặn, không gọi API (Task 6).
- Gửi trùng / bấm "Gửi lại" sau lỗi → không tạo hai giao dịch; dùng lại đúng `clientRequestId` (Task 5).
- Giọng nói: bị từ chối quyền, thiết bị không hỗ trợ, nói xong nhưng chuỗi rỗng → không crash, không gửi chuỗi rỗng (Task 8).
- Hóa đơn: `ocrResult` ≠ success, `transactedAt` null, ảnh không chọn được (hủy chọn) / từ chối quyền camera → ở lại màn, có đường lùi (Task 9).
- Đăng xuất rồi đăng nhập user khác không thấy lịch sử chat cũ (Task 5).

---

### Task 1: Gỡ gamification và màn Cá nhân gọn

**Files:**
- Delete: `lib/features/gamification/` (cả thư mục), `test/features/gamification/`, `test/fixtures/api/mascot.json`, `test/fixtures/api/gamification_profile.json`
- Create: `lib/features/profile/presentation/screens/profile_screen.dart` (class `ProfileScreen`), `test/features/profile/profile_screen_test.dart`
- Modify: `lib/routes/app_router.dart` (import `ProfileScreen` từ vị trí mới), `lib/features/dashboard/presentation/screens/home_screen.dart` (bỏ `MascotWidget` và import), `lib/features/planning/data/planning_repository.dart`, `lib/features/planning/presentation/controllers/planning_controller.dart`, `lib/features/planning/presentation/screens/planning_screen.dart`, `lib/features/transactions/presentation/controllers/transaction_controller.dart`, `test/features/dashboard/dashboard_test.dart`, `test/features/planning/planning_test.dart`, `test/features/planning/planning_repository_test.dart`, `test/integration/app_flow_test.dart`, `test/live/contract_live_test.dart`

**Interfaces:**
- Produces: `ProfileScreen` (ConsumerWidget) chỉ gồm thẻ người dùng (chữ cái đầu, tên, email), thẻ Zero-Credential, nút "Đăng xuất tài khoản" (hộp thoại "Còn giao dịch chưa đồng bộ" khi `pendingSyncCount() > 0`, rồi `logout()` và `go('/')`).
- Produces: `PlanningRepository.contribute(String goalId, BigInt amountCents, {String? note}) → Future<SavingsGoalEntity>`; `PlanningController.contributeToGoal(String, BigInt) → Future<SavingsGoalEntity>`; xóa `GoalContribution`, `onGoalContributed`, và mọi tham chiếu `gamificationProfileProvider/mascotItemsProvider/mascotControllerProvider`.

- [ ] **Step 1: Test (RED)** — `profile_screen_test.dart`: `hiện tên và email, không còn cấp độ/XP/tủ đồ` (override `authControllerProvider` bằng mock có `UserProfile` tên "Probe"; `find.textContaining('Cấp ')` và `find.text('TỦ ĐỒ LINH VẬT FINNY')` là `findsNothing`); `đăng xuất khi còn giao dịch chưa gửi hiện xác nhận 'Còn giao dịch chưa đồng bộ'` (override `databaseProvider` bằng DB in-memory có 1 mục `SyncQueue`; chạm 'Đăng xuất tài khoản' → thấy hộp thoại; chọn 'Hủy' không gọi `logout`). Sửa test cũ: `planning_test.dart` bỏ ca "báo lên cấp", mock `contributeToGoal` trả `SavingsGoalEntity` và kỳ vọng SnackBar 'Đã nạp 1.000.000 ₫ vào mục tiêu!'; `planning_repository_test.dart` kỳ vọng `contribute` trả `SavingsGoalEntity` (bỏ ca celebration và ca `onGoalContributed`); `dashboard_test.dart` bỏ `MockMascotController`/override mascot và `expect(find.text('Finny'))`; `app_flow_test.dart` bỏ route gamification của backend giả; `contract_live_test.dart` bỏ gamification.
- [ ] **Step 2: Chạy** `flutter test --no-pub` → Expected: FAIL (biên dịch lỗi vì `ProfileScreen` mới chưa có / mock lệch).
- [ ] **Step 3: Implement** — xóa các file/thư mục ở mục Delete; tạo `ProfileScreen` mới (lấy thẻ người dùng, thẻ Zero-Credential và logic đăng xuất từ file cũ trước khi xóa); sửa `PlanningRepository.contribute` chỉ trả `SavingsGoalEntity.fromJson(data)` (bỏ phần `celebration`); `PlanningController` bỏ `onGoalContributed` và import gamification; `planning_screen.dart` `_contribute` chỉ hiện `Đã nạp ${formatVnd(amount)} vào mục tiêu!`; `transaction_controller.dart` bỏ hai dòng `ref.invalidate(gamificationProfileProvider/mascotItemsProvider)` và import; `home_screen.dart` bỏ `const MascotWidget()` cùng `SizedBox` liền kề.
- [ ] **Step 4: Chạy** `flutter analyze --no-pub` và `flutter test --no-pub` → Expected: sạch, `All tests passed!`.
- [ ] **Step 5: Quét sót** — `grep -rniE "gamification|mascot|finny|XP\b|Cấp [0-9]" lib test` → Expected: không còn kết quả (trừ chuỗi 'XP' hợp lệ nếu có trong mô tả khác; nếu có, giải thích trong ledger).

### Task 2: Mô hình AI và fixture từ response thật

**Files:**
- Create: `lib/features/assistant/domain/assistant_models.dart`, `test/features/assistant/assistant_models_test.dart`, fixture `test/fixtures/api/{chat_saved,chat_summary,chat_reply_out_of_scope,chat_reply_needs_amount,chat_confirm_expense,chat_confirm_transfer,parse_ok,parse_empty,scan_receipt_success}.json`
- Modify: `lib/features/transactions/domain/entities/transaction_entity.dart` (thêm trường `source`)

**Interfaces:**
- Produces trong `assistant_models.dart`:
  - `enum DraftSource { chat, voice, receipt }` với `String get apiValue` → `'Manual'|'Voice'|'Receipt'`.
  - `enum DraftKind { expense, transfer }`.
  - `class DraftTransaction { DraftKind kind; BigInt? amountCents; TransactionType? type; String? merchantName; String? description; String? categorySlug; String? suggestedAccountId; List<String> missingFields; DraftSource source; DateTime? transactedAt; double? confidence; }` (const constructor, tất cả tham số có tên), `copyWith(...)`, `factory DraftTransaction.fromChatJson(Map<String,dynamic>, {DraftSource source = DraftSource.chat})`, `factory DraftTransaction.fromParseJson(Map<String,dynamic>, {DraftSource source = DraftSource.chat})`.
  - `class ChatSummaryItem { String slug; String name; BigInt amountCents; double share }`, `class ChatSummary { String metric; String periodLabel; BigInt totalCents, incomeCents, expenseCents, leftCents; List<ChatSummaryItem> items }` với `fromJson`.
  - `enum ChatAction { saved, summary, reply, confirm }`; `class ChatReply { ChatAction action; String? intent; String? replyText; TransactionEntity? transaction; DraftTransaction? draft; ChatSummary? summary }` với `factory ChatReply.fromJson(Map<String,dynamic>)` — `action` lạ hoặc thiếu dữ liệu tương ứng (ví dụ `saved` không có `transaction`) → `ChatReply(action: reply, replyText: <thông điệp chung>)`.
  - `class ReceiptScan { bool success; DraftTransaction draft; String? scanId }` với `fromJson` (`success = ocrResult == 'success'`, `draft.source = receipt`, `confidence` lấy từ `confidence`).
- Produces: `TransactionEntity.source` (`String`, mặc định `'Manual'`), `toRequestJson()` dùng `source` thay hằng `'Manual'`, `fromJson` đọc `json['source']`, `copyWith(source:)`.

- [ ] **Step 1:** Tạo 9 fixture bằng cách gọi backend thật (đăng nhập `docs/dev-test-account.md`, `chat` với: "cafe highlands 55k" kèm accountId, "thang nay toi tieu bao nhieu", "xin chao ban la ai", "mua do", "luong 20 trieu", "chuyen 500k tu vietcombank sang vi tien mat"; `parse` "an trua com tam 45k bang vi tien mat" và "mua do"; `scan-receipt` với `test/fixtures/receipt_sample.png` — copy từ `C:\Users\Admin\AppData\Local\Temp\receipt_test.png`), lưu đúng nguyên phong bì response; sau đó xóa giao dịch được tạo ra bởi "cafe highlands 55k" (`DELETE /transactions/{id}`).
- [ ] **Step 2: Test (RED)** — `assistant_models_test.dart`: `ChatReply.fromJson(chat_saved)` → `action == saved`, `transaction.amountCents == 55000`, `categoryName == 'Ăn uống'`; `chat_summary` → `summary.expenseCents == 55000`, `items.single.slug == 'food'`; `chat_reply_out_of_scope` và `needs_amount` → `action == reply`, `intent` đúng, `replyText` khác rỗng; `chat_confirm_expense` → `draft.missingFields == ['category']`, `draft.type == TransactionType.expense` (kể cả `transactionType: "debit"` chữ thường), `suggestedAccountId` không null; `chat_confirm_transfer` → `kind == transfer`, `missingFields == ['accounts']`, `type == TransactionType.transfer`; `parse_ok` → `categorySlug == 'food'`, `type == expense`; `parse_empty` → mọi trường null, `amountCents == null`; `scan_receipt_success` → `success`, `draft.amountCents == 55000`, `merchantName == 'WinMart'`, `draft.source == receipt`, `transactedAt == null`, `confidence == 0.7`; `action` lạ (`{"action":"dance"}`) và `saved` không có `transaction` → `reply` với thông điệp chung; `TransactionEntity.toRequestJson()['source']` bằng `'Receipt'` khi tạo entity với `source: 'Receipt'`.
- [ ] **Step 3: Chạy** `flutter test --no-pub test/features/assistant` → Expected: FAIL (thiếu file/biên dịch).
- [ ] **Step 4: Implement** các lớp ở Interfaces; `TransactionType.fromApi` đã chấp nhận `debit/credit/transfer` chữ thường; `kind == transfer` suy ra từ `draft.kind == 'transfer'`.
- [ ] **Step 5: Chạy** analyze + toàn bộ test → Expected: sạch, pass.

### Task 3: AssistantRepository và tham số `source`

**Files:**
- Create: `lib/features/assistant/data/assistant_repository.dart`, `test/features/assistant/assistant_repository_test.dart`
- Modify: `lib/features/transactions/data/transaction_repository.dart` (`createTransaction({..., String source = 'Manual'})`), `lib/features/transactions/presentation/controllers/transaction_controller.dart` (`createTransaction({..., String source = 'Manual'})` chuyển tiếp), `test/features/transactions/transaction_test.dart` (FakeTxController khớp chữ ký mới), `test/features/transactions/transaction_repository_test.dart`

**Interfaces:**
- Consumes: Task 2 (`ChatReply`, `DraftTransaction`, `ReceiptScan`).
- Produces: `AssistantRepository({required ApiClient apiClient})` với
  - `Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId})` → `POST /api/v1/transactions/chat`, body `{text, financialAccountId?, clientRequestId?}` (bỏ khóa null);
  - `Future<DraftTransaction> parse(String text, {DraftSource source = DraftSource.chat})` → `POST /api/v1/transactions/parse` `{text}`;
  - `Future<ReceiptScan> scanReceipt(String filePath)` → `POST /api/v1/transactions/scan-receipt` bằng `ApiClient.uploadFile` với `FormData` field `file` (tên tệp giữ nguyên, `MultipartFile.fromFile`);
  - `final assistantRepositoryProvider = Provider<AssistantRepository>`.
- Produces: `TransactionRepository.createTransaction(..., String source = 'Manual')` đưa `source` vào `TransactionEntity` → `toRequestJson`.

- [ ] **Step 1: Test (RED)** — adapter giả (`RouteAdapter`): `chat` gửi đúng đường dẫn/body (có và không có `accountId`/`clientRequestId`) và parse từng fixture chat; `parse` đọc `parse_ok`; `scanReceipt` gửi `multipart` với field `file` (kiểm `options.data is FormData` và `(data as FormData).files.single.key == 'file'`; tạo tệp tạm `test/fixtures/receipt_sample.png`) và đọc `scan_receipt_success`; `chat` khi AI không sẵn sàng (`error.code == 'NOTIFICATION_AI_SERVICE_UNAVAILABLE'`, HTTP 503) ném `ApiException` có `code` đó; mất mạng ném `NetworkException`; `createTransaction(source: 'Voice')` gửi `source: 'Voice'` trong body.
- [ ] **Step 2: Chạy** `flutter test --no-pub test/features/assistant test/features/transactions` → Expected: FAIL.
- [ ] **Step 3: Implement** như Interfaces; chuyển `source` qua `TransactionRepository._submit` (không đổi hàm chuyển tiền).
- [ ] **Step 4: Chạy** analyze + toàn bộ test → Expected: sạch, pass.

### Task 4: Phụ thuộc, quyền và hai interface bọc plugin

**Files:**
- Modify: `pubspec.yaml` (thêm `image_picker`, `speech_to_text` bằng `flutter pub add image_picker speech_to_text`), `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
- Create: `lib/features/assistant/data/speech_service.dart`, `lib/features/assistant/data/receipt_image_source.dart`, `test/features/assistant/platform_services_test.dart`

**Interfaces:**
- Produces trong `speech_service.dart`: `enum SpeechAvailability { available, denied, unsupported }`; `class SpeechUpdate { final String text; final bool isFinal; const SpeechUpdate(this.text, {this.isFinal = false}); }`; `abstract class SpeechService { Future<SpeechAvailability> initialize(); Stream<SpeechUpdate> listen({String localeId = 'vi_VN'}); Future<void> stop(); }`; `class SpeechToTextService implements SpeechService` (dùng plugin `speech_to_text`; `initialize()` false → `denied` nếu `!hasPermission` ngược lại `unsupported`); `final speechServiceProvider = Provider<SpeechService>((ref) => SpeechToTextService())`.
- Produces trong `receipt_image_source.dart`: `class ImageSourceException implements Exception { final String message; const ImageSourceException(this.message); }`; `abstract class ReceiptImageSource { Future<String?> pickFromCamera(); Future<String?> pickFromGallery(); }` (trả đường dẫn tệp hoặc `null` khi người dùng hủy; ném `ImageSourceException` khi bị từ chối quyền); `class ImagePickerSource implements ReceiptImageSource` (`maxWidth: 1600, maxHeight: 1600, imageQuality: 85`); `final receiptImageSourceProvider = Provider<ReceiptImageSource>((ref) => ImagePickerSource())`.
- Android: thêm `<uses-permission android:name="android.permission.CAMERA"/>` và `RECORD_AUDIO`, và trong `<queries>` một `<intent><action android:name="android.speech.RecognitionService"/></intent>`. iOS (Info.plist, tiếng Việt): `NSMicrophoneUsageDescription` ("FinMate dùng micro để bạn ghi chép bằng giọng nói."), `NSSpeechRecognitionUsageDescription` ("FinMate chuyển giọng nói của bạn thành chữ để ghi chép."), `NSCameraUsageDescription` ("FinMate dùng camera để quét hóa đơn."), `NSPhotoLibraryUsageDescription` ("FinMate đọc ảnh hóa đơn bạn chọn.").

- [ ] **Step 1: Test (RED)** — `platform_services_test.dart`: các provider có thể được `overrideWithValue` bằng bản giả `FakeSpeechService`/`FakeImageSource` (định nghĩa trong `test/fixtures/fakes.dart`, dùng chung cho Task 8–9) và đọc lại đúng giá trị; `SpeechUpdate('xin chào', isFinal: true)` có `isFinal == true`.
- [ ] **Step 2: Chạy** test đó → Expected: FAIL (thiếu file).
- [ ] **Step 3: Implement** + chạy `flutter pub add image_picker speech_to_text` rồi `flutter pub get`; sửa manifest/plist đúng các khóa ở trên; tạo `test/fixtures/fakes.dart` gồm `FakeSpeechService` (có `availability`, danh sách `updates` phát ra từ `listen`, đếm `stopCalls`) và `FakeImageSource` (có `cameraPath`, `galleryPath`, `error`).
- [ ] **Step 4: Chạy** `flutter analyze --no-pub`, `flutter test --no-pub` → Expected: sạch, pass; `flutter build apk --debug --no-pub` (nếu môi trường cho phép) hoặc ghi vào ledger rằng chưa kiểm chứng được build Android.

### Task 5: AssistantController (trạng thái chat)

**Files:**
- Create: `lib/features/assistant/presentation/controllers/assistant_controller.dart`, `lib/features/transactions/presentation/controllers/data_refresh.dart`, `test/features/assistant/assistant_controller_test.dart`
- Modify: `lib/features/transactions/presentation/controllers/transaction_controller.dart` (dùng `refreshDerivedData`)

**Interfaces:**
- Consumes: `AssistantRepository` (Task 3), `ChatReply`, `DraftTransaction`.
- Produces `sealed class ChatMessage` với `int id` (tăng dần): `UserText(text)`, `AssistantText(text)`, `SavedCard(TransactionEntity tx)`, `SummaryCard(ChatSummary summary)`, `DraftCard(DraftTransaction draft, {bool resolved = false, String? resolvedSummary})`, `ErrorNote(String message, String? retryText)`.
- Produces `class AssistantState { List<ChatMessage> messages; bool isSending; String? selectedAccountId }` (+ `copyWith`).
- Produces `class AssistantController extends StateNotifier<AssistantState>` với `AssistantController({required AssistantRepository repository, VoidCallback? onDataChanged})`:
  - `Future<void> send(String text, {DraftSource source = DraftSource.chat})`: bỏ qua nếu `text.trim().isEmpty` hoặc `isSending`; thêm `UserText`; gọi `chat(text, accountId: selectedAccountId, clientRequestId: <id>)`; theo `action`: `saved` → `SavedCard` + `onDataChanged`, `summary` → `SummaryCard`, `reply` → `AssistantText(replyText)`, `confirm` → `DraftCard(draft.copyWith(source: source))`; lỗi → `ErrorNote(errorMessage(e), retryText: text)`. `clientRequestId` được sinh một lần cho mỗi tin nhắn người dùng và **tái sử dụng** khi `retry`.
  - `Future<void> retry(int errorMessageId)` (gửi lại cùng `clientRequestId`), `void addDraft(DraftTransaction d)`, `void resolveDraft(int messageId, String summary)`, `void selectAccount(String? id)`, `void clear()`.
- Produces `final assistantControllerProvider = StateNotifierProvider<AssistantController, AssistantState>` (watch `currentUserIdProvider` để tạo lại khi đổi người dùng; `onDataChanged` = `refreshDerivedData(ref)` + `ref.invalidate(transactionControllerProvider)`).
- Produces `void refreshDerivedData(Ref ref)` trong `data_refresh.dart`: `accountsControllerProvider.notifier.load()`, `planningControllerProvider.notifier.loadPlanningData(silent: true)`, `ref.invalidate` của `monthlySummaryProvider`, `categoryBreakdownProvider`, `forecastProvider`; `transactionControllerProvider` dùng hàm này trong `onDataChanged`.

- [ ] **Step 1: Test (RED)** — repository giả (subclass/inline) trả từng `ChatReply` từ fixture: `saved` → có `SavedCard` và `onDataChanged` gọi 1 lần; `summary` → `SummaryCard`; `reply` → `AssistantText`; `confirm` → `DraftCard` với `source` truyền vào; chuỗi rỗng/chỉ khoảng trắng không gửi; gửi khi `isSending` bị bỏ qua (kiểm `chat` gọi 1 lần); lỗi `NetworkException` → `ErrorNote` kèm `retryText`, `retry` gọi lại với **cùng** `clientRequestId` (so sánh giá trị truyền vào hai lần gọi) và thay `ErrorNote` bằng kết quả; `ChatReply` lạ → `AssistantText` thông điệp chung; `resolveDraft` đổi `DraftCard.resolved`; `selectAccount` được truyền vào `chat`; provider tạo lại khi `currentUserIdProvider` đổi (lịch sử bị xóa).
- [ ] **Step 2: Chạy** → Expected: FAIL.
- [ ] **Step 3: Implement** như Interfaces (id tin nhắn dùng bộ đếm trong controller; `clientRequestId` sinh bằng `Uuid().v4()`).
- [ ] **Step 4: Chạy** analyze + toàn bộ test → Expected: sạch, pass.

### Task 6: Màn rà soát bản nháp (`/assistant/review`)

**Files:**
- Create: `lib/features/assistant/presentation/screens/transaction_review_screen.dart`, `test/features/assistant/transaction_review_test.dart`
- Modify: `lib/routes/app_router.dart` (route `/assistant/review`)

**Interfaces:**
- Consumes: `DraftTransaction`, `accountsControllerProvider`, `categoriesProvider`, `transactionControllerProvider.notifier` (`createTransaction(..., source)`, `transferInternal`), `assistantControllerProvider.notifier.resolveDraft`.
- Produces: `class ReviewArgs { final DraftTransaction draft; final int? messageId; const ReviewArgs(this.draft, {this.messageId}); }`; `class TransactionReviewScreen extends ConsumerStatefulWidget { const TransactionReviewScreen({super.key, required this.args}); final ReviewArgs args; }`. Route `/assistant/review` đọc `state.extra as ReviewArgs`.
- Hành vi: các trường sửa được — loại (Chi tiêu / Thu nhập / Chuyển tiền), số tiền (`MoneyInput` dùng `parseAmountInput`), danh mục (khớp `draft.categorySlug` với `Category.slug`), tài khoản (mặc định `suggestedAccountId`, nếu không có thì tài khoản đầu), tài khoản đích (chỉ khi chuyển), ghi chú/cửa hàng, ngày giờ (mặc định bây giờ nếu `transactedAt == null`). Banner cảnh báo khi `confidence < 0.85` hoặc `missingFields` không rỗng. Nút "Xác nhận & Lưu giao dịch" bị chặn (hiện lỗi inline, không gọi API) khi: số tiền không hợp lệ/0/vượt cap, chưa có tài khoản, chuyển tiền thiếu/trùng tài khoản. Lưu thành công: `Navigator.pop`, `resolveDraft(messageId, 'Đã ghi: <số tiền> · <danh mục>')` nếu có `messageId`, SnackBar "Đã ghi nhận giao dịch thành công!". Lỗi lưu hiện `errorMessage(e)` ngay trong màn.

- [ ] **Step 1: Test (RED)** — widget test với mock `TransactionController` (ghi lại tham số): `bản nháp 'luong 20 trieu' (debit) cho đổi sang Thu nhập và lưu với type == income, source == 'Manual'`; `draft.source == voice` lưu với `source: 'Voice'`; `receipt` → `'Receipt'`; số tiền `null`/`0`/`1000000000000` → hiện 'Vui lòng nhập số tiền hợp lệ' và không gọi `createTransaction`; không có tài khoản → 'Bạn cần có ít nhất một tài khoản để lưu giao dịch'; chuyển tiền cùng tài khoản → 'Tài khoản nguồn và đích không được trùng nhau', khác nhau → gọi `transferInternal` (không có danh mục); `missingFields: ['category']` hiện banner 'AI cần bạn kiểm tra lại một số chi tiết'; `categorySlug: 'food'` chọn sẵn chip 'Ăn uống'; `transactedAt == null` dùng thời điểm hiện tại; lỗi lưu hiện thông điệp; thành công gọi `resolveDraft`.
- [ ] **Step 2: Chạy** → Expected: FAIL.
- [ ] **Step 3: Implement** màn hình theo Interfaces (tái sử dụng bố cục/trường của `transaction_preview_screen.dart` hiện có, nhưng không phụ thuộc `draftId`).
- [ ] **Step 4: Chạy** analyze + toàn bộ test → Expected: sạch, pass.

### Task 7: Màn Chatbot, điểm vào Trang chủ và sheet Ghi chép; bỏ luồng AI cũ

**Files:**
- Create: `lib/features/assistant/presentation/screens/assistant_screen.dart`, `lib/features/assistant/presentation/widgets/chat_cards.dart`, `lib/features/assistant/presentation/widgets/assistant_prompt_bar.dart`, `test/features/assistant/assistant_screen_test.dart`
- Modify: `lib/routes/app_router.dart` (route `/assistant`), `lib/features/dashboard/presentation/screens/home_screen.dart` (thêm `AssistantPromptBar` đúng chỗ thẻ Finny cũ), `lib/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart` (tab "AI Text" chỉ còn mô tả + nút mở `/assistant`), `lib/features/transactions/presentation/controllers/transaction_controller.dart` (xóa `parseNlp`, `confirmDraft`), `lib/features/transactions/data/transaction_repository.dart` (xóa `parseNlpText`, `updateDraft`, `confirmDraft`), `test/features/transactions/transaction_test.dart`, `test/features/transactions/transaction_controller_test.dart`, `test/features/transactions/transaction_repository_test.dart`, `test/features/dashboard/dashboard_test.dart`
- Delete: `lib/features/transactions/presentation/screens/transaction_preview_screen.dart`, `lib/features/transactions/domain/entities/transaction_preview.dart`

**Interfaces:**
- Consumes: `assistantControllerProvider` (Task 5), `ReviewArgs` (Task 6), `accountsControllerProvider`.
- Produces: `class AssistantScreen extends ConsumerStatefulWidget { const AssistantScreen({super.key, this.startWith}); final String? startWith; }` (`startWith` ∈ `'voice'|'scan'|null`, dùng ở Task 8–9). Route `/assistant?start=voice|scan` đọc `state.uri.queryParameters['start']`.
- Produces: thẻ trong `chat_cards.dart` — `SavedCardView`, `SummaryCardView`, `DraftCardView` (nút "Xem và lưu" → `context.push('/assistant/review', extra: ReviewArgs(draft, messageId: id))`, các trường thiếu có nhãn "Cần bổ sung"; khi `resolved` hiện `resolvedSummary`), bong bóng `UserBubble`/`AssistantBubble`/`ErrorNoteView` (nút "Gửi lại" → `retry`).
- Produces: `AssistantPromptBar` — hàng một dòng "Hỏi FinMate: ăn phở 45k, tháng này tôi tiêu bao nhiêu?" chạm → `context.push('/assistant')`.
- Giao diện chat: danh sách cuộn tự xuống cuối, ô nhập (nút gửi bị khóa khi rỗng/đang gửi), chip tài khoản mặc định (chọn từ `accountsControllerProvider`; mặc định ví tiền mặt nếu có), gợi ý nhanh khi trống ("ăn phở 45k", "tháng này tôi tiêu bao nhiêu?"), chỉ báo đang trả lời, mất mạng → `ErrorNote`.

- [ ] **Step 1: Test (RED)** — `assistant_screen_test.dart` với `AssistantController` giả: hiện gợi ý khi chưa có tin nhắn; chạm gợi ý gửi đúng chuỗi; nhập rồi gửi gọi `send`, ô nhập được xóa; từng loại tin nhắn render đúng (`SavedCard` hiển thị '-55.000 ₫' và 'Ăn uống', `SummaryCard` hiển thị 'tháng này', tổng chi và dòng danh mục kèm %, `DraftCard` hiển thị 'Cần bổ sung' cho `missingFields` và nút 'Xem và lưu' điều hướng sang `/assistant/review`, `ErrorNote` có 'Gửi lại'); nút gửi bị vô hiệu khi `isSending`; chip tài khoản đổi `selectedAccountId`. Cập nhật test cũ: xóa các ca về `TransactionPreview*`, `parseNlp`, `confirmDraft`, `updateDraft`; `dashboard_test` kỳ vọng thấy thanh 'Hỏi FinMate' thay vì Finny; `transaction_test` kỳ vọng tab 'AI Text' có nút 'Mở trợ lý'.
- [ ] **Step 2: Chạy** `flutter test --no-pub` → Expected: FAIL.
- [ ] **Step 3: Implement** như Interfaces; xóa hai file và các hàm cũ; thêm route (query `start` đọc nhưng chưa xử lý tới Task 8–9).
- [ ] **Step 4: Chạy** analyze + toàn bộ test → Expected: sạch, pass.
- [ ] **Step 5: Quét sót** — `grep -rniE "TransactionPreview|parseNlp|confirmDraft|updateDraft|parseNlpText" lib test` → Expected: không còn kết quả.

### Task 8: Màn giọng nói (`/assistant/voice`)

**Files:**
- Create: `lib/features/assistant/presentation/screens/voice_screen.dart`, `test/features/assistant/voice_screen_test.dart`
- Modify: `lib/routes/app_router.dart` (route `/assistant/voice`), `lib/features/assistant/presentation/screens/assistant_screen.dart` (nút micro ở ô nhập; xử lý `startWith == 'voice'` bằng `addPostFrameCallback`), `lib/features/assistant/presentation/widgets/assistant_prompt_bar.dart` (biểu tượng micro → `/assistant?start=voice`), `lib/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart` (tab "Giọng nói": mô tả + nút "Nói để ghi chép" → `/assistant?start=voice`, bỏ "Sắp ra mắt")

**Interfaces:**
- Consumes: `speechServiceProvider` (Task 4), `AssistantController.send(text, source: DraftSource.voice)`.
- Produces: `class VoiceScreen extends ConsumerStatefulWidget` trả `String?` qua `Navigator.pop(text)`; trạng thái: `initializing` → `ready` → `listening` (chữ hiện dần từ `SpeechUpdate`) → `review` (ô chữ sửa được, nút "Nói lại" và "Gửi cho trợ lý"); `denied` ("Cần quyền micro để ghi âm" + hướng dẫn bật quyền trong Cài đặt), `unsupported` ("Thiết bị chưa hỗ trợ nhận dạng giọng nói" + "Nhập bằng bàn phím"), `empty` ("Mình chưa nghe thấy gì, bạn thử lại nhé"). Nút "Gửi cho trợ lý" bị khóa khi chữ rỗng/chỉ khoảng trắng. Chat: `final text = await context.push<String>('/assistant/voice'); if (text != null) controller.send(text, source: DraftSource.voice)`.

- [ ] **Step 1: Test (RED)** — `FakeSpeechService` (Task 4): `available` + hai `SpeechUpdate` rồi `isFinal` → màn hiện chữ cuối, "Gửi cho trợ lý" trả đúng chuỗi sau khi sửa; `denied` → hiện 'Cần quyền micro để ghi âm'; `unsupported` → hiện thông báo và nút nhập bàn phím; kết thúc mà không có chữ → 'Mình chưa nghe thấy gì' và nút gửi bị khóa; "Nói lại" gọi `listen` lần hai; thoát màn hình gọi `stop()`. Chat: mở từ nút micro → `send` được gọi với `source: voice`; `AssistantScreen(startWith: 'voice')` tự mở màn voice một lần.
- [ ] **Step 2: Chạy** → Expected: FAIL.
- [ ] **Step 3: Implement** theo Interfaces (animation lắng nghe đơn giản bằng `AnimatedContainer`; xin quyền khi bấm micro lần đầu qua `initialize()`; KHÔNG thêm thư viện mở cài đặt: trạng thái `denied` chỉ hiển thị hướng dẫn "Vào Cài đặt > Ứng dụng > FinMate > Quyền > Micro", nên bỏ nút "Mở cài đặt").
- [ ] **Step 4: Chạy** analyze + toàn bộ test → Expected: sạch, pass.

### Task 9: Màn quét hóa đơn (`/assistant/scan`)

**Files:**
- Create: `lib/features/assistant/presentation/screens/receipt_scan_screen.dart`, `test/features/assistant/receipt_scan_test.dart`
- Modify: `lib/routes/app_router.dart` (route `/assistant/scan`), `lib/features/assistant/presentation/screens/assistant_screen.dart` (nút máy ảnh; xử lý `startWith == 'scan'`), `lib/features/assistant/presentation/widgets/assistant_prompt_bar.dart` (biểu tượng máy ảnh → `/assistant?start=scan`), `lib/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart` (tab "Hóa đơn": nút "Quét hóa đơn" → `/assistant?start=scan`, bỏ "Sắp ra mắt")

**Interfaces:**
- Consumes: `receiptImageSourceProvider` (Task 4), `assistantRepositoryProvider.scanReceipt(String)` (Task 3), `AssistantController.addDraft`.
- Produces: `class ReceiptScanScreen extends ConsumerStatefulWidget` trả `DraftTransaction?` qua `Navigator.pop`. Luồng: chọn "Chụp ảnh"/"Chọn ảnh từ thư viện" → xem ảnh (nếu đường dẫn `null` thì ở lại màn đầu, không lỗi) → "Quét hóa đơn" → trạng thái "Đang đọc hóa đơn..." → thành công: pop `scan.draft`. `ocrResult` ≠ success hoặc `amountCents == null` → thông báo "Không đọc được hóa đơn. Bạn thử chụp rõ hơn hoặc nhập tay." với "Thử ảnh khác" và "Nhập tay" (mở sheet Ghi chép tab Thủ công); `ImageSourceException` → hiện `message` + hướng dẫn cấp quyền camera/thư viện; lỗi API hiện `errorMessage(e)` + "Thử lại". Chat: `final draft = await context.push<DraftTransaction>('/assistant/scan'); if (draft != null) controller.addDraft(draft)`. Với `confidence < 0.85` hoặc `transactedAt == null`, thẻ nháp/màn rà soát đã có cảnh báo (Task 6).

- [ ] **Step 1: Test (RED)** — `FakeImageSource` + `AssistantRepository` giả: chọn ảnh từ thư viện rồi quét thành công (fixture `scan_receipt_success`) → màn pop `DraftTransaction` (`amount 55000`, `receipt`); hủy chọn (`null`) → vẫn ở màn chọn ảnh; `ImageSourceException` → hiện thông báo quyền; `ocrResult: 'failed'` → 'Không đọc được hóa đơn' với hai nút; lỗi mạng → thông báo + 'Thử lại' gọi lại đúng ảnh; hai lần bấm "Quét hóa đơn" liên tiếp chỉ gọi `scanReceipt` một lần; chat nhận `addDraft` khi màn trả kết quả và `AssistantScreen(startWith: 'scan')` tự mở màn scan một lần.
- [ ] **Step 2: Chạy** → Expected: FAIL.
- [ ] **Step 3: Implement** theo Interfaces.
- [ ] **Step 4: Chạy** analyze + toàn bộ test → Expected: sạch, pass.

### Task 10: Tích hợp, kiểm chứng backend thật và dọn dẹp

**Files:**
- Modify: `test/integration/app_flow_test.dart`, `test/live/contract_live_test.dart`

**Interfaces:**
- Consumes: toàn bộ Task 1–9.

- [ ] **Step 1: Test (RED)** — mở rộng backend giả trong `app_flow_test.dart` với `POST /transactions/chat` (trả `saved`, `summary`, `confirm` theo từ khóa trong `text`), `POST /transactions/parse` và `POST /transactions/scan-receipt`: (a) Trang chủ → bấm 'Hỏi FinMate' → gửi "cafe 55k" → thấy thẻ đã ghi và số dư Trang chủ giảm; (b) gửi "luong 20 trieu" → thẻ nháp thiếu danh mục → 'Xem và lưu' → đổi sang Thu nhập → lưu với `source: Manual` → số dư tăng; (c) chat có `FakeSpeechService` trả 'ăn phở 45k' → thẻ đã ghi và `source` của yêu cầu chat đã gửi đúng văn bản; (d) có `FakeImageSource` + scan → thẻ nháp có 55.000 ₫, mở rà soát, lưu với `source: 'Receipt'`; (e) đăng xuất rồi đăng nhập lại: chat trống; (f) không còn màn/chuỗi gamification ở Cá nhân.
- [ ] **Step 2: Chạy** `flutter test --no-pub test/integration` → Expected: FAIL trước khi chỉnh backend giả/test; sau đó PASS.
- [ ] **Step 3:** Mở rộng `contract_live_test.dart` (chỉ chạy khi có `FINMATE_*`): `chat` "an trua 45k" rồi xóa giao dịch tạo ra; `chat` "tháng này tôi tiêu bao nhiêu" trả `summary`; `parse` "an trua com tam 45k"; `scanReceipt('test/fixtures/receipt_sample.png')` trả `success`; **kiểm chứng idempotency của chat**: gửi hai lần cùng `clientRequestId` → cùng `transaction.id` hoặc ghi vào ledger kết quả thực tế (nếu tạo hai giao dịch thì ghi rõ và xóa cả hai).
- [ ] **Step 4:** Chạy test live với tài khoản thử trong `docs/dev-test-account.md` (nạp vào biến môi trường mà không in ra); Expected: PASS. Nếu response khác giả định, sửa model và fixture rồi chạy lại toàn bộ.
- [ ] **Step 5: Kiểm tra cuối** — `flutter analyze --no-pub` sạch; `flutter test --no-pub` pass (test live ghi nhận skipped khi không có biến môi trường); `grep -rniE "gamification|mascot|finny" lib test` rỗng; báo người dùng những gì **chưa kiểm chứng**: micro/camera thật, nhận dạng giọng nói tiếng Việt trên máy, build Android/iOS với quyền mới.

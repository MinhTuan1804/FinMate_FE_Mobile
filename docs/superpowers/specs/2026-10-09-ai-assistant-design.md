# Trợ lý AI (Chatbot + Giọng nói + Quét hóa đơn) và gỡ Gamification

Ngày: 2026-10-09 · Trạng thái: chờ duyệt

## 1. Mục tiêu và tiêu chí thành công

Người dùng ghi chép và hỏi về chi tiêu bằng ba cách tự nhiên: **gõ câu hỏi/lệnh cho chatbot**, **nói**, hoặc **chụp hóa đơn**, tất cả nối với API AI của backend; đồng thời gỡ toàn bộ giao diện gamification.

Thành công khi:
- Từ Trang chủ hoặc sheet Ghi chép, người dùng mở được Chatbot, gửi "cafe highlands 55k" và thấy giao dịch được ghi (số dư cập nhật); hỏi "tháng này tôi tiêu bao nhiêu" thấy thẻ tóm tắt đúng số liệu backend.
- Câu thiếu thông tin (hoặc chuyển tiền) cho ra thẻ nháp, người dùng bổ sung ở màn rà soát rồi lưu được.
- Nói một câu → chữ hiện dần → gửi vào chat; chụp/chọn ảnh hóa đơn → thẻ nháp có số tiền/cửa hàng do OCR đọc.
- Không còn module, màn hình, provider hay chuỗi nào của gamification (Finny, cấp độ, XP, nhiệm vụ, tủ đồ).
- `flutter analyze` sạch, toàn bộ test pass, test tích hợp với backend thật pass cho chat/parse/scan-receipt.

**Ngoài phạm vi:** lưu lịch sử chat trên máy/máy chủ, trả lời bằng giọng nói (TTS), chỉnh sửa hay xóa giao dịch bằng chat (backend từ chối: "chỉ giúp ghi chi tiêu, thu nhập và xem tổng"), nhận dạng giọng nói ở phía máy chủ, quét nhiều hóa đơn một lúc, đợt giao diện 3 (font, theme).

## 2. Hợp đồng backend đã kiểm chứng (gọi thật, AI service healthy)

Phong bì chung: `{success, data, error:{code,message,details}, meta}`.

| Endpoint | Request | Response `data` |
|---|---|---|
| `POST /transactions/chat` | JSON `{text, financialAccountId?, clientRequestId?}` | `{action, intent, replyText, transaction, draft, summary}` |
| `POST /transactions/parse` | JSON `{text}` | `{amountCents, transactionType: "debit"\|"credit", merchantName, description, transactedAt, categorySlug}` — **stateless, không có id**; mọi trường có thể `null` |
| `POST /transactions/scan-receipt` | `multipart/form-data`, field `file` (ảnh) | `{ocrResult: "success"\|…, amountCents, transactionType, merchantName, transactedAt (có thể null), categorySlug, confidence (0–1), scanId}` |
| `POST /transactions` / `/transactions/transfer` | như hiện tại; `source`: `Notification\|Manual\|Voice\|Receipt` | giao dịch đã lưu |

`chat.action` (kiểm chứng):
- **`saved`**: `transaction` là giao dịch đã tạo (đã `Confirmed`, kèm `categoryName`, `balanceAfterCents`). Ví dụ "cafe highlands 55k".
- **`summary`**: `summary = {metric, periodLabel, from, to, totalCents, incomeCents, expenseCents, leftCents, items:[{categorySlug, categoryName, amountCents, share}]}`. Ví dụ "tháng này tôi tiêu bao nhiêu".
- **`reply`**: `replyText` là câu trả lời (`intent`: `out_of_scope`, `needs_amount`).
- **`confirm`**: `draft = {kind: "expense"\|"transfer", amountCents, transactionType, merchantName, description, categorySlug, incomeType, toOthers, suggestedFinancialAccountId, missingFields:[…]}` — `missingFields` gặp `["category"]` hoặc `["accounts"]`. Người dùng bổ sung rồi FE tự lưu bằng `POST /transactions` hoặc `/transactions/transfer`.

**Quirk đã gặp:** "lương 20 triệu" được trả về `intent: add_expense`, `transactionType: "debit"` (sai loại). Màn rà soát luôn cho đổi Chi/Thu/Chuyển. `parse` đúng cho "lương công ty 20 triệu" (`credit`, `income`), nên không dựa vào `intent` để quyết định loại.

Giọng nói: **không có endpoint**; dùng nhận dạng trên máy rồi gửi văn bản qua `chat`.

## 3. Kiến trúc

Module mới `features/assistant/` (`domain`, `data`, `presentation`), dùng lại `ApiClient`, `TransactionRepository`, `accountsControllerProvider`, `categoriesProvider`, `parseAmountInput`, `errorMessage`.

### 3.1 Dữ liệu (`domain` + `data`)
- `ChatReply { ChatAction action; String? intent; String? replyText; TransactionEntity? transaction; DraftTransaction? draft; ChatSummary? summary }` với `ChatAction { saved, summary, reply, confirm }`; `fromJson` chịu lỗi (action lạ → `reply` với thông điệp chung).
- `DraftTransaction { DraftKind kind; BigInt? amountCents; TransactionType? type; String? merchantName; String? description; String? categorySlug; String? suggestedAccountId; List<String> missingFields; DraftSource source; DateTime? transactedAt; double? confidence }` — dùng chung cho chat `confirm`, `parse` và `scan-receipt`. `DraftSource { chat, voice, receipt }` ánh xạ `source` khi lưu (`Manual`, `Voice`, `Receipt`).
- `ChatSummary` + `ChatSummaryItem`; `ReceiptScan` (từ `scan-receipt`) có `toDraft()`.
- `AssistantRepository { Future<ChatReply> chat(String text, {String? accountId}); Future<DraftTransaction> parse(String text); Future<ReceiptScan> scanReceipt(File image) }`. `scanReceipt` dùng `ApiClient.uploadFile` (`multipart`, field `file`). Mọi lỗi (mạng, 4xx, 5xx, AI service không sẵn sàng `NOTIFICATION_AI_SERVICE_UNAVAILABLE`) được ném lại cho giao diện, không có dữ liệu giả.
- Mở rộng `TransactionRepository.createTransaction/transferInternal` và `TransactionEntity.toRequestJson` nhận tham số `source` (mặc định `Manual`).

### 3.2 Trạng thái (`presentation/controllers`)
- `assistantControllerProvider` (`StateNotifier<AssistantState>`, tạo lại khi đổi user qua `currentUserIdProvider`, xóa khi đăng xuất): `AssistantState { List<ChatMessage> messages; bool isSending; String? selectedAccountId }`.
- `ChatMessage` (sealed): `UserText`, `AssistantText`, `SavedCard(TransactionEntity)`, `SummaryCard(ChatSummary)`, `DraftCard(DraftTransaction, resolved: bool)`, `ErrorNote(String)`. Lịch sử chỉ trong phiên (bộ nhớ).
- `send(String text, {DraftSource source = chat})`: thêm `UserText`, gọi `chat`; theo `action` thêm thẻ tương ứng; `saved` kích hoạt làm mới số dư/báo cáo qua cùng cơ chế `onDataChanged` hiện có; lỗi → `ErrorNote` có nút gửi lại. Chống gửi trùng khi `isSending`.
- `addDraft(DraftTransaction)` (cho kết quả quét hóa đơn), `saveDraft(DraftTransaction edited)` (dùng `TransactionRepository`, rồi đánh dấu thẻ `resolved`).

### 3.3 Giao diện và điều hướng
- **Route mới:** `/assistant` (chat), `/assistant/voice`, `/assistant/scan`, `/assistant/review` (rà soát; nhận `DraftTransaction` qua `extra`). `/profile` giữ lại, trỏ tới màn Cá nhân gọn.
- **Trang chủ:** thanh "Hỏi FinMate…" (giữ chỗ của thẻ Finny) có biểu tượng micro và máy ảnh; chạm mở `/assistant` (micro/máy ảnh mở chat và kích hoạt ngay màn voice/scan).
- **Sheet Ghi chép:** tab "AI Text", "Giọng nói", "Hóa đơn" mỗi tab là mô tả ngắn + một nút dẫn sang màn tương ứng (tab "Thủ công" giữ nguyên). Bỏ luồng `parse → preview → confirmDraft` và `TransactionPreviewScreen`, `TransactionPreview`, `updateDraft`, `confirmDraft`, `parseNlp` cũ.
- **Chat (`/assistant`):** danh sách tin nhắn cuộn, bong bóng người dùng lệch phải/trợ lý lệch trái; thẻ `SavedCard`, `SummaryCard` (tổng chi, còn lại, các danh mục với tỷ lệ), `DraftCard` (các trường còn thiếu được nhấn mạnh, nút "Xem và lưu" → `/assistant/review`). Ô nhập có micro, máy ảnh, gửi; chip tài khoản mặc định (mặc định là ví tiền mặt nếu có, nếu không là tài khoản đầu); gợi ý nhanh khi trống ("ăn phở 45k", "tháng này tôi tiêu bao nhiêu?"). Trạng thái đang trả lời (ba chấm), lỗi, offline (gửi bị chặn kèm thông báo).
- **Giọng nói (`/assistant/voice`):** nút micro lớn, hiệu ứng khi nghe, chữ nhận dạng hiện dần; dừng → ô chữ sửa được + "Nói lại" / "Gửi cho trợ lý". Các trạng thái: chưa cấp quyền (nút "Mở cài đặt"), không hỗ trợ, không nghe thấy gì. Kết quả là chuỗi trả về chat (`DraftSource.voice`).
- **Quét hóa đơn (`/assistant/scan`):** "Chụp ảnh" / "Chọn từ thư viện" → xem ảnh → "Quét hóa đơn" (ảnh nén tối đa 1600px, chất lượng 85) → đang đọc → trả `DraftTransaction` (`DraftSource.receipt`) về chat. `ocrResult` khác `success` hoặc lỗi → thông báo "Không đọc được hóa đơn" kèm "Thử ảnh khác" / "Nhập tay".
- **Rà soát (`/assistant/review`):** các trường sửa được: loại (Chi/Thu/Chuyển), số tiền, danh mục (khớp `categorySlug` với danh mục của người dùng), tài khoản (mặc định `suggestedAccountId`), tài khoản đích (khi chuyển), ghi chú/cửa hàng, ngày giờ (mặc định hiện tại nếu `transactedAt` null). Cảnh báo khi `confidence < 0.85` hoặc có `missingFields`. Lưu bị chặn đến khi hợp lệ (số tiền dùng `parseAmountInput`, tối đa 999.999.999.999 ₫; chuyển tiền cần hai tài khoản khác nhau).
- **Cá nhân (`features/profile/`):** thông tin người dùng + đăng xuất (xác nhận khi còn giao dịch chưa đồng bộ, như hiện tại). Không còn cấp độ, XP, chuỗi ngày, tủ đồ.

### 3.4 Bọc plugin để test được
- `abstract class SpeechService { Future<bool> init(); Stream<SpeechEvent> listen({String locale}); Future<void> stop(); }` với bản thật dùng `speech_to_text` (locale `vi_VN`).
- `abstract class ReceiptImageSource { Future<File?> pickFromCamera(); Future<File?> pickFromGallery(); }` với bản thật dùng `image_picker` (`maxWidth/maxHeight 1600`, `imageQuality 85`).
- Cung cấp qua provider (`speechServiceProvider`, `receiptImageSourceProvider`) để test thay bằng bản giả.

### 3.5 Phụ thuộc và quyền
- Thêm `image_picker`, `speech_to_text` vào `pubspec.yaml` (đã được người dùng đồng ý).
- Android: `CAMERA`, `RECORD_AUDIO`, thêm vào `<queries>` hành động `android.speech.RecognitionService`; yêu cầu quyền lúc dùng (không lúc khởi động).
- iOS: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (nội dung tiếng Việt).

## 4. Gỡ Gamification

Xóa: `lib/features/gamification/` (toàn bộ), `test/features/gamification/`, `test/fixtures/api/{mascot,gamification_profile}.json`; widget Finny trong Home; route/import trong `app_router.dart`; `onGoalContributed`/`GoalContribution.newLevel/unlockedItems` và thông báo "lên cấp" trong màn Kế hoạch (nạp tiền chỉ còn thông báo "Đã nạp X ₫ vào mục tiêu!"); phần làm mới `gamificationProfileProvider/mascotItemsProvider` trong `transaction_controller.dart` và `planning_controller.dart`; các ca kiểm thử liên quan trong `dashboard_test.dart`, `app_flow_test.dart`, `contract_live_test.dart`, `planning_*_test.dart`. Backend vẫn cộng XP; FE bỏ qua `celebration` trong response nạp tiền.

## 5. Xử lý lỗi

- Mất mạng: chat/voice-gửi/scan hiển thị "Không có kết nối mạng" và cho gửi lại; không cho "ghi" qua chat khi offline (chat cần máy chủ). Lưu từ màn rà soát vẫn dùng hàng đợi offline hiện có (giao dịch được xếp hàng).
- `NOTIFICATION_AI_SERVICE_UNAVAILABLE` hoặc 5xx: thông báo thân thiện + gợi ý "Nhập thủ công" (mở tab Thủ công).
- Thiếu quyền camera/micro: màn tương ứng hiển thị lý do và nút mở cài đặt, không crash.
- Phản hồi lạ (action mới, thiếu trường): hiển thị `replyText` nếu có, ngược lại thông báo chung; mọi trường nullable được xử lý.

## 6. Kiểm thử

- Fixture mới lưu từ response thật: `chat_saved`, `chat_summary`, `chat_reply_out_of_scope`, `chat_reply_needs_amount`, `chat_confirm_expense`, `chat_confirm_transfer`, `parse_ok`, `parse_empty`, `scan_receipt_success`.
- Unit: parse từng `action`, `DraftTransaction` (kể cả `transactionType` `debit/credit` chữ thường), `ReceiptScan.toDraft`, `source` trong `toRequestJson`.
- Repository (adapter giả): đúng đường dẫn/body; `scanReceipt` gửi `multipart` field `file`; lỗi mạng/5xx/AI không sẵn sàng được ném lại.
- Controller: gửi chat từng `action` tạo đúng loại tin nhắn; chống gửi trùng; `saved` làm mới số dư; đăng xuất/đổi user xóa lịch sử.
- Widget: chat (từng loại thẻ, gợi ý khi trống, lỗi + gửi lại, offline), màn voice với `SpeechService` giả (nghe → chữ → gửi; quyền bị từ chối; không hỗ trợ), màn scan với `ReceiptImageSource` giả (kết quả, `ocrResult` lỗi, cảnh báo độ tin cậy thấp), màn rà soát (đổi Thu/Chi, trường thiếu chặn lưu, số tiền 0/quá lớn, chuyển tiền cùng tài khoản).
- Tích hợp (backend giả): Home → chat → "ăn phở 45k" → thẻ đã ghi → số dư đổi; chat → "lương 20 triệu" → thẻ nháp → đổi sang Thu → lưu; scan → thẻ nháp → lưu; gỡ gamification không để sót màn hình nào.
- Live (cần biến môi trường): gọi thật `chat` ("an trua 45k" rồi xóa giao dịch tạo ra), `parse`, `scan-receipt` với một ảnh PNG nhỏ trong `test/fixtures`.

## 7. Rủi ro và điểm chưa biết

- **Không kiểm thử được micro/camera thật** trong môi trường này; chỉ kiểm tra qua interface giả. Cần thử trên điện thoại.
- Nhận dạng giọng nói tiếng Việt phụ thuộc dịch vụ giọng nói của Google trên máy (emulator thường không có); hành vi khác nhau giữa máy.
- Độ chính xác phân loại của AI backend (ví dụ "lương" bị coi là chi) ngoài tầm FE; FE giảm rủi ro bằng màn rà soát.
- Chat có thể tự lưu giao dịch ngay (`saved`) mà không hỏi lại; chấp nhận theo thiết kế backend, đồng thời hiển thị thẻ "Đã ghi" có đường dẫn xem giao dịch để người dùng kiểm tra.
- Chống trùng khi gửi lại: `POST /transactions` đã được kiểm chứng là idempotent theo `clientRequestId`, còn với `transactions/chat` thì **chưa kiểm chứng**. FE vẫn gửi một `clientRequestId` mới cho mỗi tin nhắn người dùng và dùng lại đúng id đó khi bấm "Gửi lại"; cần kiểm chứng thêm bằng test live ở bước thực thi.

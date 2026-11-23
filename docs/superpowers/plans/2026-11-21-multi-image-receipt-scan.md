# Gửi nhiều ảnh hoá đơn song song — Kế hoạch triển khai

> **For agentic workers:** REQUIRED SUB-SKILL: dùng subagent-driven-development (khuyến nghị) hoặc executing-plans để làm từng task. Bước dùng checkbox `- [ ]`.

**Goal:** Chọn nhiều ảnh hoá đơn trong chat, quét song song mà không khoá chat.

**Architecture:** `ReceiptImageSource` thêm chọn nhiều ảnh; `AssistantController` có hàng đợi quét với trần song song 3 và bộ đếm `pendingScans` tách khỏi `isSending`; màn chat hiện bong bóng chờ theo `pendingScans`.

**Tech Stack:** Flutter 3.47, Riverpod, `image_picker` ^1.2.4, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-21-multi-image-receipt-scan-design.md`

## Global Constraints
- Chỉ sửa `FinMate_FE` (nhánh `dev/tuan`); backend không đổi, không đổi chữ ký `AssistantRepository.scanReceipt(String)`.
- `receiptMaxPerPick = 5`, `receiptScanConcurrency = 3` (hằng số công khai trong `receipt_image_source.dart` và `assistant_controller.dart`).
- Quét ảnh không đặt `isSending`; mọi chỗ khác dùng `isSending` giữ nguyên.
- Chú thích bằng tiếng Việt, trần cứng ghi `// ponytail:`. Chỉ `git add` đường dẫn cụ thể, không commit file tạm.

## Review Focus
- Chọn thư viện trả danh sách rỗng hoặc người dùng huỷ: không thêm tin nhắn nào (Task 1, 3).
- Hai lần chọn liên tiếp: tổng ảnh chạy cùng lúc không bao giờ quá 3 (Task 2).
- Một ảnh lỗi không làm các ảnh khác mất kết quả; thử lại không tạo `ImageNote` thứ hai (Task 2).
- Controller bị huỷ (`mounted == false`) giữa chừng: không ghi state sau khi huỷ, không ném lỗi (Task 2).
- Trong lúc đang quét, gửi chat văn bản vẫn chạy được (Task 2).

---

### Task 1: Chọn nhiều ảnh từ thư viện
**Files:** Modify `lib/features/assistant/data/receipt_image_source.dart`, `test/fixtures/fakes.dart`; Test `test/features/assistant/receipt_image_source_test.dart` (tạo nếu chưa có).

**Interfaces:**
- Produces: `const receiptMaxPerPick = 5;` và `Future<List<String>> ReceiptImageSource.pickMultipleFromGallery()`; `FakeImageSource` có `List<String> galleryPaths`, `int multiCalls`, và `pickMultipleFromGallery()` trả `galleryPaths` (ném `error` nếu có).

- [ ] **Step 1: Viết test** `pickMultipleFromGallery` của `ImagePickerSource` cần bọc được `ImagePicker`; nếu chưa bọc được thì chỉ test `FakeImageSource` ở đây và test việc cắt `receiptMaxPerPick` bằng một hàm thuần `List<String> clampPicked(List<String>)` (khẳng định: 7 đường dẫn → 5 đầu tiên; rỗng → rỗng).
- [ ] **Step 2: Chạy, kỳ vọng FAIL:** `flutter test test/features/assistant/receipt_image_source_test.dart`.
- [ ] **Step 3: Cài** `clampPicked`, `ImagePickerSource.pickMultipleFromGallery()` (`_picker.pickMultiImage(maxWidth: receiptMaxSide, maxHeight: receiptMaxSide, imageQuality: receiptJpegQuality, limit: receiptMaxPerPick)`, bọc `clampPicked`, bắt `PlatformException` ném `ImageSourceException` cùng thông báo quyền như `pickFromGallery`), thêm vào lớp trừu tượng và `FakeImageSource`.
- [ ] **Step 4: Chạy lại, kỳ vọng PASS**, rồi `flutter analyze lib/features/assistant/data test/fixtures` không lỗi.
- [ ] **Step 5: Commit** `git add lib/features/assistant/data/receipt_image_source.dart test/fixtures/fakes.dart test/features/assistant/receipt_image_source_test.dart` — `feat(mobile): chọn nhiều ảnh hoá đơn từ thư viện`.

---

### Task 2: Hàng đợi quét song song trong controller
**Files:** Modify `lib/features/assistant/presentation/controllers/assistant_controller.dart`; Test `test/features/assistant/chat_media_test.dart`.

**Interfaces:**
- Consumes: `repository.scanReceipt(String)` (không đổi).
- Produces: `const receiptScanConcurrency = 3;` `AssistantState.pendingScans` (int, mặc định 0, có trong `copyWith`); `Future<void> AssistantController.scanReceipts(List<String> paths)` (hoàn tất khi TẤT CẢ ảnh vừa được thêm đã xong); `scanReceipt(String path) => scanReceipts([path])`.

- [ ] **Step 1: Viết test (trong nhóm `AssistantController.scanReceipt`), repo giả có `Completer` cho từng ảnh:**
  - `quét hai ảnh: hai ImageNote ngay lập tức, isSending luôn false, pendingScans 2 rồi 0`.
  - `không quá 3 ảnh chạy cùng lúc`: 5 ảnh, đếm số lệnh `scanReceipt` đang mở (tối đa 3), hoàn tất dần, cả 5 thẻ nháp cuối cùng.
  - `hai lần scanReceipts liên tiếp vẫn tối đa 3 đang mở`.
  - `một ảnh lỗi tạo ErrorNote riêng, ảnh khác vẫn ra DraftCard`; `thử lại ảnh lỗi không thêm ImageNote`.
  - `trong lúc quét vẫn gửi được chat văn bản` (`send('xin chào')` chạy, không bị `isSending` chặn).
  - `controller bị dispose giữa chừng không ném lỗi` (`dispose()` rồi hoàn tất `Completer`).
  - Sửa test cũ `đang quét thì bỏ qua yêu cầu quét thứ hai` (chat_media_test.dart:~128) thành khẳng định MỚI: hai lần `scanReceipt` đều được thực hiện (`repo.scanned` có 2 phần tử).
- [ ] **Step 2: Chạy, kỳ vọng FAIL:** `flutter test test/features/assistant/chat_media_test.dart`.
- [ ] **Step 3: Cài.** `pendingScans` vào `AssistantState`. `scanReceipts`: bỏ qua nếu danh sách rỗng; với mỗi đường dẫn thêm `ImageNote`, đẩy vào hàng đợi `_scanQueue`, tăng `pendingScans`; gọi `_pumpScans()` rồi trả `Future.wait` các Completer của lô. `_pumpScans`: trong khi `_activeScans < receiptScanConcurrency` và hàng đợi không rỗng, lấy một ảnh, chạy `_scan(path)` (đã bỏ đặt `isSending`; giữ nhánh kết quả/lỗi hiện có và `_failedScans`), khi xong giảm `_activeScans`/`pendingScans` (chỉ khi `mounted`) và gọi lại `_pumpScans`. `retry` cho `_failedScans` đưa đường dẫn vào hàng đợi (không thêm `ImageNote`, không còn chặn bởi `isSending`). `# ponytail: hàng đợi trong bộ nhớ, mất khi đóng màn chat`.
- [ ] **Step 4: Chạy lại, kỳ vọng PASS** (cả `chat_media_test.dart` và `assistant_controller_test.dart` để hồi quy).
- [ ] **Step 5: Commit** `git add lib/features/assistant/presentation/controllers/assistant_controller.dart test/features/assistant/chat_media_test.dart` — `feat(mobile): quét nhiều ảnh hoá đơn song song, không khoá chat`.

---

### Task 3: Nối vào màn chat và bong bóng chờ
**Files:** Modify `lib/features/assistant/presentation/screens/assistant_screen.dart` (đoạn chọn ảnh ~dòng 207-227 và danh sách tin ~dòng 255-290); Test `test/features/assistant/assistant_screen_test.dart`.

**Interfaces:** Consumes `pickMultipleFromGallery`, `scanReceipts`, `AssistantState.pendingScans` (Tasks 1, 2).

- [ ] **Step 1: Viết test widget (dùng `FakeImageSource`, repo giả):** chọn "Chọn ảnh từ thư viện" với `galleryPaths` 2 ảnh → hai bong bóng ảnh, bong bóng chờ "Đang đọc 2 hóa đơn...", ô nhập chat không bị vô hiệu; 1 ảnh → "Đang đọc hóa đơn..."; thư viện trả rỗng → không thêm gì.
- [ ] **Step 2: Chạy, kỳ vọng FAIL:** `flutter test test/features/assistant/assistant_screen_test.dart`.
- [ ] **Step 3: Cài.** Nhánh `'gallery'` gọi `pickMultipleFromGallery()` rồi `scanReceipts(paths)`; `'camera'` giữ một ảnh qua `scanReceipt`. Bong bóng chờ hiện khi `state.isSending || state.pendingScans > 0` (`sendingOffset` tính theo điều kiện này); chữ: nếu `isAskingAgent` giữ nguyên, nếu chỉ đang quét thì `pendingScans == 1 ? 'Đang đọc hóa đơn...' : 'Đang đọc $pendingScans hóa đơn...'`, còn lại giữ như cũ. `_buildInput(context, state.isSending)` giữ nguyên (không khoá ô nhập khi chỉ đang quét).
- [ ] **Step 4: Chạy, kỳ vọng PASS**, rồi toàn bộ `flutter test test/features/assistant` và `flutter analyze lib/features/assistant`.
- [ ] **Step 5: Commit** `git add lib/features/assistant/presentation/screens/assistant_screen.dart test/features/assistant/assistant_screen_test.dart` — `feat(mobile): chọn nhiều ảnh trong chat và chỉ báo đang đọc N hoá đơn`.

---

## Self-review
- **Phủ spec:** mục 1 → Task 1; mục 2, 3, 4 → Task 2; mục 5 → Task 3; trần 5/3 → Task 1/2.
- **Nhất quán tên:** `pickMultipleFromGallery`, `scanReceipts`, `pendingScans`, `receiptMaxPerPick`, `receiptScanConcurrency` dùng đúng một tên xuyên suốt.
- **Rủi ro cần để mắt:** `pickMultiImage(limit:)` yêu cầu `image_picker` ≥ 1.1 (đã có 1.2.4); không chạy được trên máy thật trong kế hoạch này nên chọn nhiều ảnh thật chưa kiểm chứng ngoài test giả.

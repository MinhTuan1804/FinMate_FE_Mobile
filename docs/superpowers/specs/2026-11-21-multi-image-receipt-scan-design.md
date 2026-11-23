# Gửi nhiều ảnh hoá đơn cùng lúc trong chat (chạy song song ở app)

Ngày: 2026-11-21 · Trạng thái: đã duyệt trong chat · Phạm vi: chỉ app (`FinMate_FE`), backend không đổi

## Vì sao
Quét một ảnh mất 9 đến 22 giây (đo ngày 2026-11-16) và trong lúc đó chat bị khoá (`isSending`), chỉ chọn được một ảnh mỗi lần. Người dùng muốn chọn nhiều ảnh và không phải chờ từng ảnh.

## Mục tiêu / không phải mục tiêu
- Mục tiêu: chọn nhiều ảnh từ thư viện, gửi song song, mỗi ảnh xong thì hiện thẻ nháp riêng, chat không bị khoá.
- Không làm: job nền ở server (người dùng chọn "chỉ chạy song song"; job nền buộc server giữ ảnh tạm, trái cam kết "ảnh không được lưu"); gộp nhiều ảnh thành một hoá đơn; đổi backend.

## Thiết kế
1. `ReceiptImageSource` thêm `Future<List<String>> pickMultipleFromGallery()` (dùng `pickMultiImage`, tối đa `receiptMaxPerPick = 5`, giữ `maxWidth/maxHeight/imageQuality` như `_pick`). Camera và "Quét bill" vẫn một ảnh.
2. `AssistantState` thêm `pendingScans` (số ảnh đang quét hoặc xếp hàng). Quét ảnh KHÔNG đặt `isSending`, nên gõ chat, gửi ảnh khác và các nút khác vẫn dùng được.
3. `AssistantController.scanReceipts(List<String>)`: mỗi ảnh thêm ngay một `ImageNote`, rồi đưa vào hàng đợi. Tối đa `receiptScanConcurrency = 3` ảnh chạy cùng lúc (toàn controller, không phải mỗi lần chọn). `scanReceipt(String)` giữ nguyên chữ ký, gọi `scanReceipts([path])`.
4. Lỗi tách riêng: ảnh lỗi chỉ tạo `ErrorNote` của nó (có nút thử lại như hiện nay); thử lại đưa ảnh vào hàng đợi, không thêm `ImageNote` mới.
5. Giao diện: khi `pendingScans > 0` hiện một bong bóng chờ ở cuối danh sách: "Đang đọc N hóa đơn..." (N = 1 giữ nguyên chữ "Đang đọc hóa đơn...").
6. Trần 5 ảnh mỗi lần chọn và 3 ảnh song song là lựa chọn của người thiết kế: server giới hạn tốc độ theo người dùng, và OCR cục bộ dự phòng chỉ chạy một ảnh một lúc nên gửi quá nhiều dễ timeout. `# ponytail:` ghi trần này trong mã.

## Rủi ro đã biết
- Thẻ nháp hiện theo thứ tự ảnh xong, không theo thứ tự chọn. Mỗi thẻ đi kèm `ImageNote` của nó nhưng chúng không nằm cạnh nhau.
- Khi Vision lỗi và OCR cục bộ chạy nối tiếp, ảnh thứ ba có thể chờ lâu hơn timeout phía backend (35 giây); lỗi đó hiện thành thẻ lỗi có nút thử lại.

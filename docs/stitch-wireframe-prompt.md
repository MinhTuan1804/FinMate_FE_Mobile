# Prompt Stitch – WIREFRAME FinMate (bản phác thảo, theo một flow)

> Dán **toàn bộ khối bên dưới** vào Stitch một lần. Đây là wireframe độ trung thực thấp: chỉ khung, nhãn và luồng, chưa màu sắc, chưa dữ liệu chi tiết. Bản UI hoàn chỉnh dùng `stitch-prompt-finmate.md`.

```
Create a LOW-FIDELITY WIREFRAME set (not a finished UI) for a Vietnamese mobile app "FinMate"
(personal finance + AI assistant). Mobile portrait 390×844.

STYLE OF THE WIREFRAME
- Grayscale only (white, light gray, mid gray, dark gray lines). No brand colors, no photos,
  no gradients, no shadows. Simple rectangles, rounded boxes, "X" boxes for images/charts.
- Plain system-like sans font. Short Vietnamese labels only; use placeholder numbers like
  "000.000 ₫". No long paragraphs (use gray bars for text blocks).
- Every screen: a small screen number + name on top (e.g. "01 · Welcome") and arrows or labels
  showing where each button leads. Same component shapes everywhere (button = rounded rect with
  label, input = rectangle with label, list row = line with left icon box and right value).
- Icons are plain labeled squares. No emoji, no gamification (no points, levels, badges).

FLOW – draw the screens in this exact order, connected by arrows (one main path, side branches
marked "nhánh"):

A. ĐĂNG KÝ & THIẾT LẬP
 01 Welcome: logo box, headline, "Cam kết bảo mật" box, checkbox "Đồng ý điều khoản"
    (links → 22, 23), buttons [Tạo tài khoản mới] [Đăng nhập với Email].
 02 Đăng ký: inputs Tên, Email, Mật khẩu, Nhập lại mật khẩu; [Đăng ký].
 03 Xác thực email (OTP): 6 code boxes, [Xác nhận], link "Gửi lại mã".
 04 Đăng nhập: inputs Email, Mật khẩu; [Đăng nhập]; (nhánh: người dùng cũ vào thẳng từ 01).
 05 Thiết lập ban đầu – 3 frames with a step bar: (a) giới thiệu ghi nhận tự động,
    (b) chọn nguồn theo dõi (list with toggles), (c) nhập thu nhập tháng + [Hoàn tất].

B. TRANG CHỦ & TRỢ LÝ AI
 06 Trang chủ: header (tên + icon người dùng → 16), box "Tổng số dư", 2–3 chip tài khoản,
    thanh "Hỏi FinMate…" kèm 2 icon (quét, mic) → 07, hàng 4 nút nhanh, danh sách "Giao dịch gần
    đây" 3 dòng, thanh điều hướng dưới 4 tab [Trang chủ][Giao dịch][Kế hoạch][Phân tích] và nút
    nổi [Ghi chép] → 09. Một banner mascot (ô tròn + 2 dòng chữ + nút) đặt ở đầu khi vượt ngưỡng.
 07 Chat trợ lý (kiểu Messenger, 1 màn duy nhất): app bar, vùng tin nhắn (bong bóng trái = AI,
    phải = người dùng, 1 bong bóng ảnh, 1 thẻ "Đã ghi giao dịch", 1 thẻ "Cần xác nhận" có nút
    [Xem và lưu]), chip "Ghi vào: <tài khoản>", thanh nhập: [icon quét] [ô nhắn] [icon mic] [Gửi].
    Vẽ thêm 2 frame phụ: (a) đang nói: ô nhắn hiện "Đang nghe…", mic đổi thành dừng;
    (b) bấm quét: sheet 3 dòng [Quét bill] [Chụp ảnh] [Chọn ảnh từ thư viện].
 08 Xác nhận giao dịch (dùng chung): chip loại [Chi][Thu][Chuyển], ô Số tiền, Danh mục, Tài khoản,
    Cửa hàng, Ghi chú, Ngày; ô cảnh báo "AI cần bạn kiểm tra lại"; [Xác nhận & Lưu] → quay lại 07.
 09 Sheet Ghi chép (từ nút nổi): chỉ form nhập tay (chip loại, Số tiền, Danh mục dạng lưới,
    Tài khoản, Ghi chú, [Lưu giao dịch]) + nút phụ [Nhắn cho AI] → 07.

C. QUẢN LÝ & PHÂN TÍCH (4 tab dưới)
 10 Giao dịch: ô tìm kiếm, chip lọc [Tất cả][Chi][Thu][Chuyển], danh sách nhóm theo ngày
    (tiêu đề ngày + tổng ngày), chạm dòng → sheet chi tiết giao dịch (frame phụ).
 11 Kế hoạch – tab "Ngân sách": thẻ "Chi an toàn hôm nay", thanh tiến độ tháng, danh sách ngân
    sách theo danh mục (thanh tiến độ), [Thêm]. Frame phụ: trạng thái chưa có ngân sách.
 12 Kế hoạch – tab "Mục tiêu tiết kiệm": thẻ mục tiêu (tên, thanh %, hạn), [Nạp tiền], [Tạo mục tiêu].
 13 Thống kê: thanh chọn [Ngày][Tuần][Tháng][Năm], bộ chuyển kỳ ‹ ›, ô "Tổng chi / thu", biểu đồ
    cột (mỗi cột có nhãn và SỐ TIỀN bên dưới), thẻ chi tiết khi chạm cột (tổng + danh sách giao
    dịch), biểu đồ tròn danh mục, thẻ dẫn sang 14. Vẽ 4 frame nhỏ cho 4 chế độ.
 14 Dự báo tài chính: số "Dự kiến chi cuối tháng", chip độ tin cậy, biểu đồ đường (thực tế liền,
    dự báo đứt, vạch ngân sách), thẻ "Số dư dự kiến cuối tháng", hộp lời khuyên AI.

D. CÁ NHÂN & CÀI ĐẶT
 15 (trống – dành cho mascot): frame "Banner mascot" 3 mức (sắp chạm / vượt / an toàn) gồm ô
    nhân vật, 2 dòng chữ, [Xem kế hoạch] [Để sau].
 16 Cá nhân & Cài đặt (từ icon người dùng): thẻ người dùng, dòng Thu nhập tháng, các nhóm dòng có
    chevron: Giao diện → 17 · Ngưỡng cảnh báo → 18 · Sao lưu → 19 · Nhập dữ liệu → 20 ·
    Tài khoản & nguồn → 21 · Điều khoản → 22 · Chính sách bảo mật → 23; 2 công tắc (Thông báo
    đẩy, Cảnh báo ngân sách); nút [Đăng xuất] → hộp thoại xác nhận → 01.
 17 Giao diện: 3 thẻ chọn [Sáng][Tối][Theo hệ thống], thanh trượt cỡ chữ, công tắc "Ẩn số dư".
 18 Ngưỡng cảnh báo: thanh ngân sách có 2 tay kéo (Sắp chạm, Vượt) + 2 ô số, công tắc Mascot /
    Thông báo, [Lưu] [Khôi phục mặc định].
 19 Sao lưu dữ liệu: thẻ "Lần sao lưu gần nhất", chip nội dung, [Tạo bản sao lưu], mục "Xuất báo
    cáo" (chọn khoảng ngày + định dạng CSV/Excel).
 20 Nhập dữ liệu: 4 frame có thanh bước: chọn file → xem trước (bảng 5 dòng + ánh xạ cột) →
    xử lý trùng lặp → kết quả.
 21 Tài khoản & nguồn: danh sách tài khoản (tên, số dư, công tắc theo dõi), [Thêm tài khoản].
 22 Điều khoản sử dụng / 23 Chính sách bảo mật: tiêu đề, mục lục chip, khối chữ (thanh xám).
 24 Sheet hỏi quyền (micro / camera / thông báo): icon, 1 dòng lý do, [Cho phép] [Để sau].

E. WIDGET ANDROID (vẽ ngoài app, trên nền màn hình chính)
 25 Widget nhỏ 2×2 (số lớn "Chi an toàn hôm nay" + vòng tiến độ), vừa 4×2 (số dư, đã chi, vòng,
    2 nút [Ghi chép][Hỏi FinMate]), lớn 4×4 (thêm dự báo, 3 giao dịch, 2 nút mic/quét).

AT THE END add one overview page: a flow map with all screen numbers as small boxes and arrows
showing: 01→02→03→04→05→06; 06→07→08→06; 06→09; bottom tabs 06/10/11/13; 13→14; avatar 06→16;
16→17/18/19/20/21/22/23; 16→01 (đăng xuất). Do not add any screen that is not listed.
```

## Ghi chú cho bạn
- Wireframe đánh số lại 01–25 theo thứ tự flow nên **khác mã S01–S26** trong file prompt UI; đối chiếu: Chat = 07, Xác nhận = 08, Thống kê = 13, Cài đặt = 16.
- Tôi đã dùng phương án **sheet Ghi chép chỉ còn form nhập tay + nút "Nhắn cho AI"** (bỏ 3 tab trùng với chat). Nếu bạn muốn giữ 4 tab, sửa mục 09.
- Mục 15 chỉ là khung mascot, chưa có hình nhân vật; bạn cần cung cấp hoặc chọn hình.

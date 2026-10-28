# FinMate_FE – Rules cho AI

Các rule dưới đây là BẮT BUỘC. Xung đột với mặc định của AI thì rule ở đây thắng.

## 1. Icon
- KHÔNG tự vẽ icon, KHÔNG dùng emoji làm icon, KHÔNG nhúng SVG do AI tự sinh.
- Chỉ dùng icon từ thư viện đã cài trong dự án (ưu tiên `lucide-react`; nếu dự án đã dùng thư viện khác như `react-icons`, `@heroicons/react`, `@phosphor-icons/react` thì dùng đúng thư viện đó, không trộn nhiều bộ).
- Chưa có thư viện icon → hỏi/đề xuất cài, rồi mới dùng. Import từng icon (`import { Wallet } from "lucide-react"`), không import cả bộ.
- Một bộ icon = một kích thước/stroke thống nhất toàn app.

## 2. Quy trình làm việc
- Trước mọi việc sáng tạo (tính năng mới, component, đổi hành vi): LUÔN gọi skill `superpowers:brainstorming` để làm rõ yêu cầu và lên luồng/thiết kế TRƯỚC khi code.
- Việc nhiều bước: dùng `superpowers:writing-plans` để lập kế hoạch, rồi mới thực thi.
- Gặp bug/lỗi: dùng `superpowers:systematic-debugging` trước khi sửa.
- Trước khi báo "xong": dùng `superpowers:verification-before-completion` (chạy build/lint/test thật, có bằng chứng).

## 3. Thiết kế UI
- Mọi việc liên quan giao diện (page, component, layout, style) PHẢI dùng các skill thiết kế UI: `ui-ux-pro-max` và `taste-skill`. Luôn gọi skill trước khi viết code UI, không thiết kế theo cảm tính.
- Nếu skill chưa cài/không tìm thấy: báo cho người dùng, không tự bỏ qua.
- Bắt buộc: responsive (mobile trước), dark/light nếu dự án có theme, đủ trạng thái (loading, empty, error, hover, focus, disabled), tương phản đủ chuẩn WCAG AA, có label/aria cho control, điều hướng được bằng bàn phím.
- Dùng design token (màu, spacing, font, radius) tập trung; không hard-code màu/px rải rác.
- Tránh "AI slop": gradient tím-xanh mặc định, card lồng card, bo góc/đổ bóng đại trà, lorem ipsum, số liệu bịa.

## 4. Code
- Đọc code hiện có và tái sử dụng component/hook/util sẵn có trước khi viết mới. Không tạo abstraction/thư viện mới khi chưa cần.
- Diff nhỏ nhất đáp ứng yêu cầu; không refactor ngoài phạm vi, không thêm tính năng không được yêu cầu.
- Giữ đúng convention hiện tại (đặt tên, cấu trúc thư mục, style, ngôn ngữ). Nếu dùng TypeScript: không `any` khi tránh được.
- Không cài dependency mới khi chưa hỏi; nêu rõ lý do và lựa chọn thay thế.
- Comment chỉ khi giải thích "tại sao"; comment cùng ngôn ngữ với code xung quanh.

## 5. Bảo mật & dữ liệu (app tài chính)
- KHÔNG commit hoặc hard-code secret, API key, token; dùng biến môi trường (`.env*` không được đưa vào git).
- Không log dữ liệu nhạy cảm (số tài khoản, số dư, token, thông tin cá nhân).
- Validate input ở ranh giới hệ thống; không render HTML thô từ người dùng (chống XSS).
- Số tiền: không dùng float cho phép tính; format tiền tệ/ngày tháng theo locale `vi-VN` qua `Intl`.
- Không bịa dữ liệu tài chính giả trong code production; mock chỉ đặt trong thư mục mock/fixture rõ ràng.

## 6. Giao tiếp
- Trả lời bằng tiếng Việt, ngắn gọn, đi thẳng vào việc.
- Việc không hoàn thành/không chắc → nói rõ, không giả vờ đã xong.
- Hành động khó hoàn tác (xoá file, force push, đổi cấu hình chung) → hỏi trước.

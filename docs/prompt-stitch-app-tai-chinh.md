# FinMate – Prompt for Stitch (mobile UI generator)

## HOW TO USE (read first, in Vietnamese)

- Stitch làm tốt nhất khi nhận **từng nhóm màn hình nhỏ**. Với mỗi lượt: dán **Block S (Style)** + **Block D (Sample data)** + **một Batch** bên dưới. Không dán cả file một lần.
- Hướng dẫn viết bằng tiếng Anh; mọi chữ trong ngoặc kép `"..."` là **nhãn hiển thị bằng tiếng Việt** và phải giữ nguyên.
- Sau mỗi batch, đối chiếu mục **Acceptance check** rồi mới sang batch kế. Nếu Stitch lệch màu/font, dán lại Block S kèm câu: *"Keep the exact same design system as before."*
- Thứ tự khuyến nghị: Batch 1 → 2 → 3 → 4 → 5 → 6.

---

## BLOCK S – STYLE (paste with every batch)

```
You are designing screens for "FinMate", a personal finance manager mobile app for Vietnamese users
(office workers aged 22–35, monthly income 10–30 million VND). Tone: friendly, trustworthy, calm, precise.
Canvas: 390 x 844 (iPhone 14), portrait. Design each screen as a separate frame.

LANGUAGE RULE: every visible UI string must be in Vietnamese with full diacritics, exactly as quoted in the
spec. Use a font that supports Vietnamese: "Plus Jakarta Sans" (fallback Inter). Never use lorem ipsum.
Never use English placeholder text in the UI.

STYLE: minimal "neo-fintech". Dark mode is the primary presentation (OLED-friendly); also provide a light
variant for Home only. Clean, generous whitespace, flat surfaces with 1px borders, very subtle shadow only on
floating elements. No purple-to-blue gradients, no glassmorphism, no nested cards, no decorative 3D.

COLOR TOKENS (dark):  background #0B1220 · surface #131C2E · surface-elevated #1A2540 · border #243049
  text-primary #F1F5F9 · text-secondary #94A3B8 · text-muted #64748B
COLOR TOKENS (light): background #F8FAFC · surface #FFFFFF · surface-subtle #F1F5F9 · border #E2E8F0
  text-primary #0F172A · text-secondary #475569 · text-muted #94A3B8
SEMANTIC: primary #2563EB · safe #22C55E · warning #F59E0B · danger #EF4444 · income #10B981 · expense #F43F5E
  Budget gauge colors: <70% safe, 70–89% warning, >=90% danger. Transfers use neutral blue-grey #64748B.
  Never rely on color alone: pair with icon or text.

TYPE: h1 28/700 · h2 22/600 · h3 18/600 · body 14/400 · body-medium 14/500 · caption 12/400 · overline 12/700
  uppercase +0.5 letter-spacing. Money uses TABULAR (monospaced) figures: money-large 32/700, money-medium 20/600,
  money-small 15/600.
SHAPE & SPACE: spacing multiples of 4/8; screen side padding 20; radius: input/card 12, large card 16–20,
  primary button = full pill (radius 999), chips 999. Tap targets >= 48px. Icon size 18–24, 1.75px stroke,
  ONE consistent outline icon set (Lucide style). Never use emoji as icons.

NUMBER/DATE FORMAT: money "1.250.000 ₫" (dot thousands separator, ₫ after a space); expense shown "-45.000 ₫"
  in expense color, income "+18.000.000 ₫" in income color; dates "dd/MM/yyyy"; time "HH:mm"; weekday labels
  Vietnamese ("Thứ Hai"…"Chủ Nhật").

COMPONENTS (reuse identically across all screens):
  • Primary button: pill, primary fill, white 15/600 label, height 52; disabled = 35% opacity; loading = spinner.
  • Secondary button: pill, transparent, 1px border, primary or text color label.
  • Text field: surface-elevated fill, 1px border, radius 12, height 52, label above (caption), error text 12 danger
    below with alert icon; leading icon optional; password field has eye toggle.
  • Money field: large right-aligned tabular number with "₫" suffix, live thousand separators.
  • Balance card: radius 20, surface, 1px border, overline title, money-large amount, divider, two mini stats
    (income/expense) each with a small circular tinted icon.
  • Transaction row: 44px rounded-square tinted icon (category), title 14/600, subtitle 12 secondary
    (category · account), trailing amount money-small; small cloud-off icon in warning color if not synced.
  • Budget gauge card: category name + percent pill (semantic color), 8px rounded progress bar, caption row
    "Đã chi: X" left and "Hạn mức: Y" right.
  • Category chip: pill with leading icon, selected = primary at 20% fill + primary text.
  • Bottom tab bar (5 items, always visible on main screens): "Trang chủ" (home), "Sổ thu chi" (receipt),
    "Kế hoạch" (target), "Phân tích" (pie-chart), "Cá nhân" (user). Selected = primary icon+label.
  • Bottom sheet: top radius 24, drag handle 40x4, scrolls, sits above the keyboard.
  • Empty state: 48px icon, one-line title, one-line hint, one primary/secondary action.
  • Error state: alert icon, friendly Vietnamese message, "Thử lại" button.
  • Mascot "Finny": a friendly round piggy-bank/fox-like character (flat vector, blue accent). Emotions:
    happy (calm budget), worried (70–89%), panic (>=90%). Shown small in cards, larger in celebrations.

STATES: for every screen also design (when relevant) loading (skeleton), empty, error and offline variants.
A global thin banner "Đang ngoại tuyến – dữ liệu sẽ đồng bộ khi có mạng" (warning tint) shows when offline.
```

---

## BLOCK D – SAMPLE DATA (paste with every batch; use ONLY these numbers)

```
TODAY: Chủ Nhật, 18/10/2026 (October has 31 days → 13 days remain in the month).
USER: "Nguyễn Minh Tuấn" (display "Tuấn"), email tuan@email.com, monthly income 18.000.000 ₫.
GAMIFICATION: Level 4, XP 520/800, streak 6 days (longest 12). Finny mood: happy. Equipped: "Mũ lưỡi trai".

ACCOUNTS (total 25.000.000 ₫): 
  "Ví tiền mặt" (Tiền mặt) 2.350.000 ₫ · "Vietcombank" (Ngân hàng) 21.480.000 ₫ · "MoMo" (Ví điện tử) 1.170.000 ₫

TRANSACTIONS (October, newest first; type, category, account):
 1) 18/10 12:30 "Cơm tấm Sài Gòn" · Ăn uống · Ví tiền mặt · -45.000 ₫
 2) 18/10 08:10 "Cà phê Highlands" · Ăn uống · MoMo · -55.000 ₫
 3) 17/10 19:45 "Grab đi làm" · Di chuyển · MoMo · -68.000 ₫
 4) 17/10 09:00 "Rút tiền ATM" · CHUYỂN NỘI BỘ Vietcombank → Ví tiền mặt · 2.000.000 ₫ (neutral, "Nội bộ – không tính chi tiêu")
 5) 16/10 20:15 "Netflix" · Giải trí · Vietcombank · -260.000 ₫
 6) 15/10 18:30 "Siêu thị WinMart" · Mua sắm · Vietcombank · -742.000 ₫
 7) 14/10 07:50 "Bún bò Huế" · Ăn uống · Ví tiền mặt · -50.000 ₫
 8) 13/10 21:00 "Tiền điện tháng 10" · Hóa đơn · Vietcombank · -680.000 ₫
 9) 12/10 12:15 "Cơm văn phòng" · Ăn uống · Ví tiền mặt · -45.000 ₫
10) 10/10 15:00 "Freelance thiết kế logo" · Thu nhập · Vietcombank · +1.500.000 ₫
11) 09/10 10:20 "Khám răng" · Sức khỏe · Vietcombank · -350.000 ₫
12) 08/10 19:00 "Áo sơ mi Uniqlo" · Mua sắm · Vietcombank · -549.000 ₫
13) 05/10 18:40 "Xăng xe máy" · Di chuyển · Ví tiền mặt · -70.000 ₫
14) 03/10 20:30 "Lẩu Thái với bạn" · Ăn uống · MoMo · -420.000 ₫
15) 01/10 09:00 "Lương tháng 10" · Thu nhập · Vietcombank · +18.000.000 ₫
 Month totals: income 19.500.000 ₫ · spent 3.334.000 ₫ · net +16.166.000 ₫ · 15 transactions.
 Previous month spent 3.810.000 ₫ → "Chi tiêu giảm 12,5%" / "Bạn đã chi ít hơn 476.000 ₫ so với tháng trước."

SPENDING BY CATEGORY (of 3.334.000 ₫): Mua sắm 1.291.000 (38,7%) · Hóa đơn 680.000 (20,4%) ·
 Ăn uống 615.000 (18,4%) · Sức khỏe 350.000 (10,5%) · Giải trí 260.000 (7,8%) · Di chuyển 138.000 (4,1%)
DAILY SPEND (line chart): 03:420k 05:70k 08:549k 09:350k 12:45k 13:680k 14:50k 15:742k 16:260k 17:68k 18:100k

BUDGETS (October): Tổng tháng 9.000.000 ₫ (spent 3.334.000 = 37,0%, còn 5.666.000 ₫ → "435.846 ₫ / ngày", "Còn 13 ngày")
  Ăn uống 3.000.000 (spent 615.000 · 20,5% · safe) · Di chuyển 800.000 (138.000 · 17,3% · safe)
  Mua sắm 1.500.000 (1.291.000 · 86,1% · warning) · Hóa đơn 700.000 (680.000 · 97,1% · danger)
  Giải trí 300.000 (260.000 · 86,7% · warning) · Sức khỏe: no budget yet.

GOALS: "Quỹ khẩn cấp" 12.000.000 / 30.000.000 ₫ (40%), deadline 31/03/2027, badge "Cần ~3.600.000 ₫/tháng"
       "Du lịch Đà Lạt" 5.000.000 / 8.000.000 ₫ (62,5%), deadline 30/11/2026, badge "Cần ~3.000.000 ₫/tháng"
       "Mua laptop" 20.000.000 / 20.000.000 ₫ (100%), badge "Hoàn thành" (use for completed variant)

FORECAST (after 18 days): spent so far 3.334.000 ₫ · projected end of month 5.742.000 ₫ · confidence "Trung bình"
  (based on 18 days) · income 18.000.000 ₫ · projected end balance 12.258.000 ₫ · no cut needed.

RECURRING/BILLS: "Netflix" 260.000 ₫ hằng tháng ngày 16 (đã trả) · "Tiền điện" ~680.000 ₫ ngày 13 (đã trả) ·
  "Internet FPT" 220.000 ₫ hạn 20/10 (còn 2 ngày) · "Tiền nước" 95.000 ₫ hạn 25/10 (còn 7 ngày)
SPLIT BILL: "Lẩu Thái với bạn" 420.000 ₫ chia 4 người → mỗi người 105.000 ₫; bạn bè An, Bình, Chi còn nợ 105.000 ₫ mỗi người.

MASCOT ITEMS: owned "Mũ lưỡi trai" (equipped), "Kính râm", "Nền phòng khách"; locked "Mũ heo đất" (hint "Hoàn thành nhiệm vụ Khởi động mục tiêu"),
  "Nền bãi biển" ("Đạt level 8"), "Sơ mi công sở" ("Đạt level 5").
MISSIONS: Hằng ngày "Xác nhận 3 giao dịch" 2/3 (+50 XP) · "Tự thêm 1 giao dịch" 1/1 hoàn thành (+30 XP)
  Hằng tuần "Không vượt hạn mức 7 ngày" 6/7 (+120 XP) · Một lần "Khởi động mục tiêu" hoàn thành (+100 XP)
NOTIFICATIONS: "Ngân sách Hóa đơn đã dùng 97%" (hôm nay 09:00) · "Bạn còn 1 nhiệm vụ hôm nay" (hôm nay 08:00) ·
  "Dự báo: cuối tháng còn khoảng 12.258.000 ₫" (hôm qua)
CATEGORIES (system): Ăn uống, Di chuyển, Mua sắm, Hóa đơn, Giải trí, Sức khỏe, Giáo dục, Gia đình, Nhà ở, Thu nhập, Khác.
BANKS/WALLETS to follow: MB Bank, Vietcombank, MoMo, VNPay, ZaloPay.
```

---

## BATCH 1 – Foundations & Auth (8 screens)

**1. Splash.** Full-bleed background. Center: logo (rounded-square primary tint with a wallet icon), wordmark "FinMate", tagline "Trợ lý tài chính cá nhân thông minh". Bottom: small spinner. Variant: same screen when offline showing the offline banner.

**2. Intro carousel (3 slides + skip).** Top-right text button "Bỏ qua". Each slide: large flat illustration area (Finny), title h1, 2-line body, page dots, pill button "Tiếp tục" (last slide "Bắt đầu"). Slide 1 "Tự động ghi chép" / "FinMate đọc thông báo biến động số dư để ghi chép giúp bạn, không cần nhập tay." Slide 2 "Kiểm soát ngân sách" / "Đặt hạn mức, nhận gợi ý mức chi an toàn mỗi ngày." Slide 3 "Tiết kiệm có động lực" / "Đặt mục tiêu, nạp tiền và cùng Finny lên cấp."

**3. Welcome & terms.** Center logo + "FinMate" (h1, tight tracking) + subtitle. Above buttons: "Zero-Credential" trust card (shield-check icon in safe color): title "Cam kết bảo mật Zero-Credential", body "FinMate tuyệt đối không bao giờ yêu cầu mật khẩu Internet Banking, mã PIN hay mã OTP ngân hàng của bạn." Checkbox row "Tôi đã đọc và đồng ý với Điều khoản dịch vụ & Chính sách quyền riêng tư" (the two phrases underlined links). Buttons: primary "Đăng nhập với Email" and secondary "Tạo tài khoản mới" — both disabled until checkbox ticked (show disabled state and enabled state as two frames).

**4. Register.** App bar back arrow + title "Tạo tài khoản mới". Heading "Chào mừng bạn đến với FinMate", caption "Bắt đầu hành trình quản lý tài chính thông minh, bảo mật và hoàn toàn tự động." Fields (overline labels): "HỌ VÀ TÊN" (placeholder "Nguyễn Văn A"), "ĐỊA CHỈ EMAIL" ("name@example.com"), "MẬT KHẨU" ("Tối thiểu 8 ký tự", with a 4-segment password-strength bar and text "Yếu/Trung bình/Mạnh"), "XÁC NHẬN MẬT KHẨU" ("Nhập lại mật khẩu"). Zero-Credential mini banner. Primary "Đăng ký tài khoản". Footer "Đã có tài khoản? " + link "Đăng nhập ngay". Frames: empty, filled, validation errors ("Vui lòng nhập họ và tên", "Email không đúng định dạng", "Mật khẩu phải có ít nhất 8 ký tự", "Mật khẩu xác nhận không khớp"), server error banner "Email đã được sử dụng.", loading button.

**5. OTP verification.** Back arrow. Title "Xác thực Email"; body "Mã xác nhận 6 chữ số đã được gửi tới:" + email "tuan@email.com" in text-primary. Six separate rounded digit boxes (50x60) centered, focused box has primary border. Primary "Xác nhận". Under it a text button: "Gửi lại mã sau 39s" (disabled, muted) → after countdown "Gửi lại mã xác nhận" (primary). Frames: empty, 6 digits filled, error "Mã không hợp lệ hoặc đã hết hạn." (danger, boxes with danger border), loading.

**6. Login.** Back arrow. h1 "Chào mừng trở lại", caption "Đăng nhập để tiếp tục quản lý chi tiêu cá nhân". Optional info banner (primary tint, info icon) "Email đã được xác thực. Vui lòng đăng nhập để tiếp tục." Fields "Email" (mail icon) and "Mật khẩu" ("Nhập mật khẩu của bạn", eye toggle). Right-aligned link "Quên mật khẩu?". Primary "Đăng nhập". Divider "hoặc" and secondary button "Tiếp tục với Google" (use a neutral G-in-circle placeholder, not an emoji). Footer "Chưa có tài khoản? " + "Đăng ký ngay". Frames: default, error banner "Email hoặc mật khẩu không đúng.", session-expired banner "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.", loading.

**7. Forgot password.** Title "Quên mật khẩu?", body "Nhập email đăng ký, chúng tôi sẽ gửi mã để đặt lại mật khẩu." Email field, primary "Gửi mã". Success frame: check-circle icon, "Nếu email tồn tại, chúng tôi đã gửi mã đặt lại mật khẩu." + primary "Tiếp tục".

**8. Reset password.** Title "Đặt lại mật khẩu". Fields: "Mã xác nhận" (6 digits), "Mật khẩu mới", "Xác nhận mật khẩu mới" (with strength bar). Primary "Đặt lại mật khẩu". Success frame: "Đổi mật khẩu thành công" + primary "Về đăng nhập".

**Acceptance check (Batch 1):** all buttons pill 52px; same fields everywhere; Vietnamese diacritics render; disabled/loading/error frames exist for Welcome, Register, OTP, Login.

---

## BATCH 2 – Onboarding, Home, Notifications (5 screens)

**9. Onboarding 1/3 – Permissions.** App bar title "Thiết lập ban đầu (1/3)", right text button "Bỏ qua", 3-segment progress bar under it (segment 1 filled). h2 "Tự động ghi nhận thông minh"; body "FinMate lắng nghe thông báo biến động số dư từ ngân hàng để tự động ghi chép tức thì mà không cần bạn nhập tay." Two permission cards (icon left, title, description, trailing status pill "Chưa cấp" warning / "Đã cấp" safe, and a small button "Mở cài đặt"): "Quyền truy cập thông báo" — "Cho phép FinMate nhận diện biến động số dư từ ngân hàng và ví điện tử."; "Tắt tối ưu hóa pin (ROM Defense)" — "Ngăn hệ điều hành Android tự động tắt ngầm dịch vụ lắng nghe thông báo." Bottom pill "Tiếp tục".

**10. Onboarding 2/3 – Sources.** Title "(2/3)". h2 "Chọn nguồn cần theo dõi"; body "FinMate chỉ xử lý thông báo từ các ứng dụng bạn chủ động cho phép dưới đây." List of 5 rows (bank logo placeholder circle, name, type caption "Ngân hàng"/"Ví điện tử", trailing switch): MB Bank, Vietcombank (on), MoMo (on), VNPay, ZaloPay. Bottom "Tiếp tục".

**11. Onboarding 3/3 – Finance setup.** Title "(3/3)". h2 "Kế hoạch tài chính tháng"; body "Thiết lập thu nhập dự kiến và số dư ví để kích hoạt hệ thống cảnh báo và cố vấn AI." Money fields: "Thu nhập hàng tháng dự kiến (VND)" = 18.000.000; "Ngân sách chi tiêu tháng này (VND, tùy chọn)" = 9.000.000; "Số dư ví tiền mặt hiện có (VND)" = 0 (0 is valid). Bottom primary "Hoàn tất & Khám phá FinMate". Error frame: "Vui lòng nhập thu nhập hàng tháng hợp lệ."

**12. Home (dark + light variants).** Scrollable, bottom tab bar with "Trang chủ" selected.
 Zones top→bottom: (a) header: "Xin chào," caption + "Tuấn" h3; right side profile icon button (circle-user) and bell icon with red dot. (b) Balance card: overline "TỔNG TÀI SẢN KHẢ DỤNG", eye toggle, "25.000.000 ₫" money-large; mini stats "Thu nhập +19.500.000 ₫" and "Chi tiêu -3.334.000 ₫". (c) Finny card: mascot avatar with "Lv.4" badge, name "Finny" + mood pill "Yên tâm", equipped "Mũ lưỡi trai", speech line "Bạn đang kiểm soát chi tiêu rất tốt! Tiếp tục phát huy nhé!". (d) Quick actions row of 4 tiles: "Ghi chép" (plus, filled primary), "Kế hoạch" (target), "Báo cáo" (pie-chart), "Lịch sử" (arrows-left-right). (e) Overline "GIAO DỊCH GẦN ĐÂY" + text button "Xem tất cả"; 4 transaction rows (items 1–4 of Block D). (f) Optional reminder strip "Internet FPT 220.000 ₫ – còn 2 ngày".
 Frames: normal; loading skeleton; empty new user ("0 ₫", hint "Bạn chưa có tài khoản. Bấm "Ghi chép" để tạo ví đầu tiên.", empty list "Chưa có giao dịch nào. Hãy bấm "Ghi chép" để thêm giao dịch đầu tiên!"); report-error state ("Không tải được số liệu" + "Thử lại"); worried-mascot variant (hypothetical: total budget used 72%, mood pill "Cần chú ý", speech "Bạn đã dùng 72% ngân sách tháng. Hãy chú ý các khoản mua sắm và cafe ăn vặt nhé!"; label this frame as an alternate scenario, not the default data); light mode.

**13. Notifications.** App bar "Thông báo", right text button "Đánh dấu đã đọc". Grouped list: header "HÔM NAY" then two items; header "HÔM QUA" one item (Block D). Each item: tinted round icon (alert-triangle warning / target primary / trending-up safe), bold title if unread + small primary dot, caption time. Empty state: bell-off icon "Chưa có thông báo nào".

**Acceptance check (Batch 2):** Home numbers equal Block D (25.000.000 = 2.350.000 + 21.480.000 + 1.170.000); tab bar identical; light and dark Home both present.

---

## BATCH 3 – Transactions (10 screens)

**14. Transaction list ("Sổ thu chi").** App bar title "Lịch sử giao dịch" + search icon + filter icon (with count badge when active). Horizontal filter chips: "Tất cả" (selected), "Chi tiêu", "Thu nhập", "Chuyển tiền nội bộ". List grouped by day with sticky day header (surface-elevated bar): "18/10/2026 · Chủ Nhật" with right-aligned day total "-100.000 ₫"; rows from Block D. Transfer row uses double-arrow icon and pill "Nội bộ – không tính chi tiêu". Floating extended button "Ghi chép mới" (plus). Frames: normal, loading skeleton, empty ("Chưa có giao dịch nào"), error with "Thử lại", offline banner with two rows showing cloud-off, "swipe to delete" revealed action (danger, "Xóa") + snackbar "Đã xóa giao dịch" with "Hoàn tác".

**15. Filter bottom sheet.** Title "Bộ lọc", right "Đặt lại". Sections: "Khoảng thời gian" (quick chips "Hôm nay", "7 ngày", "Tháng này", "Tùy chọn" + two date fields), "Tài khoản" (multi-select chips of the 3 accounts), "Danh mục" (multi-select chips with icons), "Loại giao dịch" (segmented: Tất cả / Chi tiêu / Thu nhập / Chuyển tiền), "Khoảng số tiền" (two money fields "Từ" / "Đến"). Bottom pill "Áp dụng (3)".

**16. Search.** Search field autofocus with clear button, placeholder "Tìm theo mô tả, cửa hàng, ghi chú"; recent searches list ("Cà phê", "WinMart") with clock icon and "Xóa lịch sử"; results state with highlighted match ("Cà phê Highlands"); no-results state "Không tìm thấy giao dịch nào".

**17. Create transaction sheet – "AI Text" tab.** Bottom sheet (height ~75%), tab bar with 4 icon+label tabs: "AI Text" (sparkles, selected), "Giọng nói" (mic), "Hóa đơn" (scan-line), "Thủ công" (pencil). Caption "Nhập câu tự nhiên, FinMate tự trích xuất thông tin:". Multiline field with placeholder "Ví dụ: "Ăn trưa cơm tấm 45k bằng ví tiền mặt", "Lương công ty 20 triệu"..." Filled example "Cà phê Highlands 55k bằng MoMo". Suggestion chips below: "Ăn trưa 50k", "Grab 68k", "Lương 18 triệu". Primary "Phân tích bằng FinMate AI" with sparkle icon; loading state; error inline "AI Service không phản hồi. Bạn có thể nhập thủ công." + secondary "Nhập thủ công".

**18. Create transaction sheet – "Thủ công" tab.** Segmented chips "Chi tiêu" / "Thu nhập" / "Chuyển tiền". Fields: money field (label "Số tiền (VNĐ)", example 45.000), "Danh mục" dropdown with icon rows and "Chưa phân loại", "Tài khoản" dropdown (3 accounts), "Ngày giờ" (18/10/2026 12:30), "Ghi chú". Primary "Lưu giao dịch". Variants: Transfer mode (hide category; show "Từ tài khoản" and "Đến tài khoản" with swap icon; error "Tài khoản nguồn và đích không được trùng nhau"); no-account state (wallet icon, "Bạn chưa có tài khoản nào", "Tạo một ví để bắt đầu ghi chép giao dịch.", button "Tạo ví tiền mặt" + small dialog "Số dư hiện có (VNĐ)" default 0, buttons "Hủy"/"Tạo ví"); validation "Vui lòng nhập số tiền hợp lệ"; keyboard-open frame proving fields stay above keyboard.

**19. Create sheet – "Giọng nói" tab.** Big circular mic button (80px, primary) idle; recording frame: red stop button with animated pulse rings, waveform, timer "00:07", caption "Đang lắng nghe... Chạm để hoàn tất". After recording: editable transcript card "Uống cafe Highland 55 ngàn bằng tài khoản MB" + buttons "Ghi lại" and "Phân tích". Permission-denied frame: "Cần quyền micro để ghi âm" + "Mở cài đặt". Alternative "Sắp ra mắt" disabled frame.

**20. Create sheet – "Hóa đơn" tab.** Illustration frame with camera icon, text "Chụp hoặc tải ảnh hóa đơn", caption "OCR tự động bóc tách tổng tiền, nhà hàng & ngày giờ"; buttons "Chụp ảnh" (primary) and "Chọn ảnh từ thư viện" (secondary). After picking: image preview with corner guides, button "Quét hóa đơn"; scanning frame with shimmer and "Đang đọc hóa đơn...".

**21. AI preview & confirm.** App bar close (X) + title "Xác nhận thông tin giao dịch". Warning banner (warning tint, triangle-alert) "AI cần bạn kiểm tra lại một số chi tiết" / "Thiếu thông tin: category. Vui lòng bổ sung trước khi lưu." Overline "NỘI DUNG NHẬN DIỆN TỰ ĐỘNG" + italic quote card "Cà phê Highlands 55k bằng MoMo". Sections: "LOẠI GIAO DỊCH" (two chips Chi tiêu/Thu nhập), "SỐ TIỀN (VNĐ)" (large expense-colored 55.000 ₫), "DANH MỤC" (wrap of chips; AI-suggested chip has a star icon and primary tint: "Ăn uống"), "TÀI KHOẢN NGUỒN" dropdown "MoMo", "GHI CHÚ / MÔ TẢ". Buttons "Xác nhận & Lưu giao dịch" (with check icon) and secondary "Hủy bỏ bản ghi nháp". Frames: low-confidence (banner) and high-confidence (no banner).

**22. Transaction detail.** App bar back + title "Chi tiết giao dịch" + overflow menu ("Sửa", "Xóa"). Hero: category icon circle, "-55.000 ₫" money-large expense, "Cà phê Highlands", status pill "Đã đồng bộ" (safe) / "Chưa đồng bộ" (warning). Info list rows: "Danh mục" Ăn uống, "Tài khoản" MoMo, "Thời gian" "18/10/2026 · 08:10", "Nguồn" "Thủ công/Thông báo/Giọng nói/Hóa đơn" (pill), "Số dư sau giao dịch" "1.170.000 ₫", "Ghi chú". Secondary button "Chia hóa đơn" (users icon). Delete confirmation dialog: "Xóa giao dịch này?" / "Hành động này không thể hoàn tác." buttons "Hủy" / "Xóa" (danger).

**23. Split bill.** App bar "Chia hóa đơn". Header card "Lẩu Thái với bạn · 420.000 ₫". "Chia đều cho" stepper (4 người). Participant rows with avatar initials: "Bạn" 105.000 ₫ (paid), "An" 105.000 ₫ "Chưa trả", "Bình" 105.000 ₫ "Chưa trả", "Chi" 105.000 ₫ "Chưa trả"; add-person row "Thêm người". Summary "Bạn bè còn nợ bạn: 315.000 ₫". Buttons "Gửi nhắc nợ" (primary) and per-person "Đánh dấu đã trả".

**Acceptance check (Batch 3):** list/day totals match Block D (18/10 = -100.000 ₫); transfer never colored as expense; three frames for the create sheet share identical tab bar; keyboard-safe frame present.

---

## BATCH 4 – Planning (6 screens)

**24. Planning – Budgets tab.** App bar "Kế hoạch tài chính" with 2 tabs: "Hạn mức ngân sách" (wallet icon, selected) / "Mục tiêu tiết kiệm" (piggy-bank). Card 1 (radius 20): overline "HẠN MỨC CHI TIÊU HÔM NAY" + pill "Còn 13 ngày", value "435.846 ₫ / ngày" money-large, caption "Ngân sách tháng: 9.000.000 ₫ · Đã chi 3.334.000 ₫", thin progress 37%. Header row "NGÂN SÁCH THEO DANH MỤC" + text button "+ Thêm". Four gauge cards from Block D (Ăn uống safe, Di chuyển safe, Mua sắm warning 86%, Hóa đơn danger 97%, Giải trí warning 87%) — five cards total scrollable. Frames: normal; **no-budget** (card "Bạn chưa đặt ngân sách tháng này", caption "Đặt hạn mức chi tiêu cả tháng để FinMate gợi ý mức chi an toàn mỗi ngày.", button "Tạo ngân sách tháng"); **over-budget** (card border danger, "ĐÃ CHI VƯỢT NGÂN SÁCH!", "Bạn đã tiêu quá hạn mức tháng. Hãy dừng chi tiêu không thiết yếu!"); loading; error.

**25. Add / edit budget sheet.** Title "Thêm ngân sách danh mục" (or "Tạo ngân sách tháng" / "Sửa Mua sắm"). Category dropdown with icons (only categories without budget), money field "Hạn mức chi tiêu (VNĐ)", buttons "Hủy" / "Lưu". Errors: "Vui lòng chọn danh mục", "Vui lòng nhập số tiền hợp lệ", server "Bạn đã có hạn mức cho danh mục này." Edit mode also shows destructive text button "Xóa ngân sách".

**26. Planning – Goals tab.** Header "MỤC TIÊU TIẾT KIỆM HIỆN CÓ" + pill button "+ Mục tiêu mới". Goal cards: title 16/700, status badge (semantic), caption "Hạn chót: 31/03/2027", 10px progress bar (safe), two columns "Đã tích lũy 12.000.000 ₫" (safe) and "Mục tiêu 30.000.000 ₫", outlined button "Nạp tiền vào mục tiêu" (disabled for completed). Three goals from Block D incl. completed "Hoàn thành". Empty: piggy-bank icon "Bạn chưa có mục tiêu tiết kiệm nào." + button "Tạo mục tiêu đầu tiên". Overdue variant badge "Trễ hạn" (danger).

**27. Create goal sheet.** Title "Tạo mục tiêu tiết kiệm". Fields: "Tên mục tiêu" (placeholder "Quỹ du lịch"), money "Mục tiêu tích lũy (VNĐ)", outlined date button "Chọn hạn chót (tùy chọn)" opening a calendar picker frame. Live helper card: "Để đạt mục tiêu, bạn cần nạp khoảng 3.600.000 ₫/tháng." Buttons "Hủy" / "Tạo mục tiêu". Errors "Vui lòng nhập tên mục tiêu".

**28. Contribute & celebration.** Dialog: title "Nạp tiền vào "Quỹ khẩn cấp"", money field "Số tiền (VNĐ)" (1.000.000), quick chips "+500.000", "+1.000.000", "+2.000.000", optional note, source account dropdown, buttons "Hủy" / "Nạp tiền"; error "Vui lòng nhập số tiền hợp lệ". Success frame: goal card progress animating to 43,3%, snackbar "Đã nạp 1.000.000 ₫ vào mục tiêu!". **Level-up celebration** full-screen: confetti (flat), large happy Finny wearing new item, "Bạn vừa lên cấp 5!", subtitle "Mở khóa: Sơ mi công sở", primary "Tuyệt vời!".

**29. Recurring & bill reminders.** App bar "Giao dịch định kỳ" + "+" button. Section "SẮP ĐẾN HẠN": two rows "Internet FPT · 220.000 ₫ · hạn 20/10 · còn 2 ngày" (warning pill) and "Tiền nước · 95.000 ₫ · hạn 25/10 · còn 7 ngày". Section "ĐÃ THANH TOÁN THÁNG NÀY": Netflix (ngày 16), Tiền điện (ngày 13) with check icons. Each row: bell toggle "Nhắc trước 1 ngày". Add sheet: name, money, category, account, repeat "Hằng tháng/Hằng tuần", day, reminder switch, "Lưu". Empty state "Chưa có khoản định kỳ nào".

**Acceptance check (Batch 4):** gauge colors follow the 70/90 thresholds; daily limit text equals "435.846 ₫ / ngày"; goal badges text matches Block D; level-up screen uses Finny.

---

## BATCH 5 – Analytics (4 screens)

**30. Analytics – month.** App bar "Phân tích chi tiêu & Xu hướng", share/export icon. Period selector (pill segmented): "Tháng này" (selected), "Tuần này" and "Năm nay" shown disabled with helper caption "Tuần và năm sắp có." (and a frame with all three enabled for the future). Comparison card: trending-down icon in safe tint, "Chi tiêu giảm 12,5%", "Bạn đã chi ít hơn 476.000 ₫ so với tháng trước." Section "CƠ CẤU CHI TIÊU THEO DANH MỤC": donut chart (center label "3.334.000 ₫" + "Tổng chi"), 6 legend rows (colored dot, "Mua sắm (39%)", right amount) from Block D; tapping a slice highlights it. Section "XU HƯỚNG CHI TIÊU THEO NGÀY": smooth line/area chart from the DAILY SPEND data with today marker and tooltip on one point. Section "DỰ BÁO CHI TIÊU ĐẾN CUỐI THÁNG": card rows "Đã chi tới nay 3.334.000 ₫", "Dự kiến cuối tháng 5.742.000 ₫" (emphasized), "Ngân sách tháng 9.000.000 ₫" + progress 64% (safe), divider, "Thu nhập tháng 18.000.000 ₫", "Số dư dự kiến cuối tháng 12.258.000 ₫", caption "Độ tin cậy: trung bình · dựa trên 18 ngày". Frames: normal, empty ("Chưa có chi tiêu tháng này", "Chưa đủ dữ liệu để dự báo"), errors ("Thử lại"), spending-up variant (danger trending-up "Chi tiêu tăng 20%"), negative projected balance variant ("-500.000 ₫" in danger with row "Gợi ý cắt giảm mỗi ngày 20.000 ₫").

**31. Category detail.** App bar back + "Mua sắm". Hero: icon, "1.291.000 ₫", "38,7% tổng chi · 2 giao dịch", budget gauge (86%). Bar chart "Theo tuần" (4 bars). List of the 2 Mua sắm transactions (WinMart 742.000, Uniqlo 549.000). Button "Đặt ngân sách cho danh mục" if none.

**32. Insights.** App bar "Gợi ý từ FinMate". Cards with colored left border: warning "Ngân sách Hóa đơn sắp hết" (97%, action "Xem ngân sách"), info "Chi tiêu Ăn uống thấp hơn mức trung bình 20%", safe "Bạn đang đi đúng kế hoạch tiết kiệm Quỹ khẩn cấp", each with time and swipe "Đã đọc". Filter chips "Tất cả", "Chưa đọc". Empty: "Chưa có gợi ý nào".

**33. Export report.** Sheet/page "Xuất báo cáo". Month picker "Tháng 10/2026", format segmented "PDF" / "Excel" / "CSV", checklist "Tổng quan thu chi", "Cơ cấu theo danh mục", "Danh sách giao dịch", "Dự báo", preview thumbnail of the report first page (Finny logo, totals). Primary "Xuất báo cáo"; success frame "Đã tạo báo cáo" with buttons "Chia sẻ" and "Mở tệp".

**Acceptance check (Batch 5):** donut segments sum to 100% of 3.334.000 ₫ and legend numbers equal Block D; forecast rows equal Block D; charts use the same palette in dark and light.

---

## BATCH 6 – Profile & Settings (10 screens)

**34. Profile ("Cá nhân").** App bar "Cá nhân & Gamification". User card: initial-letter avatar "T", "Nguyễn Minh Tuấn", "tuan@email.com", small button "Sửa". Level card: "Cấp 4", right "520 / 800 XP", progress bar, row flame icon "Chuỗi hiện tại: 6 ngày · Dài nhất: 12 ngày". Overline "TỦ ĐỒ LINH VẬT FINNY": chips of items (owned selectable, "Mũ lưỡi trai" selected; locked have lock icon + hint text below). Menu list (icon, title, chevron): "Nhiệm vụ", "Tài khoản & ví", "Danh mục", "Giao dịch định kỳ", "Xuất báo cáo", "Cài đặt". Zero-Credential card. Danger outlined button "Đăng xuất tài khoản". Frames: normal, loading, error ("Thử lại"), logout confirm dialog when unsynced items exist: title "Còn giao dịch chưa đồng bộ", body "Còn 2 giao dịch chưa được gửi lên máy chủ. Đăng xuất sẽ làm mất chúng.", buttons "Hủy" / "Vẫn đăng xuất".

**35. Mascot wardrobe.** Large Finny preview on a background tile (changes when an item is equipped), tabs "Mũ", "Phụ kiện", "Nền", "Trang phục"; 3-column item grid: owned (tap to equip, equipped has primary ring + check), locked (dimmed, lock, hint). Bottom "Lưu trang phục". Constraint note: only one item per category.

**36. Missions.** Tabs "Hằng ngày", "Hằng tuần", "Một lần". Mission cards: title, description, progress bar "2/3", reward pill "+50 XP", completed state with check + "Đã hoàn thành". Top summary "Hôm nay: 1/2 nhiệm vụ · +30 XP". Link "Lịch sử nhiệm vụ".

**37. Accounts & wallets.** App bar "Tài khoản & ví" + "+". Summary "Tổng cộng 25.000.000 ₫". Rows: icon by type, name, type caption, balance, switch "Theo dõi"; the 3 accounts. Row tap → account detail (balance hero + that account's transaction list). Empty: "Bạn chưa có tài khoản nào" + "Tạo ví tiền mặt".

**38. Add / edit account sheet.** Title "Thêm tài khoản". Type segmented "Ngân hàng" / "Ví điện tử" / "Tiền mặt"; provider dropdown (only for bank/wallet; providers list) ; name field; money "Số dư ban đầu (VNĐ)" (0 allowed). Error "Bạn đã có tài khoản khác theo dõi ứng dụng này." Edit mode adds "Xóa tài khoản" with confirm "Xóa tài khoản này? Các giao dịch liên quan sẽ không còn hiển thị tên tài khoản."

**39. Categories.** Two sections: "DANH MỤC HỆ THỐNG" (11 chips/rows with icons, lock icon = read-only) and "DANH MỤC CỦA BẠN" (empty state + "+ Thêm danh mục"). Add sheet: name field, icon picker grid (24 icons), "Lưu".

**40. Settings.** Sections with grouped rows: "THÔNG BÁO" (switches "Thông báo đẩy", "Cảnh báo ngân sách", "Nhắc nhiệm vụ"); "BẢO MẬT" ("Khóa ứng dụng bằng sinh trắc học" switch, "Ẩn số dư khi vào nền" switch, "Đổi mật khẩu" chevron, "Đăng xuất mọi thiết bị"); "HIỂN THỊ" (segmented "Sáng"/"Tối"/"Theo hệ thống", "Ngôn ngữ: Tiếng Việt"); "DỮ LIỆU & QUYỀN RIÊNG TƯ" ("Xuất dữ liệu", "Điều khoản dịch vụ", "Chính sách quyền riêng tư"); danger row "Xóa tài khoản". App version caption at bottom.

**41. Change password.** Fields "Mật khẩu hiện tại", "Mật khẩu mới" (strength bar), "Xác nhận mật khẩu mới"; primary "Đổi mật khẩu"; errors "Mật khẩu hiện tại không đúng", success snackbar "Đã đổi mật khẩu".

**42. Delete account.** Warning card (danger tint): "Xóa tài khoản vĩnh viễn", bullet list of consequences ("Toàn bộ giao dịch, ngân sách, mục tiêu sẽ bị xóa", "Hành động này không thể hoàn tác"). Password field "Nhập mật khẩu để xác nhận", checkbox "Tôi hiểu hậu quả", danger button "Xóa tài khoản" (disabled until both satisfied), secondary "Hủy".

**43. System states (one frame each).** "Mất kết nối": wifi-off icon, "Không có kết nối mạng", "Vui lòng kiểm tra lại đường truyền.", button "Thử lại". "Phiên hết hạn": lock icon, "Phiên đăng nhập đã hết hạn", button "Đăng nhập lại". "Lỗi máy chủ": "Máy chủ đang gặp sự cố. Vui lòng thử lại sau." "Bảo trì": "FinMate đang bảo trì", caption with estimated time. "Cập nhật bắt buộc": "Đã có phiên bản mới", button "Cập nhật ngay".

**Acceptance check (Batch 6):** Profile numbers equal Block D (Cấp 4, 520/800, chuỗi 6/12); only one equipped item per category shown; destructive actions always red + confirmation; all switches share one style.

---

## FINAL CONSISTENCY PASS (paste after all batches, optional)

```
Review all generated frames and fix inconsistencies without changing layouts:
1) Every money value must come from the sample data and use "1.250.000 ₫" format with tabular figures.
2) Expense = "-" in #F43F5E, income = "+" in #10B981, internal transfers neutral (#64748B) with the pill
   "Nội bộ – không tính chi tiêu" and never counted in spending.
3) Same bottom tab bar, same pill primary button (height 52), same input height (52), same 12px radius.
4) One icon set only; no emoji anywhere. All UI text Vietnamese with diacritics; no English strings.
5) Budget/goal colors: <70% green, 70–89% amber, >=90% red — verify each gauge.
6) Provide a light-mode version of Home, Transaction list, Budgets and Analytics.
```

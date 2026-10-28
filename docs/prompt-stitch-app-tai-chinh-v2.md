# FinMate – Prompt for Stitch, v2 "Sáng & tươi" (bright, modern, light editorial direction)

## HOW TO USE (read first, in Vietnamese)

- Stitch làm tốt nhất khi nhận **từng nhóm màn hình nhỏ**. Mỗi lượt dán: **Block S (Phong cách)** + **Block D (Dữ liệu mẫu)** + **một Batch**. Không dán cả file một lần.
- Hướng dẫn viết bằng tiếng Anh; chữ trong ngoặc kép `"..."` là **nhãn hiển thị tiếng Việt**, giữ nguyên.
- Nếu Stitch trượt về kiểu "app fintech xanh–tối, thẻ bo đều", dán lại Block S kèm câu: *"Stay in the bright light editorial system. No cards with borders, no blue accent, no dark navy, no cream/brown vintage look."*
- Sau mỗi batch đối chiếu **Acceptance check**. Thứ tự: Batch 1 → 6.

---

## BLOCK S – STYLE (paste with every batch)

```
PRODUCT: "FinMate", a personal money notebook for Vietnamese people aged 22–35 (office workers, income
10–30 million VND/month). It should feel bright, fresh and modern — like a clean editorial magazine crossed with a
well-designed notes app: light, airy, confident, a little playful. It must NOT look like a generic fintech/AI-generated app.
Canvas 390 x 844, portrait, one frame per screen.

LANGUAGE: all visible text is Vietnamese with full diacritics, exactly as quoted in the spec. No English UI
text, no lorem ipsum. Voice: short, friendly, first-person-plural-free, speaks to "bạn". Never robotic.

── DESIGN PHILOSOPHY (follow strictly) ──
1. FEW BOXES. Separate content with white space, thin rules and type scale — NOT with bordered rounded cards.
   Use at most ONE "featured block" per screen. Never place a card inside a card. Never build a 2×2 grid of
   identical tiles.
2. EDITORIAL, LEFT-ALIGNED. Big numbers and titles hug the left edge; small labels sit on a thin rule. Content
   column has slightly asymmetric margins: 24px left, 20px right. Vary block widths and heights on purpose;
   do not make every element the same size or spacing.
3. TYPE IS THE HERO. Strong contrast between very large numerals/headlines and very small quiet labels.
4. ONE ACCENT COLOR ONLY (coral), used sparingly for the single primary action or the single most
   important figure on a screen. Everything else is ink on a bright light canvas.
5. HANDMADE DETAILS: almost-no grain (at most 1% noise), crisp clean white space, hairline rules, small
   "stamp" tags, slightly wobbly hand-drawn illustration lines, tiny hand-drawn tick/arrow marks in charts.

── COLOR (bright light theme is the main theme; nothing beige, cream or brown) ──
canvas (background) #FBFAF7 · paper-sunk (recessed areas, inputs) #F1EFEA · ink (primary text) #14171A
ink-2 (secondary text) #565C63 · ink-3 (muted/captions) #8B9098 · rule (lines) #E5E2DA
ACCENT coral #FF5A36 (primary button emphasis, key figure, selected marker)
STATUS: mint #0FA968 (income, good, safe) · amber #F5A623 (warning, 70–89%) · rose-red #E5384F (danger >= 90%)
Money: EXPENSE is shown in plain ink with a minus sign ("-45.000 ₫") — NOT red. INCOME is mint with a plus
sign ("+18.000.000 ₫"). Internal transfers are ink-3 with a "↔" mark. Danger/over-budget uses rose-red.
Optional dark theme "nền tối" (Home only): background #101214, sunk #1A1D20, ink #F2F3F4, ink-2 #B4B9BF, rule #2A2E33, accent #FF7A5C, mint #3DD598, amber #FFB84D, rose-red #FF6B7F. No blue, no purple, no neon anywhere.

── TYPOGRAPHY ──
Display & headings: "Bricolage Grotesque" (characterful modern grotesque, supports Vietnamese; fallback
"Plus Jakarta Sans" 700), weights 500–700, sentence case, slightly tight tracking. NO serif fonts anywhere. Body & UI: "Be Vietnam Pro" (designed for Vietnamese diacritics), 400/500/600.
Sizes: hero-number 44/600 Bricolage Grotesque · h1 30/600 Bricolage Grotesque · h2 22/600 Bricolage Grotesque · h3 17/600 Be Vietnam Pro ·
body 15/400 · body-strong 15/600 · label 12/500 small-caps look with +0.06em tracking in ink-3 (NOT all-caps
shouting) · caption 12/400. Table/list amounts use Be Vietnam Pro with tabular figures; the "₫" symbol is 60%
of the number size, baseline aligned.

── SHAPE, RULES, SPACE ──
Rules (hairlines): 1px in rule color; use them as the main structural device (under headers, between rows).
Radii are small and used inconsistently ON PURPOSE for a handmade feel: buttons 8, inputs 6, tags 3,
"featured block" 4/4/18/4 (uneven corners). No pill buttons. No fully round chips. No drop shadows; if
something floats (sheet, snackbar) use a 1px rule border and a soft 2px offset paper-shadow (#00000012).
Spacing scale 4/8/12/20/32/48 — vary vertical rhythm: tight inside groups, generous between groups.
Icons: 2px stroke, slightly rounded, one consistent set (Phosphor "bold" or Lucide 2px), 22px, ink color; NO
tinted circle backgrounds behind icons. Category is shown as a small glyph next to text or as a text tag.
Illustration: mascot "Finny" (a plump piggy-bank fox, flat) drawn as an ink outline with wobbly line and a
coral/mint spot fill, like a stamp or sticker; appears small and sparingly.

── COMPONENTS (reuse identically) ──
• Primary button: solid ink (#14171A) fill, paper-colored 15/600 label, height 54, radius 8, full width,
  trailing small arrow "→". Only ONE per screen may use the coral fill instead (the key action).
• Secondary button: no fill, 1px ink border, radius 8. Text button: underlined ink label.
• Field: recessed paper-sunk fill, NO border, 2px ink bottom line that turns coral on focus; small label
  above in label style; error text 12 rose-red with a "!" mark. Password field shows "Hiện/Ẩn" text toggle.
• Money field: huge Bricolage Grotesque number, left-aligned, "₫" small at the end, thousand dots as you type.
• Row (transaction/list): NO card. 56–64px tall on paper, hairline rule beneath. Left: title 15/600 and a
  caption "Ăn uống · MoMo" in ink-3. Right: amount, tabular. Date grouped headers are small labels with a
  rule extending to the right edge ("18/10 · Chủ Nhật ───── -100.000 ₫").
• Stamp tag: 1px ink outline, radius 3, 11/600 label with +0.08em tracking, e.g. "NỘI BỘ", "ĐÃ ĐỒNG BỘ".
  Status stamps use status color for outline and text.
• Progress (budgets/goals): a THIN 4px line on the rule color with the filled part in status color and a small
  vertical tick at the end of the fill; percentage and remaining amount written in words beside it
  ("Còn 5.666.000 ₫"). No chunky rounded bars.
• Featured block (max one per screen): paper-sunk background, uneven corners, generous padding, contains the
  most important number in Bricolage Grotesque.
• Bottom navigation: paper background, 1px top rule, 5 items icon + 11px label; selected item is ink with a
  small coral dot under the icon; others ink-3. Items: "Trang chủ", "Sổ thu chi", "Kế hoạch",
  "Phân tích", "Cá nhân".
• Bottom sheet: paper with 1px rule border, top radius 12, small centered handle line, sits above keyboard.
• Charts: drawn like ink plots — thin 1.5px ink lines with small filled dots, light hatched fill under lines,
  a stacked horizontal "ribbon" bar instead of donut charts, values labeled directly on the chart, hand-drawn
  style tick marks; palette limited to ink, coral, mint, amber, rose-red and tints of paper.
• Empty state: a small hand-drawn Finny sketch (or a single glyph), one sentence, one action. States needed
  where relevant: loading (thin animated rule/shimmer lines, not spinners in boxes), empty, error
  ("Thử lại" text button), offline (thin amber-tinted strip at top: "Đang ngoại tuyến – dữ liệu sẽ đồng bộ khi
  có mạng").

FORMAT: money "1.250.000 ₫"; dates "dd/MM/yyyy"; time "HH:mm"; weekdays Vietnamese ("Chủ Nhật").
Tap targets >= 48px. Contrast >= WCAG AA. Never rely on color alone (add sign, stamp text or icon).
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

*Layout mood: each screen is one clean "page": big bold headline top-left, one short paragraph, fields as
recessed lines, one solid button at the bottom. No cards.*

**1. Splash.** Paper background with subtle grain. Left-aligned at 40% height: wordmark "FinMate" in Bricolage Grotesque 44 with a small hand-drawn coin/ledger mark before it; under it a hairline rule and the line "Cuốn sổ tiền bạc của riêng bạn." Bottom-left: a thin animated rule that fills left→right as loading. Offline variant: amber strip on top.

**2. Intro (3 pages + skip).** Top-right text button "Bỏ qua". Each page: a large ink-line Finny sketch that bleeds off one edge (differs per page: writing in a ledger / holding a magnifier over coins / climbing a coin stack), page number "1 / 3" in label style at top-left, headline h1, two-line body, bottom-left text "Tiếp tục →" (last: solid ink button "Bắt đầu →"). Copy — 1: "Tự ghi chép giúp bạn" / "FinMate đọc thông báo biến động số dư để ghi lại chi tiêu, bạn không cần gõ tay." 2: "Nhìn rõ tiền đi đâu" / "Đặt hạn mức, biết ngay hôm nay có thể tiêu bao nhiêu." 3: "Tiết kiệm có động lực" / "Đặt mục tiêu, nạp dần, và cùng Finny lên cấp."

**3. Welcome & terms.** Top-left small Finny stamp and "FinMate" (h1). Under a rule, a short "promise" paragraph set like a pull-quote with a vertical coral line on its left: "Cam kết bảo mật Zero-Credential" (h3) / "FinMate tuyệt đối không bao giờ yêu cầu mật khẩu Internet Banking, mã PIN hay mã OTP ngân hàng của bạn." Below: a hand-drawn checkbox (square, ink stroke, tick drawn like a pen mark) with "Tôi đã đọc và đồng ý với Điều khoản dịch vụ & Chính sách quyền riêng tư" (links underlined). Bottom: solid ink button "Đăng nhập với Email →" and secondary outlined "Tạo tài khoản mới". Show two frames: both disabled (40% opacity) until the box is ticked, and enabled.

**4. Register.** Back arrow (text-like "←"). h1 "Tạo tài khoản mới"; caption "Bắt đầu hành trình quản lý tài chính thông minh, bảo mật và hoàn toàn tự động." Fields as recessed lines with small labels: "Họ và tên" (hint "Nguyễn Văn A"), "Địa chỉ email" ("name@example.com"), "Mật khẩu" ("Tối thiểu 8 ký tự", with a thin 4-tick strength line + word "Yếu/Trung bình/Mạnh"), "Xác nhận mật khẩu". A one-line trust note with a small shield glyph. Solid ink button "Đăng ký tài khoản →". Footer: "Đã có tài khoản? " + underlined "Đăng nhập ngay". Frames: empty, filled, validation errors ("Vui lòng nhập họ và tên", "Email không đúng định dạng", "Mật khẩu phải có ít nhất 8 ký tự", "Mật khẩu xác nhận không khớp"), server error line "Email đã được sử dụng.", loading (button label replaced by a thin animated rule).

**5. OTP.** h1 "Xác thực email"; body "Mã 6 chữ số đã được gửi tới" and the email "tuan@email.com" underlined in ink. Six digit slots drawn as six short underlines (no boxes), each digit in Bricolage Grotesque 32; the active slot underline is coral with a blinking caret. Button "Xác nhận →". Under it a text line "Gửi lại mã sau 39s" (ink-3) that becomes an underlined "Gửi lại mã xác nhận" at 0s. Frames: empty, filled, error ("Mã không hợp lệ hoặc đã hết hạn." in rose-red, underlines turn rose-red), loading.

**6. Login.** h1 "Chào mừng trở lại"; caption "Đăng nhập để tiếp tục quản lý chi tiêu cá nhân." Optional note strip (paper-sunk, left coral rule) "Email đã được xác thực. Vui lòng đăng nhập để tiếp tục." Fields "Email", "Mật khẩu" (toggle "Hiện"). Right-aligned underlined "Quên mật khẩu?". Solid ink button "Đăng nhập →". Below a hairline with the word "hoặc" centered, then secondary outlined "Tiếp tục với Google" (neutral round "G" glyph, not an emoji). Footer "Chưa có tài khoản? " + "Đăng ký ngay". Frames: default; error "Email hoặc mật khẩu không đúng."; session-expired note "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."; loading.

**7. Forgot password.** h1 "Quên mật khẩu?"; body "Nhập email đăng ký, chúng tôi sẽ gửi mã để đặt lại mật khẩu."; email field; button "Gửi mã →". Success frame: a small hand-drawn envelope sketch, "Nếu email tồn tại, chúng tôi đã gửi mã đặt lại mật khẩu." and button "Tiếp tục →".

**8. Reset password.** h1 "Đặt lại mật khẩu"; fields "Mã xác nhận" (6 underlines), "Mật khẩu mới" (strength line), "Xác nhận mật khẩu mới"; button "Đặt lại mật khẩu →". Success frame "Đổi mật khẩu thành công" with a hand-drawn tick and button "Về đăng nhập →".

**Acceptance check (Batch 1):** no bordered cards, no blue, no pill buttons; headings in Bricolage Grotesque, UI in Be Vietnam Pro; every screen has exactly one solid ink button; Vietnamese diacritics intact; error/loading/disabled frames present for Welcome, Register, OTP, Login.

---

## BATCH 2 – Onboarding, Home, Notifications (5 screens)

**9. Onboarding 1/3 – Quyền.** Top: "Thiết lập ban đầu" left, "Bỏ qua" right; under it a 3-part hairline progress (segment 1 inked, others rule-colored) with the label "1 / 3". h2 "Tự động ghi nhận thông minh"; body "FinMate lắng nghe thông báo biến động số dư từ ngân hàng để tự động ghi chép tức thì mà không cần bạn nhập tay." Two list entries separated by rules (no cards): glyph + "Quyền truy cập thông báo" / "Cho phép FinMate nhận diện biến động số dư từ ngân hàng và ví điện tử." with a stamp "CHƯA CẤP" (amber) and underlined "Mở cài đặt"; second entry "Tắt tối ưu hóa pin (ROM Defense)" / "Ngăn hệ điều hành Android tự động tắt ngầm dịch vụ lắng nghe thông báo." Bottom button "Tiếp tục →". Granted variant: stamp "ĐÃ CẤP" mint.

**10. Onboarding 2/3 – Nguồn theo dõi.** Same header, "2 / 3". h2 "Chọn nguồn cần theo dõi"; body "FinMate chỉ xử lý thông báo từ các ứng dụng bạn chủ động cho phép dưới đây." Five ruled rows: name in body-strong + caption ("Ngân hàng"/"Ví điện tử"), trailing hand-drawn toggle (rectangular track radius 4, ink when on, coral knob): MB Bank, Vietcombank (on), MoMo (on), VNPay, ZaloPay. Bottom "Tiếp tục →".

**11. Onboarding 3/3 – Kế hoạch tháng.** "3 / 3". h2 "Kế hoạch tài chính tháng"; body "Thiết lập thu nhập dự kiến và số dư ví để kích hoạt hệ thống cảnh báo và cố vấn AI." Three stacked money fields, each with a small label and a huge Bricolage Grotesque number: "Thu nhập hàng tháng dự kiến (VND)" 18.000.000; "Ngân sách chi tiêu tháng này (VND, tùy chọn)" 9.000.000; "Số dư ví tiền mặt hiện có (VND)" 0 (0 is valid). Button "Hoàn tất & Khám phá FinMate →" (coral fill — this is the screen's single accent action). Error frame "Vui lòng nhập thu nhập hàng tháng hợp lệ."

**12. Home – "Trang hôm nay" (light main + dark "nền tối" variant).** Scrollable, bottom nav "Trang chủ" selected. Layout top→bottom, all on paper:
 (a) Top line: small label "Chủ Nhật, 18/10/2026" left; bell glyph (with tiny coral dot) and profile glyph right. Under it h2 "Chào Tuấn," on one line.
 (b) **Featured block (the one on this screen):** uneven-corner paper-sunk area. Label "Tổng tài sản khả dụng" + small "Ẩn" toggle; hero-number "25.000.000 ₫" in Bricolage Grotesque 44 (coral only on this figure). Under it two inline figures separated by a vertical hairline: "Thu +19.500.000 ₫" (mint) and "Chi -3.334.000 ₫" (ink).
 (c) A single sentence line with a tiny Finny stamp: "Bạn đang kiểm soát chi tiêu rất tốt! Tiếp tục phát huy nhé." (Finny level chip "Lv.4", wearing "Mũ lưỡi trai"). NOT a card — just a line with a hairline above and below.
 (d) Quick actions as a row of four TEXT+glyph links separated by hairlines (not tiles): "Ghi chép", "Kế hoạch", "Báo cáo", "Lịch sử". "Ghi chép" underlined in coral.
 (e) Section label "Gần đây" with rule and text link "Xem tất cả →"; four ruled rows (items 1–4 of Block D).
 (f) A one-line reminder with amber stamp "SẮP ĐẾN HẠN": "Internet FPT · 220.000 ₫ · còn 2 ngày".
 Frames: normal; loading (skeleton rules); new-user empty ("0 ₫", note "Bạn chưa có tài khoản. Bấm "Ghi chép" để tạo ví đầu tiên.", list "Chưa có giao dịch nào. Hãy bấm "Ghi chép" để thêm giao dịch đầu tiên!"); report-error ("Không tải được số liệu" + "Thử lại"); worried-Finny alternate (hypothetical 72% used, sentence "Bạn đã dùng 72% ngân sách tháng. Hãy chú ý các khoản mua sắm và cafe ăn vặt nhé!", amber stamp "CẦN CHÚ Ý" — label as alternate scenario); dark "nền tối".

**13. Thông báo.** Header "Thông báo" left, underlined "Đánh dấu đã đọc" right. Grouped by small labels with rules ("Hôm nay", "Hôm qua"). Each item is a ruled row: unread = bold title + tiny coral dot at left; caption with time; a glyph only (no circle). Items from Block D. Empty: Finny sketch asleep "Chưa có thông báo nào".

**Acceptance check (Batch 2):** the Home has exactly one featured block; quick actions are NOT tiles; 25.000.000 = 2.350.000 + 21.480.000 + 1.170.000; expense figures are ink (not red); dark variant uses only the "nền tối" palette.

---

## BATCH 3 – Transactions (10 screens)

**14. Sổ thu chi.** Header "Lịch sử giao dịch" left, search glyph and filter glyph (small coral dot when active) right. Under it a text filter line: "Tất cả · Chi tiêu · Thu nhập · Chuyển tiền nội bộ" where the active word is ink-bold with a 2px coral underline (no chips). List grouped by day with the header rule style; rows from Block D; transfer rows show "↔" and stamp "NỘI BỘ – KHÔNG TÍNH CHI TIÊU"; unsynced rows show a small cloud-off glyph. A floating rectangular button bottom-right (radius 8, solid ink) "＋ Ghi chép mới". Frames: normal; loading; empty ("Chưa có giao dịch nào"); error ("Thử lại"); offline strip with two unsynced rows; swipe-to-delete revealed ("Xóa" in rose-red text on paper, no red fill) + snackbar "Đã xóa giao dịch" with underlined "Hoàn tác".

**15. Bộ lọc (sheet).** Title "Bộ lọc" left, underlined "Đặt lại" right. Sections separated by rules, each with a small label: "Khoảng thời gian" (text options "Hôm nay", "7 ngày", "Tháng này", "Tùy chọn" as underlined selectable words + two date fields), "Tài khoản" (checkbox rows for the 3 accounts), "Danh mục" (two-column checkbox list with glyphs), "Loại giao dịch" (text segmented "Tất cả / Chi tiêu / Thu nhập / Chuyển tiền"), "Khoảng số tiền" (two money fields "Từ" / "Đến"). Bottom solid ink button "Áp dụng (3) →".

**16. Tìm kiếm.** Large single field with a bottom line, placeholder "Tìm theo mô tả, cửa hàng, ghi chú", autofocus, clear "×". Under it a label "Tìm gần đây" with rows "Cà phê", "WinMart" (clock glyph) and underlined "Xóa lịch sử". Results frame: matched text highlighted with a coral marker-pen underline ("Cà phê Highlands"). No-result frame: "Không tìm thấy giao dịch nào".

**17. Ghi chép – tab "AI Text" (sheet).** Sheet with a text tab strip (no boxes): "AI Text" (active, ink + coral underline) · "Giọng nói" · "Hóa đơn" · "Thủ công". Caption "Nhập câu tự nhiên, FinMate tự trích xuất thông tin:". Big recessed multiline field, placeholder "Ví dụ: "Ăn trưa cơm tấm 45k bằng ví tiền mặt", "Lương công ty 20 triệu"...", filled example "Cà phê Highlands 55k bằng MoMo". Below, three underlined suggestions "Ăn trưa 50k", "Grab 68k", "Lương 18 triệu". Button "Phân tích bằng FinMate AI →" (coral fill). Loading frame; error frame "AI Service không phản hồi. Bạn có thể nhập thủ công." + text button "Nhập thủ công".

**18. Ghi chép – tab "Thủ công".** Segmented text row "Chi tiêu · Thu nhập · Chuyển tiền" (active underlined). Fields as recessed lines: huge money field "Số tiền (VNĐ)" showing 45.000; "Danh mục" (dropdown list with glyph + name, plus "Chưa phân loại"); "Tài khoản"; "Ngày giờ" (18/10/2026 12:30); "Ghi chú". Button "Lưu giao dịch →". Variants: Chuyển tiền (hide category; "Từ tài khoản" and "Đến tài khoản" with a small swap glyph; error "Tài khoản nguồn và đích không được trùng nhau"); no-account ("Bạn chưa có tài khoản nào" / "Tạo một ví để bắt đầu ghi chép giao dịch." + button "Tạo ví tiền mặt" + small dialog "Số dư hiện có (VNĐ)" default 0, "Hủy"/"Tạo ví"); validation "Vui lòng nhập số tiền hợp lệ"; keyboard-open frame with fields above the keyboard.

**19. Tab "Giọng nói".** Center: a large hand-drawn microphone glyph inside a wobbly ink circle (idle). Recording frame: circle in coral with two concentric hand-drawn ripples, a waveform drawn as thin vertical ink strokes, timer "00:07", caption "Đang lắng nghe... Chạm để hoàn tất". After: transcript in an editable recessed field "Uống cafe Highland 55 ngàn bằng tài khoản MB" and buttons "Ghi lại" (secondary) / "Phân tích →". Permission-denied frame "Cần quyền micro để ghi âm" + "Mở cài đặt". "Sắp ra mắt" disabled frame.

**20. Tab "Hóa đơn".** A sketch of a camera and a receipt; text "Chụp hoặc tải ảnh hóa đơn", caption "OCR tự động bóc tách tổng tiền, nhà hàng & ngày giờ"; buttons "Chụp ảnh →" (ink) and "Chọn ảnh từ thư viện" (secondary). Preview frame with the photo, four hand-drawn corner marks, button "Quét hóa đơn →"; scanning frame with a sweeping line and "Đang đọc hóa đơn...".

**21. Xác nhận giao dịch AI.** Top "✕" and title "Xác nhận thông tin giao dịch". A single amber-left-ruled note: "AI cần bạn kiểm tra lại một số chi tiết" / "Thiếu thông tin: category. Vui lòng bổ sung trước khi lưu." Label "Nội dung nhận diện tự động" then the original sentence in Be Vietnam Pro italic as a pull-quote: "Cà phê Highlands 55k bằng MoMo". Then labeled sections separated by rules: "Loại giao dịch" (text options Chi tiêu / Thu nhập), "Số tiền (VNĐ)" (hero-number 55.000 ₫ in ink), "Danh mục" (text tags; AI-suggested one has a small star and coral underline: "Ăn uống"), "Tài khoản nguồn" ("MoMo"), "Ghi chú / mô tả". Buttons "Xác nhận & Lưu giao dịch →" (ink) and text link "Hủy bỏ bản ghi nháp". Frames: low-confidence (note visible) and high-confidence (no note).

**22. Chi tiết giao dịch.** Top: "←", title "Chi tiết giao dịch", "⋯" menu ("Sửa", "Xóa"). Hero: small glyph + "Cà phê Highlands" h2; hero-number "-55.000 ₫" (ink); stamp "ĐÃ ĐỒNG BỘ" (mint) or "CHƯA ĐỒNG BỘ" (amber). Then a definition list with rules: "Danh mục" Ăn uống · "Tài khoản" MoMo · "Thời gian" 18/10/2026 · 08:10 · "Nguồn" (stamp Thủ công/Thông báo/Giọng nói/Hóa đơn) · "Số dư sau giao dịch" 1.170.000 ₫ · "Ghi chú". Secondary button "Chia hóa đơn". Delete dialog (paper, rule border): "Xóa giao dịch này?" / "Hành động này không thể hoàn tác." — "Hủy" / "Xóa" (rose-red text).

**23. Chia hóa đơn.** Header "Chia hóa đơn". A single line summary "Lẩu Thái với bạn · 420.000 ₫". "Chia đều cho" with a −/+ stepper (4 người). Participants as ruled rows with initials in a hand-drawn circle: "Bạn" 105.000 ₫ (stamp "ĐÃ TRẢ" mint), "An" / "Bình" / "Chi" 105.000 ₫ (stamp "CHƯA TRẢ" amber), "Thêm người" row. Below a featured line "Bạn bè còn nợ bạn: 315.000 ₫". Buttons "Gửi nhắc nợ →" and per-row "Đánh dấu đã trả".

**Acceptance check (Batch 3):** list day total for 18/10 is -100.000 ₫; transfers never look like expenses; filters are text-underline, not chips; the create sheet's tab strip identical across frames.

---

## BATCH 4 – Planning (6 screens)

**24. Kế hoạch – Ngân sách.** Header "Kế hoạch tài chính" with a text tab strip: "Hạn mức ngân sách" (active) · "Mục tiêu tiết kiệm". **Featured block:** label "Hạn mức chi tiêu hôm nay", hero-number "435.846 ₫ / ngày" (coral figure), line "Ngân sách tháng: 9.000.000 ₫ · Đã chi 3.334.000 ₫", thin 4px line at 37%, stamp "CÒN 13 NGÀY". Section label "Ngân sách theo danh mục" + right text link "＋ Thêm". Then ruled entries (NOT cards): name left, percent right, thin progress line with tick, below "Đã chi: 615.000 ₫ · Hạn mức: 3.000.000 ₫" in caption; entries: Ăn uống (20,5% mint), Di chuyển (17,3% mint), Mua sắm (86% amber), Giải trí (87% amber), Hóa đơn (97% rose-red + stamp "SẮP HẾT"). Frames: normal; **no-budget** (block replaced by an inviting sentence "Bạn chưa đặt ngân sách tháng này" / "Đặt hạn mức chi tiêu cả tháng để FinMate gợi ý mức chi an toàn mỗi ngày." + button "Tạo ngân sách tháng →"); **over-budget** (hero replaced by "ĐÃ CHI VƯỢT NGÂN SÁCH!" in rose-red, "Bạn đã tiêu quá hạn mức tháng. Hãy dừng chi tiêu không thiết yếu!"); loading; error.

**25. Thêm / sửa ngân sách (sheet).** Title "Thêm ngân sách danh mục" (or "Tạo ngân sách tháng" / "Sửa Mua sắm"). Category picker rows (glyph + name; only categories without budget), huge money field "Hạn mức chi tiêu (VNĐ)", buttons "Hủy" (text) / "Lưu →". Errors "Vui lòng chọn danh mục", "Vui lòng nhập số tiền hợp lệ", "Bạn đã có hạn mức cho danh mục này." Edit mode adds underlined rose-red "Xóa ngân sách".

**26. Kế hoạch – Mục tiêu.** Label "Mục tiêu tiết kiệm hiện có" + "＋ Mục tiêu mới" (text link). Each goal is a ruled entry laid out like a ledger line: title h3 left, status stamp right ("CẦN ~3.600.000 ₫/THÁNG"); under it "Hạn chót: 31/03/2027"; a thin mint progress line with tick at 40%; two-column figures "Đã tích lũy 12.000.000 ₫" / "Mục tiêu 30.000.000 ₫"; text button "Nạp tiền vào mục tiêu →" (disabled for finished). Three goals from Block D (completed one stamped "HOÀN THÀNH" mint). Empty: sketch of a piggy bank, "Bạn chưa có mục tiêu tiết kiệm nào." + "Tạo mục tiêu đầu tiên". Overdue variant stamp "TRỄ HẠN" rose-red.

**27. Tạo mục tiêu (sheet).** Title "Tạo mục tiêu tiết kiệm". "Tên mục tiêu" (hint "Quỹ du lịch"), huge money field "Mục tiêu tích lũy (VNĐ)", text button "Chọn hạn chót (tùy chọn)" opening a paper-styled calendar frame (selected day circled with hand-drawn ink ring). Live line: "Để đạt mục tiêu, bạn cần nạp khoảng 3.600.000 ₫/tháng." Buttons "Hủy" / "Tạo mục tiêu →". Error "Vui lòng nhập tên mục tiêu".

**28. Nạp tiền & ăn mừng.** Sheet: title "Nạp tiền vào "Quỹ khẩn cấp"", huge money field "Số tiền (VNĐ)" 1.000.000, three underlined quick amounts "+500.000", "+1.000.000", "+2.000.000", optional note, source account, "Hủy" / "Nạp tiền →"; error "Vui lòng nhập số tiền hợp lệ". Success frame: the goal line animates to 43,3% and snackbar "Đã nạp 1.000.000 ₫ vào mục tiêu!". **Level-up frame (full screen, paper):** big hand-drawn Finny wearing the new item with ink-stroke confetti, h1 "Bạn vừa lên cấp 5!", subtitle "Mở khóa: Sơ mi công sở", coral button "Tuyệt vời!".

**29. Giao dịch định kỳ & nhắc hóa đơn.** Header "Giao dịch định kỳ" + "＋". Section label "Sắp đến hạn": ruled rows "Internet FPT · 220.000 ₫ · hạn 20/10 · còn 2 ngày" (amber stamp), "Tiền nước · 95.000 ₫ · hạn 25/10 · còn 7 ngày". Section "Đã thanh toán tháng này": Netflix (ngày 16), Tiền điện (ngày 13) each with a hand-drawn tick. Each row has "Nhắc trước 1 ngày" toggle. Add sheet: name, money, category, account, repeat "Hằng tháng/Hằng tuần", day, reminder toggle, "Lưu →". Empty "Chưa có khoản định kỳ nào".

**Acceptance check (Batch 4):** progress lines are thin with a tick, never chunky bars; colors follow 70/90 rule (mint/amber/rose-red); hero "435.846 ₫ / ngày" matches Block D; no cards anywhere.

---

## BATCH 5 – Analytics (4 screens)

**30. Phân tích – tháng.** Header "Phân tích chi tiêu & Xu hướng", export glyph. Period as text tabs: "Tháng này" (active) · "Tuần này" · "Năm nay" (last two ink-3 with caption "Tuần và năm sắp có."). Order of content:
 (a) Comparison as a sentence block, not a card: a small down-arrow glyph in mint + "Chi tiêu giảm 12,5%" (h2) and "Bạn đã chi ít hơn 476.000 ₫ so với tháng trước."
 (b) "Cơ cấu chi tiêu theo danh mục": a single horizontal stacked **ribbon bar** (segments in ink, coral, mint, amber, rose-red, light grey (#E5E2DA)) with total label "3.334.000 ₫ · Tổng chi"; below, ruled legend rows "Mua sắm (39%)" … amount right, each row with a small colored square swatch. No donut.
 (c) "Xu hướng chi tiêu theo ngày": hand-plotted line chart of DAILY SPEND (1.5px ink line, filled dots, light hatched fill), a vertical dotted line for "Hôm nay", one annotated point "15/10 · 742.000 ₫".
 (d) "Dự báo chi tiêu đến cuối tháng" as a ledger: rows "Đã chi tới nay 3.334.000 ₫", "Dự kiến cuối tháng 5.742.000 ₫" (bold), "Ngân sách tháng 9.000.000 ₫" + thin mint line at 64%, rule, "Thu nhập tháng 18.000.000 ₫", "Số dư dự kiến cuối tháng 12.258.000 ₫" (bold), caption "Độ tin cậy: trung bình · dựa trên 18 ngày".
 Frames: normal; empty ("Chưa có chi tiêu tháng này", "Chưa đủ dữ liệu để dự báo"); error ("Thử lại"); spending-up ("Chi tiêu tăng 20%" with rose-red up-arrow, "Bạn đã chi nhiều hơn 2.000.000 ₫ so với tháng trước."); negative-balance ("-500.000 ₫" in rose-red and row "Gợi ý cắt giảm mỗi ngày 20.000 ₫").

**31. Chi tiết danh mục.** "←" + "Mua sắm". Hero-number "1.291.000 ₫", caption "38,7% tổng chi · 2 giao dịch", thin amber progress line at 86% of budget. A small hand-drawn bar chart "Theo tuần" (4 bars in ink with hatched fill). Ruled list: WinMart 742.000, Uniqlo 549.000. If no budget: text button "Đặt ngân sách cho danh mục →".

**32. Gợi ý từ FinMate.** Header "Gợi ý từ FinMate"; text filter "Tất cả · Chưa đọc". Entries as ruled notes each with a colored left rule (2px): amber "Ngân sách Hóa đơn sắp hết" (97%, link "Xem ngân sách →"), ink "Chi tiêu Ăn uống thấp hơn mức trung bình 20%", mint "Bạn đang đi đúng kế hoạch tiết kiệm Quỹ khẩn cấp"; time caption and swipe "Đã đọc". Empty "Chưa có gợi ý nào".

**33. Xuất báo cáo (sheet).** Title "Xuất báo cáo"; month selector "Tháng 10/2026"; format as text options "PDF · Excel · CSV" (active underlined); checklist "Tổng quan thu chi", "Cơ cấu theo danh mục", "Danh sách giao dịch", "Dự báo"; a small page-thumbnail sketch of the report (paper page with Finny stamp and totals). Button "Xuất báo cáo →". Success frame "Đã tạo báo cáo" with "Chia sẻ" / "Mở tệp".

**Acceptance check (Batch 5):** ribbon bar segments sum to 3.334.000 ₫ and legend equals Block D; forecast rows equal Block D; charts are thin ink-drawn style with no rounded colored bars or donut.

---

## BATCH 6 – Profile & Settings (10 screens)

**34. Cá nhân.** Header "Cá nhân & Gamification". Top: a large initial "T" in Bricolage Grotesque inside a wobbly hand-drawn circle, "Nguyễn Minh Tuấn", "tuan@email.com", text link "Sửa". **Featured block:** "Cấp 4" (hero style) with "520 / 800 XP" right, thin coral progress line, line "Chuỗi hiện tại: 6 ngày · Dài nhất: 12 ngày" with a small flame glyph. Section label "Tủ đồ linh vật Finny": items as text tags (owned = outline; equipped "Mũ lưỡi trai" = filled ink with paper text; locked = dashed outline with lock glyph and its hint below in caption). Then a ruled menu (glyph, title, chevron): "Nhiệm vụ", "Tài khoản & ví", "Danh mục", "Giao dịch định kỳ", "Xuất báo cáo", "Cài đặt". Trust line with shield glyph. Text button "Đăng xuất tài khoản" in rose-red with a 1px rose-red underline. Frames: normal, loading, error ("Thử lại"), logout dialog "Còn giao dịch chưa đồng bộ" / "Còn 2 giao dịch chưa được gửi lên máy chủ. Đăng xuất sẽ làm mất chúng." — "Hủy" / "Vẫn đăng xuất".

**35. Tủ đồ Finny.** Top half: large Finny sketch on a paper-sunk backdrop that changes with the equipped background. Text tabs "Mũ · Phụ kiện · Nền · Trang phục". Grid of 3 columns of items drawn as small sketches on paper (owned: tap to equip, equipped gets an ink ring and a hand-drawn tick; locked: faded with lock and hint in caption). Note "Mỗi loại chỉ mặc được một món." Button "Lưu trang phục →".

**36. Nhiệm vụ.** Text tabs "Hằng ngày · Hằng tuần · Một lần". Summary line "Hôm nay: 1/2 nhiệm vụ · +30 XP". Missions as ruled entries: title, description caption, thin progress line and "2/3", reward stamp "+50 XP"; completed = hand-drawn tick and "Đã hoàn thành". Link "Lịch sử nhiệm vụ →".

**37. Tài khoản & ví.** Header "Tài khoản & ví" + "＋". Line "Tổng cộng 25.000.000 ₫" (h2). Ruled rows: glyph by type, name, caption type, balance right, small toggle "Theo dõi"; the 3 accounts. Tap → account detail (hero balance + that account's transactions). Empty: "Bạn chưa có tài khoản nào" + "Tạo ví tiền mặt".

**38. Thêm / sửa tài khoản (sheet).** Title "Thêm tài khoản". Text options "Ngân hàng · Ví điện tử · Tiền mặt"; provider list (for bank/wallet); "Tên tài khoản"; huge money field "Số dư ban đầu (VNĐ)" (0 allowed). Error "Bạn đã có tài khoản khác theo dõi ứng dụng này." Edit mode: rose-red text "Xóa tài khoản" + dialog "Xóa tài khoản này? Các giao dịch liên quan sẽ không còn hiển thị tên tài khoản."

**39. Danh mục.** Section "Danh mục hệ thống" (11 ruled rows with glyph, lock mark = chỉ xem) and "Danh mục của bạn" (empty sentence + "＋ Thêm danh mục"). Add sheet: name field, icon picker as a 6×4 grid of hand-drawn glyph sketches (selected one circled), "Lưu →".

**40. Cài đặt.** Sections separated by big rules and small labels: "Thông báo" (toggles "Thông báo đẩy", "Cảnh báo ngân sách", "Nhắc nhiệm vụ"), "Bảo mật" ("Khóa ứng dụng bằng sinh trắc học", "Ẩn số dư khi vào nền", "Đổi mật khẩu", "Đăng xuất mọi thiết bị"), "Hiển thị" (text options "Sáng · Tối · Theo hệ thống", "Ngôn ngữ: Tiếng Việt"), "Dữ liệu & quyền riêng tư" ("Xuất dữ liệu", "Điều khoản dịch vụ", "Chính sách quyền riêng tư"), rose-red row "Xóa tài khoản". Version caption at bottom. All toggles share the one hand-drawn rectangular style.

**41. Đổi mật khẩu.** Fields "Mật khẩu hiện tại", "Mật khẩu mới" (strength line), "Xác nhận mật khẩu mới"; button "Đổi mật khẩu →"; errors "Mật khẩu hiện tại không đúng"; success snackbar "Đã đổi mật khẩu".

**42. Xóa tài khoản.** A rose-red-left-ruled note: "Xóa tài khoản vĩnh viễn" with lines "Toàn bộ giao dịch, ngân sách, mục tiêu sẽ bị xóa" and "Hành động này không thể hoàn tác". Field "Nhập mật khẩu để xác nhận", hand-drawn checkbox "Tôi hiểu hậu quả", solid rose-red button "Xóa tài khoản" (disabled until both satisfied), text "Hủy".

**43. Trạng thái hệ thống (one frame each).** Each is a paper page with a small Finny sketch and a sentence: "Không có kết nối mạng" / "Vui lòng kiểm tra lại đường truyền." + "Thử lại"; "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại"; "Máy chủ đang gặp sự cố. Vui lòng thử lại sau."; "FinMate đang bảo trì" (with estimated time); "Đã có phiên bản mới" + "Cập nhật ngay".

**Acceptance check (Batch 6):** Cấp 4, 520/800, chuỗi 6/12 match Block D; only one equipped item per category; destructive actions in rose-red with confirmation; all toggles identical.

---

## FINAL CONSISTENCY PASS (paste after all batches, optional)

```
Review all frames and fix inconsistencies without redesigning layouts:
1) Palette only: paper #FBFAF7, sunk #F1EFEA, ink #14171A, rule #E5E2DA, coral #FF5A36, mint #0FA968,
   amber #F5A623, rose-red #E5384F (dark variant: "nền tối"). Remove any blue, purple, neon or pure black/white.
2) No bordered rounded cards, no circular tinted icon backgrounds, no pill buttons, no drop shadows.
   At most one featured block per screen.
3) Expenses are plain ink with "-"; income is mint with "+"; transfers are ink-3 with "↔" and stamp "NỘI BỘ".
4) Headings Bricolage Grotesque, UI text Be Vietnam Pro; all Vietnamese diacritics render correctly; money uses tabular figures.
5) Progress = thin 4px line + end tick; charts = thin ink-drawn style; ribbon bar instead of donut.
6) Every screen has exactly one dominant action (solid ink or coral button). One icon set only; no emoji.
7) Numbers match the sample data exactly.
```

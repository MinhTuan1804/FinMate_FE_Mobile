# Prompt Stitch – UI/UX FinMate (bản sau khi bỏ gamification)

> Cách dùng: dán **Phần 1** (Prompt nền) vào Stitch trước, dán **Phần 1B** (luồng người dùng mới từ lúc đăng ký) để Stitch nối prototype, rồi dán lần lượt từng **Phần 2** (prompt từng màn hình) để tạo/chỉnh màn. Phần 3 là bảng dữ liệu mỗi màn hình cần. Phần 4 là những điểm cần bạn quyết định.
> Bảng màu lấy từ `b_ng_m_m_u_ui_app_t_i_ch_nh_ai.md`. Tôi chọn **Style A (Modern & Smart)** vì có sẵn màu AI Accent cho chatbot; nếu bạn muốn Style B/C chỉ cần thay bảng màu ở mục 1.2.

---

## PHẦN 1 – PROMPT NỀN (dán đầu tiên)

```
Design a complete mobile app UI (iOS/Android, 390×844 base, portrait) called "FinMate":
a Vietnamese personal-finance app with an AI assistant. All UI copy is in Vietnamese.
Money is Vietnamese đồng, formatted vi-VN with a dot as thousands separator and the ₫ sign
after a space, e.g. "55.000 ₫", "24.000.000 ₫". Never show decimals. Dates are dd/MM/yyyy,
times HH:mm.

PRODUCT SCOPE (only these features exist):
1. Auth + onboarding (email sign-in, OTP email verification, set monthly income, pick sources to track).
2. Home dashboard (balance, quick actions, recent transactions, assistant entry).
3. AI assistant = ONE messenger-style chat screen where the user can type, talk (voice-to-text
   inside the input bar) or scan a bill (photo sent as a chat message). No separate voice or
   scan screens. Drafts from the chat end in ONE shared "Review & save transaction" screen.
4. Transactions list + manual entry.
5. Planning: monthly budget limits and savings goals.
6. Analytics + PERSONAL FINANCIAL FORECAST (projected month-end spending and balance).
7. Profile + notification settings.
8. A small mascot that appears ONLY as a notification when the user crosses the safe
   spending threshold (see "Mascot alert").
NO gamification: no points, XP, levels, streaks, badges, missions, leaderboards, avatars
wardrobe, or collectibles anywhere. Do not invent extra features.

1.1 DESIGN PRINCIPLES
- Calm, trustworthy, modern fintech. Light mode is primary; also deliver dark mode for every screen.
- Numbers are the hero: large, tabular (monospaced digits), high contrast.
- 60-30-10 rule: 60% neutrals, 30% brand navy/blue, 10% accents (AI violet, green for primary action).
- Icons: one consistent line-icon set (Lucide style, 2px stroke, 20–24px). No emoji as icons,
  no hand-drawn icons.
- Radius 12 for cards/inputs, 999 for pills/chips, 20 for bottom sheets. Soft shadow only on
  floating elements; cards use 1px borders instead of heavy shadows. No card inside card.
- 8-pt spacing grid, 20px screen side padding, minimum touch target 48px.
- Font: Inter (or Be Vietnam Pro) – must render Vietnamese diacritics well. Sizes:
  Display 32/700, H1 24/700, H2 20/600, Body 16/400, Caption 13/400, Overline 12/700 caps.
- Every screen must show its states: loading (skeleton), empty, error (with "Thử lại"),
  and where relevant offline ("Chưa đồng bộ" badge).
- WCAG AA contrast, visible focus, labels on all inputs, no color-only meaning
  (pair color with an icon or sign: "+" / "−").
- Do NOT use: purple-to-blue generic gradients on backgrounds, lorem ipsum, stock illustrations
  of people, fake brand logos, glassmorphism everywhere, neon glow on non-AI elements.

1.2 COLOR TOKENS (Style A – Modern & Smart)
This is a brand-new visual identity. Use ONLY the colors listed in this section. Do not
reuse, imitate, or infer any colors from an existing version of the app or from any
screenshot; the old palette is discarded. Keep the overall look bright, airy and clean
(light mode first, generous white space, navy used sparingly for the balance card and text).
Brand:      Primary Deep Navy #0F172A · Primary Active Royal Blue #2563EB
AI:         AI Accent Neon Violet #8B5CF6
            AI gradient (ONLY for AI avatar, AI floating button, AI card outline):
            linear-gradient(135deg, #6366F1 0%, #A855F7 50%, #EC4899 100%)
Secondary:  Soft Teal / success #10B981
Functional: Income #10B981 · Expense #EF4444 · Warning #F59E0B · Info #3B82F6
Light mode: Background #F8FAFC · Surface #FFFFFF · Border #E2E8F0 ·
            Text primary #0F172A · Text secondary #64748B · Text disabled #94A3B8
Dark mode:  Background #0F172A · Surface #1E293B · Border #1E293B (use #334155 for visible dividers) ·
            Text primary #F8FAFC · Text secondary #94A3B8 · Text disabled #64748B
AI Smart Insight card – Light: bg #F3E8FF, border #D8B4FE, text #581C87.
                        Dark: bg rgba(139,92,246,0.15), border rgba(168,85,247,0.4), soft violet glow.
Rules: red #EF4444 means money out / over budget (and AI only uses red for serious financial
risk). Primary CTA buttons are Royal Blue #2563EB with white text, pill shaped. Anything
written by the AI carries a small sparkles icon or the violet/gradient outline.

1.3 NAVIGATION
Bottom navigation, 4 tabs: Trang chủ · Giao dịch · Kế hoạch · Phân tích. Center-right floating
button "Ghi chép" (opens the entry bottom sheet). Profile opens from the avatar icon in the
Home header. The assistant opens from the "Hỏi FinMate" bar on Home and from the sheet.
Bottom nav is visible on the 4 main tabs only.

1.4 MASCOT ALERT (the only place a mascot exists)
A small friendly mascot (simple geometric character, 2–3 colors from the palette, NOT cartoonish
kids style) shown inside a dismissible banner/bottom sheet when the safe threshold is crossed.
Three variants, same character:
 - "Sắp chạm ngưỡng" (80–90% of budget): amber #F59E0B accent, concerned-but-calm pose.
   Copy: "Bạn đã dùng 85% ngân sách tháng. Mức chi an toàn còn 120.000 ₫/ngày."
 - "Đã vượt ngưỡng" (>100%): red #EF4444 accent, alert pose. Copy: "Bạn đã chi vượt ngân sách
   tháng 320.000 ₫. Hãy tạm dừng các khoản không thiết yếu."
 - "Quay lại an toàn" (optional): green accent, relaxed pose.
Buttons: "Xem kế hoạch" (primary) and "Để sau" (text). Never blocks the screen, never shown on
every launch (max once per threshold crossing). No points or rewards attached.
```

---

## PHẦN 1B – LUỒNG NGƯỜI DÙNG MỚI TỪ ĐẦU (dán sau Phần 1, trước các màn hình)

Dùng để Stitch nối các màn thành một prototype có thể bấm đi từng bước. Mỗi dòng là một cú chạm.

```
Create a clickable prototype of the complete first-time journey of a brand-new user.
Connect the screens in this exact order and show the same user data consistently
(name "Minh Tuấn", email "tuan@example.com"). Show each transition (button label → next screen).

STEP 1  Welcome (S01). User ticks the terms checkbox → buttons become enabled.
        Taps "Tạo tài khoản mới".
STEP 2  Đăng ký (S03). Fills the form, taps "Đăng ký tài khoản".
STEP 3  Xác thực Email (S04). Enters the 6-digit code, taps "Xác nhận".
STEP 4  Đăng nhập (S02) with the email pre-filled and the info banner "Email đã xác thực.
        Hãy đăng nhập." Enters password, taps "Đăng nhập".
        (Alternative branch for returning users: Welcome → "Đăng nhập với Email" → S02 directly.)
STEP 5  Thiết lập ban đầu (S05), because the new user has no monthly income yet:
        5a "Tự động ghi nhận thông minh" → "Tiếp tục"
        5b "Chọn nguồn cần theo dõi" (toggle 2 banks) → "Tiếp tục"
        5c "Kế hoạch tài chính tháng": types 15.000.000 → "Hoàn tất & Khám phá FinMate".
        (A cash wallet is created automatically at this point.)
STEP 6  Trang chủ (S06) in its FIRST-RUN state: balance 0 ₫, empty recent-transactions
        message, the "Hỏi FinMate" bar prominent, a one-time coach hint pointing at "Ghi chép".
STEP 7  Taps the "Hỏi FinMate" bar → Chat (S08, empty state). Taps the suggestion chip
        "ăn phở 45k" (or types it) → typing indicator → assistant replies with a Draft card
        (missing category) → taps "Xem và lưu" → Xác nhận giao dịch (S11) → "Xác nhận & Lưu
        giao dịch" → back to chat: card collapses to "Đã ghi: 45.000 ₫ · Ăn uống".
STEP 8  In the same chat: taps the mic, speaks "cafe 30k" (words appear in the input field),
        sends → "Đã ghi giao dịch" card. Then taps the scan icon → sheet → "Chọn ảnh từ thư viện"
        → photo bubble → "Đang đọc hóa đơn..." → Draft card → S11 → saved.
STEP 9  Back to Trang chủ (S06) in its POPULATED state: balance reduced, 3 recent transactions.
STEP 10 Tab "Kế hoạch" (S13): empty state "Bạn chưa đặt ngân sách tháng này" → "Tạo ngân sách
        tháng" → enters 15.000.000 → budget hero card with safe daily spend → adds a category
        budget for Ăn uống. Switch to "Mục tiêu tiết kiệm" (S14) → "Tạo mục tiêu" → "Quỹ khẩn
        cấp" → "Nạp tiền".
STEP 11 Tab "Phân tích" = Thống kê (S15): switches Ngày → Tuần → Tháng → Năm, taps the Wednesday bar to see
        its amount and transactions, then taps the forecast entry card → "Dự báo tài chính" (S16).
STEP 12 Mascot alert: show one frame where the budget reaches 85% and the "Sắp chạm ngưỡng"
        banner appears on Trang chủ with "Xem kế hoạch" → opens S13.
STEP 13 Avatar icon → Cá nhân & Cài đặt (S17): open "Giao diện & hiển thị" (S23) and switch to
        Tối, open "Ngưỡng cảnh báo" (S24) and drag the warning handle to 75%, open "Sao lưu dữ liệu"
        (S25) and create a backup, open "Nhập dữ liệu từ file" (S26) through its 4 steps; then
        "Đăng xuất tài khoản" → confirm → back to Welcome (S01).

Also provide the bottom-nav behavior: tabs Trang chủ · Giao dịch (S12) · Kế hoạch (S13/S14) ·
Phân tích (S15/S16), and the floating "Ghi chép" button opening the sheet (S07) from any tab.
Keep the visual identity from Part 1; do not add screens that are not listed.
```

---

## PHẦN 2 – PROMPT TỪNG MÀN HÌNH

Mỗi khối dưới đây dán riêng vào Stitch (sau Phần 1). Mã `S01…` dùng để đối chiếu với bảng dữ liệu ở Phần 3.

### Nhóm A – Xác thực & Onboarding

**S01 – Welcome**
```
Screen "Welcome" for FinMate. Clean first screen: logo mark + wordmark, one headline
("Quản lý tiền thông minh, an toàn"), one-line subcopy. A security promise card titled
"Cam kết bảo mật Zero-Credential" explaining FinMate never asks for banking passwords or
OTP of the bank. A required checkbox "Tôi đồng ý Điều khoản & Chính sách bảo mật". Two buttons:
primary "Đăng nhập với Email" and secondary "Tạo tài khoản mới" (both disabled until the
checkbox is ticked, show the disabled state). Include light + dark.
```

**S02 – Đăng nhập**
```
Screen "Đăng nhập" titled "Chào mừng trở lại". Fields: Email, Mật khẩu (show/hide eye).
Primary button "Đăng nhập". Link "Tạo tài khoản mới". States: empty, field validation errors
(under each field), server error banner (e.g. "Email hoặc mật khẩu không đúng."), loading
button, info banner "Email đã được xác thực. Hãy đăng nhập." , info banner
"Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." Back arrow top-left.
```

**S03 – Đăng ký**
```
Screen "Tạo tài khoản": fields Tên hiển thị, Email, Mật khẩu, Nhập lại mật khẩu, with a small
password-rule checklist (≥8 ký tự, chữ hoa, chữ thường, số, ký tự đặc biệt) that ticks live.
Primary "Đăng ký tài khoản". Show validation, loading, and "Email đã tồn tại" error states.
```

**S04 – Xác thực email (OTP)**
```
Screen "Xác thực Email": shows the target email, a 6-digit code input (one field or 6 boxes),
primary "Xác nhận", text button "Gửi lại mã" with a 60s cooldown timer, error state
"Mã không đúng hoặc đã hết hạn".
```

**S05 – Thiết lập ban đầu (3 bước, có thanh tiến độ)**
```
Onboarding wizard "Thiết lập ban đầu", 3 steps with a progress indicator and "Tiếp tục" button:
 Step 1 "Tự động ghi nhận thông minh": explain how FinMate reads bank notifications on device
   (no passwords) – 3 benefit rows with icons, privacy note.
 Step 2 "Chọn nguồn cần theo dõi": list of providers/banks with logo placeholder (initial
   letter circle), name, and a toggle; loading skeleton, error "Thử lại", empty state.
 Step 3 "Kế hoạch tài chính tháng": input "Thu nhập hàng tháng (VNĐ)" with live dot formatting,
   helper text, final button "Hoàn tất & Khám phá FinMate". Validation: amount must be > 0.
```

### Nhóm B – Trang chủ & Trợ lý AI

**S06 – Trang chủ**
```
Home dashboard. Header: "Xin chào," + user display name, profile icon button (top-right).
1) Balance card (navy surface, white text): label "Tổng số dư", big total balance, below it
   up to 3 account chips (name + balance), and a mini line "Tháng này: −45.000 ₫ đã chi".
2) Assistant bar (white card, violet outline, sparkles icon): "Hỏi FinMate: ăn phở 45k, tháng
   này tôi tiêu bao nhiêu?" with two small icon buttons on the right: scan (scanLine) and mic.
   Tapping the bar opens the chat.
3) Quick actions row (4 items): Ghi chép, Giao dịch, Kế hoạch, Phân tích.
4) Section "GIAO DỊCH GẦN ĐÂY" with "Xem tất cả": 5 rows – category icon in tinted circle,
   description, category + time, amount right-aligned (red "−55.000 ₫" / green "+20.000.000 ₫").
5) Optional Mascot alert banner above the balance card when over the safe threshold.
States: loading skeleton, empty (no account: "Bạn chưa có tài khoản. Bấm 'Ghi chép' để tạo
ví đầu tiên."; no transactions: "Chưa có giao dịch nào. Hãy bấm 'Ghi chép' để thêm giao dịch
đầu tiên!"), error with retry, offline badge "n giao dịch chưa đồng bộ". Bottom nav visible.
```

**S07 – Sheet "Ghi chép" (bottom sheet, 75% height, 4 tabs)**
```
Bottom sheet "Ghi chép" with a drag handle and a 4-tab bar: AI Text · Giọng nói · Hóa đơn · Thủ công.
- AI Text / Giọng nói / Hóa đơn tabs: icon (sparkles / mic / scan), a short description
  ("Nhắn tự nhiên như 'ăn phở 45k'…", "Nói tự nhiên, FinMate chuyển thành chữ…", "Chụp hoặc chọn
  ảnh hóa đơn…") and ONE primary pill button ("Mở trợ lý" / "Nói để ghi chép" / "Quét hóa đơn").
  All three buttons open the SAME chat screen (S08); the second starts listening, the third
  opens the scan source sheet right away.
- Thủ công tab: type chips (Chi tiêu / Thu nhập / Chuyển tiền), field "Số tiền (VNĐ)",
  Danh mục dropdown (icon + name, "Chưa phân loại" option), Tài khoản dropdown
  (for Chuyển tiền: "Từ tài khoản" + "Đến tài khoản"), Ghi chú, primary "Lưu giao dịch".
  Error text states: "Vui lòng nhập số tiền hợp lệ", "Cần ít nhất 2 tài khoản để chuyển tiền",
  "Tài khoản nguồn và đích không được trùng nhau". Empty-account state with "Tạo ví tiền mặt"
  (dialog with initial balance).
Keyboard-aware (sheet lifts above keyboard).
```

**S08 – Trợ lý FinMate (Chat kiểu Messenger – nơi duy nhất để nhắn, nói và quét bill)**
```
ONE single chat screen "Trợ lý FinMate", designed like a messenger app (Messenger / iMessage
feel). There are NO separate screens for voice or receipt scanning: the user stays in this chat
and can type, talk, or scan a bill from the input bar at any time.

Top: app bar with back arrow, title "Trợ lý FinMate" with a small AI sparkles avatar
(AI gradient circle) and a subtitle "Trợ lý tài chính AI".

Message list (newest at the bottom, auto-scroll):
 - User text bubble: right-aligned, Royal Blue, white text, rounded 16 with a small tail corner.
 - User receipt-photo bubble: right-aligned image thumbnail (about 200px wide, rounded 16) –
   the bill photo the user just sent, exactly like sending a picture in Messenger.
 - Assistant text bubble: left-aligned, neutral surface, tiny sparkles AI mark.
 - "Đang trả lời..." typing bubble with 3 animated dots; when a bill photo was just sent the
   text is "Đang đọc hóa đơn..." with a subtle scanning shimmer over the sent photo.
 - "Đã ghi giao dịch" card: green check, big amount "−55.000 ₫", description, category,
   "Số dư sau giao dịch: 30.845.000 ₫", link "Xem giao dịch".
 - Summary card "Tóm tắt chi tiêu tháng này" (violet AI Smart Insight styling): rows Tổng chi /
   Tổng thu / Còn lại, then up to 5 category rows (icon, name, percent, amount).
 - Draft card "Giao dịch cần xác nhận" (also what a scanned bill turns into): amount,
   description or merchant, category, amber line "Cần bổ sung: danh mục" and, for bills, a small
   confidence hint, primary button "Xem và lưu". After saving it collapses to
   "Đã ghi: 20.000.000 ₫ · Thu nhập".
 - Assistant bubble when a bill cannot be read: "Không đọc được hóa đơn. Bạn thử chụp rõ hơn
   hoặc nhập tay."
 - Error note (red tint) "Không có kết nối mạng." + "Gửi lại" (works for both a failed text
   message and a failed bill scan – it resends the same photo, no duplicate bubble).
Empty state: sparkles icon, "Bạn muốn ghi gì hôm nay?", helper line "Nhắn, nói hoặc quét bill –
FinMate sẽ ghi chép giúp bạn.", suggestion chips ("ăn phở 45k", "tháng này tôi tiêu bao nhiêu?").

Above the input: small pill "Ghi vào: Ví tiền mặt ⌄" (opens an account menu).

INPUT BAR (always visible, one row, like Messenger): [scan-bill icon button] [rounded text
field "Nhắn: "ăn phở 45k"..."] [mic icon button] [send button]. Send is disabled when the
field is empty or the assistant is busy. Design these in-chat interactions as extra frames of
this SAME screen:

 (a) TALK – tap the mic: the mic button turns into a red "stop" mic, the text field shows the
     placeholder "Đang nghe..." and the words appear live inside the text field as the user
     speaks, with a small pulsing violet waveform strip above the input bar. Tap the mic again
     to stop; the recognized text stays in the field so the user can edit it, then press send.
     Frames: listening; stopped with editable text; permission denied (snackbar: "Cần quyền
     micro để ghi âm. Vào Cài đặt > Ứng dụng > FinMate > Quyền > Micro để bật."); device not
     supported (snackbar: "Thiết bị chưa hỗ trợ nhận dạng giọng nói. Bạn có thể nhập bằng bàn
     phím."); heard nothing (snackbar: "Mình chưa nghe thấy gì, bạn thử lại nhé").

 (b) SCAN – tap the scan icon: a small bottom sheet slides up with three rows, each with an
     icon: "Quét bill" (scan-line icon), "Chụp ảnh" (camera icon), "Chọn ảnh từ thư viện"
     (image icon). After choosing/capturing, the photo is posted straight into the chat as a
     user photo bubble, then the "Đang đọc hóa đơn..." state, then the assistant replies with
     the Draft card (or the "Không đọc được hóa đơn…" bubble). Frames: the 3-option sheet; photo
     sent + reading; resulting draft card; unreadable bill; camera permission denied (snackbar:
     "Cần quyền camera để chụp hóa đơn. Bạn có thể bật quyền trong Cài đặt > Ứng dụng >
     FinMate > Quyền.").

 (c) Entry shortcuts: from Home, the mic and scan icons on the "Hỏi FinMate" bar open this
     chat and immediately start (a) or (b).
```

**S09 – (đã gộp vào S08) Giọng nói trong chat**
```
No separate screen. Use the "TALK" frames described in S08 (a). Nothing else to design here.
```

**S10 – (đã gộp vào S08) Quét hóa đơn trong chat**
```
No separate screen. Use the "SCAN" frames described in S08 (b). Nothing else to design here.
```

**S11 – Xem lại & lưu giao dịch (dùng chung cho tin nhắn, giọng nói và quét bill trong chat)**
```
Screen "Xác nhận giao dịch". Top: if AI is unsure (confidence < 85% or missing fields) show an
amber banner "AI cần bạn kiểm tra lại một số chi tiết". Form: type chips (Chi tiêu / Thu nhập /
Chuyển tiền), Số tiền (big input), Danh mục (chip grid with icons, pre-selected from AI),
Tài khoản (dropdown; transfer shows Từ/Đến), Tên cửa hàng, Ghi chú, Ngày giờ (date picker;
default now). A small source tag "Nguồn: Hóa đơn / Giọng nói / Chat" with sparkles for AI-filled
fields. Primary button "Xác nhận & Lưu giao dịch". Validation texts as in S07. Loading + error states.
```

### Nhóm C – Giao dịch, Kế hoạch, Phân tích

**S12 – Giao dịch**
```
Screen "Giao dịch": search/filter row (type filter chips: Tất cả / Chi / Thu / Chuyển, account
filter), list grouped by date headers ("Hôm nay", "Hôm qua", dd/MM/yyyy) each with the day's
total spent/earned on the right. Rows: category icon, description/merchant, category + account,
amount colored with sign; small badges: "Chưa đồng bộ" (info blue), source icon for Voice /
Receipt / Notification. Pull to refresh, infinite scroll loader, empty state, error state.
Tap a row → transaction detail bottom sheet (all fields, balance after, source, time).
```

**S13 – Kế hoạch › Hạn mức ngân sách**
```
Screen "Kế hoạch tài chính" with 2 tabs: "Hạn mức ngân sách" and "Mục tiêu tiết kiệm".
Budget tab:
 - Hero card "HẠN MỨC CHI TIÊU HÔM NAY": big safe amount per day, "Còn N ngày", a progress bar
   of the monthly budget, line "Ngân sách tháng: 15.000.000 ₫ · Đã chi 45.000 ₫".
 - Over-limit state: red card "ĐÃ CHI VƯỢT NGÂN SÁCH!" + "Bạn đã tiêu quá hạn mức tháng…"
   and the Mascot alert.
 - Section "NGÂN SÁCH THEO DANH MỤC" with "Thêm": rows with category icon, name, progress
   bar (green <80%, amber 80–100%, red >100%), "Đã chi / Hạn mức", percent.
 - Empty state "Bạn chưa đặt ngân sách tháng này" with CTA "Tạo ngân sách tháng";
   dialog to set monthly limit; dialog to add category limit (category picker + amount).
```

**S14 – Kế hoạch › Mục tiêu tiết kiệm**
```
Savings tab: list of goal cards (name, deadline dd/MM/yyyy, progress ring or bar with percent,
"Đã tiết kiệm 1.000.000 ₫ / 45.000.000 ₫", "Còn 44.000.000 ₫", status chip Đang thực hiện /
Hoàn thành) and button "Nạp tiền" per goal. FAB/CTA "Tạo mục tiêu". Dialogs: create goal
(name, target amount, deadline), top-up (amount, source account). Success snackbar
"Đã nạp 500.000 ₫ vào mục tiêu!". Completed goal shows a calm "Hoàn thành" state – NO confetti
rewards or points. Empty state with CTA.
```

**S15 – Thống kê (Ngày · Tuần · Tháng · Năm)**
```
Screen "Thống kê" (tab Phân tích). Top: segmented control with 4 options – Ngày · Tuần · Tháng ·
Năm – and below it a period switcher "‹ Tuần 06–12/10/2026 ›" (Ngày: "Hôm nay, 10/10/2026";
Tháng: "Tháng 10/2026"; Năm: "2026"). Swiping the chart or tapping the arrows changes period.
Design all four modes as separate frames, same layout:

1) SUMMARY HEADER (changes with the mode): big "Tổng chi" for the selected period, small
   "Tổng thu" and "Chênh lệch" beside it, and a comparison chip vs the previous period
   ("+12% so với tuần trước", or "Chưa có dữ liệu kỳ trước").

2) BAR CHART – the heart of the screen. One bar per unit of the period:
   - Ngày mode: 24 hourly bars (or grouped by morning/noon/evening) for that day.
   - Tuần mode: 7 bars T2…CN.
   - Tháng mode: one bar per day of the month (28–31 bars, scrollable if needed).
   - Năm mode: 12 bars T1…T12.
   Under EVERY bar show its label and, right below it, the amount spent in a compact vi-VN
   form (e.g. "120K", "1,2Tr"); bars with no spending show "–". The highest bar is highlighted
   (Royal Blue), others lighter, the current day/week/month has a small dot; a dashed horizontal
   line marks the daily/monthly safe spending limit when a budget exists (red where exceeded).
   Toggle chips above the chart: "Chi tiêu" (default) · "Thu nhập" · "Cả hai".

3) SELECTED-BAR DETAIL: tapping any bar selects it and shows a card below the chart – e.g.
   "Thứ Tư, 08/10/2026 · Đã chi 310.000 ₫" – with its category split (small stacked bar +
   rows with icon, name, amount, percent) and the list of transactions of that bar
   (category icon, description, time, signed amount). Button "Xem tất cả giao dịch của ngày này"
   opens the Giao dịch list filtered to that day. In the Tuần/Tháng/Năm modes tapping a bar
   lets the user drill down (Năm → tháng, Tháng → ngày, Tuần → ngày).

4) CATEGORY BREAKDOWN for the whole period: donut chart + legend rows (icon, name, amount,
   percent); tapping a slice highlights it and filters the bar chart to that category.

5) ENTRY CARD to the forecast: "Dự báo tài chính cá nhân – xem dự kiến chi cuối tháng" → S16.

Example data for the Tuần frame (6–12/10/2026): T2 120.000 ₫, T3 45.000 ₫, T4 310.000 ₫,
T5 0, T6 85.000 ₫, T7 220.000 ₫, CN 55.000 ₫ → tổng chi 835.000 ₫.
States: loading skeleton, empty ("Chưa có chi tiêu trong kỳ này" with a button "Ghi chép"),
error with "Thử lại", offline stale data badge. Light + dark. Amounts always right-aligned,
tabular digits.
```

**S16 – Dự báo tài chính cá nhân**
```
Screen "Dự báo tài chính" (flagship analytics view). Content:
 - Hero: "Dự kiến chi cuối tháng" big number (projected spend), under it "Đã chi 45.000 ₫ sau
   30/30 ngày" and a confidence chip ("Độ tin cậy: Trung bình", levels Thấp/Trung bình/Cao
   in gray/amber/green).
 - Area/line chart: actual spend (solid line) vs projected path (dashed) across days of the
   month, with the monthly budget as a horizontal threshold line (red dashed) and a marker "Hôm nay".
 - Card "Số dư dự kiến cuối tháng": projected balance, and monthly income reference.
 - AI Smart Insight card (violet): advice text such as "Nếu giữ nhịp chi này, cuối tháng bạn
   còn khoảng 14.955.000 ₫." and, when overspending is projected, a suggestion
   "Giảm khoảng 120.000 ₫/ngày để về mức an toàn." with a button "Đặt ngân sách".
 - Small note: "Dự báo dựa trên N ngày dữ liệu gần nhất".
 States: not enough data ("Cần ít nhất vài ngày giao dịch để dự báo"), loading, error, and the
 Mascot alert variant when projection exceeds the budget.
```

### Nhóm D – Cá nhân

**S17 – Cá nhân & Cài đặt (mở khi chạm icon người dùng ở Trang chủ)**
```
Screen "Cá nhân" is the settings hub, opened by tapping the user icon in the Home header.
Top: user card (initial avatar circle, display name, email) and an editable row "Thu nhập hàng
tháng". Then grouped settings lists (iOS/Android settings style, each row = icon in tinted
square, label, short current-value text on the right, chevron):
 Group "Giao diện"           → "Giao diện & hiển thị"   (value: "Theo hệ thống")      → S23
 Group "Cảnh báo & thông báo"→ "Ngưỡng cảnh báo ngân sách" (value: "80% · 100%")      → S24
                               switch "Thông báo đẩy"
                               switch "Cảnh báo ngân sách (mascot)"
 Group "Dữ liệu"             → "Sao lưu dữ liệu"        (value: "Lần cuối 08/10/2026") → S25
                             → "Nhập dữ liệu từ file"                                  → S26
                             → "Tài khoản & nguồn theo dõi" (accounts, S18)
 Group "Bảo mật & pháp lý"   → Zero-Credential card (read-only info), "Điều khoản sử dụng",
                               "Chính sách bảo mật", "Phiên bản ứng dụng 1.0.0"
 Bottom: red text button "Đăng xuất tài khoản".
Logout confirmation dialog; when there are unsynced transactions the title is "Còn giao dịch
chưa đồng bộ" with buttons "Hủy" and "Vẫn đăng xuất". No points, levels, wardrobe or badges.
```

**S23 – Giao diện & hiển thị**
```
Screen "Giao diện & hiển thị". Sections:
 - "Chế độ màu": 3 selectable preview cards side by side – Sáng, Tối, Theo hệ thống – each a
   mini phone mock showing the Home screen in that mode; selected card has a Royal Blue border
   and check. The whole screen live-previews the choice.
 - "Cỡ chữ": slider with 3 stops (Nhỏ · Vừa · Lớn) and a live sample card ("Tổng số dư
   34.955.000 ₫") that scales.
 - "Hiển thị số tiền": switch "Ẩn số dư trên Trang chủ và widget" (shows "••••••" in the sample),
   segmented control for money format "55.000 ₫" vs "55K" (compact).
 - "Ngôn ngữ": row "Tiếng Việt" (single option, disabled chevron).
Auto-saves; show a small toast "Đã áp dụng".
```

**S24 – Ngưỡng cảnh báo ngân sách**
```
Screen "Ngưỡng cảnh báo". Explains in one line: "FinMate sẽ nhắc bạn bằng mascot khi mức chi
chạm các ngưỡng này." Content:
 - A horizontal budget bar (0–100%+) with two draggable handles: "Sắp chạm ngưỡng" (default 80%,
   amber) and "Đã vượt ngưỡng" (default 100%, red). Zones colored green / amber / red.
 - Under it two stepper inputs for exact values (50–95% for the warning, 100–150% for over).
 - Per-scope list: "Ngân sách tổng tháng" (uses the global values) and each category budget row
   (Ăn uống, …) with a switch "Dùng ngưỡng riêng" revealing its own two values.
 - Switches: "Hiện mascot cảnh báo", "Gửi thông báo đẩy khi chạm ngưỡng", and a time picker
   "Giờ nhắc tổng kết hằng ngày" (optional, default off).
 - Live preview card at the bottom showing the exact mascot banner text for the current values
   (e.g. "Bạn đã dùng 80% ngân sách tháng…").
 - Buttons: primary "Lưu", text "Khôi phục mặc định". Validation: warning must be lower than over.
```

**S25 – Sao lưu dữ liệu**
```
Screen "Sao lưu dữ liệu". Status card: "Lần sao lưu gần nhất: 08/10/2026 14:05", size of the
file, what it contains (checklist chips: Giao dịch, Tài khoản, Danh mục, Ngân sách, Mục tiêu
tiết kiệm, Cài đặt). Primary button "Tạo bản sao lưu" → progress state "Đang tạo file..." →
success state with the file name "finmate-backup-2026-10-10.json", size, and actions "Lưu vào
thiết bị" and "Chia sẻ" (system share sheet). Secondary section "Xuất báo cáo": choose range
(Tháng này / 3 tháng / Tùy chọn) and format segmented (CSV · Excel) → "Xuất giao dịch".
A privacy note: "File sao lưu chứa dữ liệu tài chính của bạn, hãy giữ an toàn." Optional switch
"Đặt mật khẩu cho file sao lưu". Error states: no storage permission, failed, offline.
```

**S26 – Nhập dữ liệu từ file**
```
Wizard "Nhập dữ liệu", 4 steps with a progress indicator:
 1 "Chọn file": drop-zone style card with a file icon, button "Chọn file" (supports FinMate
   backup .json and .csv), list of the supported formats and a link "Tải file CSV mẫu".
 2 "Xem trước": summary of what was found ("128 giao dịch · 3 tài khoản · 9 danh mục"), a
   table preview of the first 5 rows, and for CSV a column-mapping step (dropdowns mapping
   Ngày, Số tiền, Loại, Danh mục, Mô tả, Tài khoản) with auto-detected suggestions.
 3 "Xử lý trùng lặp": warning amber card "Có 6 giao dịch có thể đã tồn tại", choice
   (Bỏ qua trùng · Ghi đè · Nhập tất cả), account selection when the file has none.
 4 "Kết quả": success state ("Đã nhập 122 giao dịch, bỏ qua 6") with "Xem giao dịch", or
   failure list of rows with errors ("Dòng 14: số tiền không hợp lệ") and "Tải danh sách lỗi".
Confirmation dialog before importing ("Hành động này thay đổi số dư của bạn"). Loading, empty
and error states for each step. Money, dates in vi-VN formats.
```

**S18 – Tài khoản & nguồn (nếu tách riêng)**
```
Screen "Tài khoản": list of accounts (type icon Bank/Cash/E-wallet, name, provider, balance,
"Đang theo dõi" toggle). Button "Thêm tài khoản": form with type segmented control
(Tiền mặt / Ngân hàng / Ví điện tử), name, provider picker (for bank/e-wallet), initial
balance. Empty state, error state.
```

### Nhóm E – Chính sách & Widget

**S19 – Điều khoản sử dụng**
```
Screen "Điều khoản sử dụng": app bar with back arrow, a "Cập nhật lần cuối: dd/MM/yyyy" caption,
a table-of-contents row of chips that jump to sections, then readable long-form text with
numbered section headings (1. Giới thiệu, 2. Tài khoản người dùng, 3. Sử dụng trợ lý AI và
giới hạn trách nhiệm (AI không phải tư vấn đầu tư), 4. Dữ liệu tài chính do người dùng nhập,
5. Chấm dứt và xóa tài khoản, 6. Liên hệ hỗ trợ). Body text 16/24, generous line height,
max reading width. Use neutral placeholder paragraphs only (clearly shaded "Nội dung do
đội pháp lý cung cấp") – do not invent real legal clauses. Bottom: contact email row.
States: loading skeleton, error with "Thử lại", offline. Light + dark.
```

**S20 – Chính sách bảo mật**
```
Screen "Chính sách bảo mật" with the same reading layout as S19, plus a top summary card
"Tóm tắt nhanh" with 4 icon rows: "Không bao giờ hỏi mật khẩu hay OTP ngân hàng" (Zero-Credential),
"Dữ liệu giao dịch của bạn được mã hóa", "Micro và camera chỉ dùng khi bạn bấm nói hoặc quét",
"Bạn có thể đăng xuất và xóa dữ liệu trên máy bất cứ lúc nào". Sections: 1. Dữ liệu chúng tôi
thu thập (thông tin tài khoản, giao dịch, thông báo ngân hàng đọc trên máy, ảnh hóa đơn),
2. Quyền truy cập thiết bị (micro, camera, thông báo – mỗi quyền một dòng: lý do + khi nào dùng),
3. Cách dùng dữ liệu cho AI, 4. Lưu trữ và bảo mật, 5. Quyền của bạn, 6. Liên hệ.
Placeholder content only (shaded "Nội dung do đội pháp lý cung cấp").
```

**S21 – Màn hỏi quyền (permission rationale)**
```
Reusable bottom sheet shown BEFORE the system permission dialog, three variants: Micro
("Để bạn nói thay vì gõ"), Camera ("Để quét hóa đơn"), Thông báo ("Để cảnh báo khi sắp vượt
ngân sách"). Each: icon in tinted circle, one-line reason, one line "Bạn có thể thay đổi
trong Cài đặt bất cứ lúc nào", primary "Cho phép", text "Để sau". Plus the "denied" variant
with instructions "Vào Cài đặt > Ứng dụng > FinMate > Quyền".
```

**Điểm vào các trang chính sách (cập nhật các màn trước):**
- S01 Welcome và S03 Đăng ký: câu "Tôi đồng ý Điều khoản & Chính sách bảo mật" có hai liên kết gạch chân mở S19 và S20.
- S17 Cá nhân & Cài đặt: nhóm "Bảo mật & pháp lý" đã có hai dòng "Điều khoản sử dụng" và "Chính sách bảo mật", cùng dòng "Phiên bản ứng dụng 1.0.0".
- S05 bước 1 và các chỗ xin quyền: liên kết nhỏ "Xem Chính sách bảo mật".

**S22 – Widget màn hình chính (ANDROID, thiết kế như bề mặt riêng ngoài app)**
```
Design Android home-screen widgets for FinMate (Material 3 / Glance style, rounded 24 corners,
same color tokens as Part 1; follow system light/dark). Show each on a plain wallpaper mock
for context. Three sizes, each in light and dark:

SMALL 2×2 – "Chi an toàn hôm nay": one big number (e.g. "120.000 ₫") with caption "Chi an toàn
hôm nay", and a circular progress ring around/behind it showing the monthly budget used
(e.g. 85%). Ring color: green < 80%, amber #F59E0B at 80–100%, red #EF4444 over budget
(then the number becomes "Vượt 320.000 ₫" in red). Tap anywhere → opens Trang chủ.

MEDIUM 4×2 – left: "Tổng số dư" with the amount, below it "Đã chi tháng này: 45.000 ₫";
right: the ring from SMALL; bottom row: two pill buttons "Ghi chép" (opens the Ghi chép
sheet) and "Hỏi FinMate" (opens the chat, sparkles icon with the AI gradient outline).

LARGE 4×4 – everything in MEDIUM, plus a "Dự báo cuối tháng" row (projected spend + small
sparkline, confidence chip) and the 3 most recent transactions (category icon, description,
signed colored amount), and a footer row of two round icon buttons: mic (opens chat and starts
listening) and scan (opens chat and the bill-source sheet).

STATES for every size: normal; warning (≥80%, amber); over budget (red); no budget set
("Chưa đặt ngân sách" + "Đặt ngay" button opening Kế hoạch); not signed in ("Đăng nhập để xem",
opens Welcome); loading/stale ("Cập nhật lúc 14:05" caption in secondary text); privacy mode
(balances shown as "••••••" with an eye-off icon; setting stored in the widget config).
Also design the widget configuration screen opened when placing the widget: toggle "Ẩn số dư",
choose size preview, "Hoàn tất". And the widget-picker preview thumbnail for each size.
Do not add features beyond these. No gamification elements. Readable at a glance: one hero
number per widget, minimum 12sp text, 48dp touch targets for buttons.
```

---

## PHẦN 3 – DỮ LIỆU MỖI MÀN HÌNH CẦN (khớp API hiện có)

Quy ước: số tiền là số nguyên VND (backend trả `...Cents` nhưng đơn vị là đồng), hiển thị `55.000 ₫`. Màn nào "mock cho thiết kế" thì chỉ dùng số liệu mẫu bên dưới, đánh dấu rõ là dữ liệu minh hoạ, không đưa vào code production.

| Mã | Màn hình | Dữ liệu cần hiển thị | Nguồn / API | Ghi chú |
|---|---|---|---|---|
| S01 | Welcome | Văn bản tĩnh, checkbox điều khoản | – | Không cần dữ liệu |
| S02 | Đăng nhập | email, mật khẩu; thông điệp lỗi server | `POST /auth/login` | Cờ "hết hạn phiên", "email đã xác thực" là trạng thái cục bộ |
| S03 | Đăng ký | displayName, email, mật khẩu | `POST /auth/register` | – |
| S04 | OTP | email, mã 6 số | `POST /auth/verify-email`, gửi lại: `resend-verification` | Cooldown gửi lại 60s |
| S05 | Thiết lập | Danh sách nhà cung cấp (id, tên, tên hiển thị, gói app); thu nhập hàng tháng | `GET /financial-accounts/providers`, `PATCH /users/me` (`monthlyIncomeCents`), `POST /financial-accounts` | Tạo ví tiền mặt khi hoàn tất |
| S06 | Trang chủ | `displayName`; tổng số dư = tổng `balanceCents` các tài khoản; từng tài khoản (tên, loại, số dư); chi tháng này; 5 giao dịch gần nhất (mô tả, danh mục, `amountCents`, loại Debit/Credit/Transfer, `transactedAt`, `isSynced`); số giao dịch chưa đồng bộ; trạng thái ngưỡng an toàn | `GET /financial-accounts`, `GET /transactions`, `GET /reports/monthly-summary`, hàng đợi offline cục bộ, ngân sách | Mascot alert cần `percentUsed` / `isOverLimit` từ ngân sách |
| S07 | Sheet Ghi chép | Danh mục (id, tên, slug), tài khoản (id, tên, loại) | `GET /categories`, `GET /financial-accounts` | Nút các tab chỉ điều hướng |
| S08 | Chat | Tin nhắn; `action` (saved / summary / reply / confirm); giao dịch đã ghi (amount, category, description, `balanceAfterCents`); tóm tắt (kỳ, tổng chi/thu, còn lại, danh sách danh mục + `share`); bản nháp (số tiền, loại, mô tả, category slug, tài khoản gợi ý, `missingFields`); tài khoản được chọn | `POST /transactions/chat` | Lịch sử chat chỉ lưu trong phiên, xoá khi đăng xuất |
| S09 | (gộp vào S08) Giọng nói trong chat | Chuỗi nhận dạng (từng phần + cuối) hiện trong ô nhập; trạng thái quyền | Nhận dạng trên máy (không có API) rồi gửi như chat | Locale `vi_VN` |
| S10 | (gộp vào S08) Quét bill trong chat | Ảnh gửi vào chat; kết quả: `ocrResult`, số tiền, loại, tên cửa hàng, `transactedAt` (có thể null), `categorySlug`, `confidence`, `scanId` | `POST /transactions/scan-receipt` (multipart `file`) | OCR chạy ở BE (ocr-service) |
| S11 | Xác nhận giao dịch | Bản nháp từ S08/S09/S10 + danh mục + tài khoản; `source` = Manual / Voice / Receipt | `POST /transactions` (hoặc chuyển tiền nội bộ) | Cảnh báo khi `confidence` < 0,85 hoặc thiếu trường |
| S12 | Giao dịch | Danh sách phân trang/nhóm theo ngày: tổng chi/thu mỗi ngày; từng giao dịch (đủ trường); bộ lọc | `GET /transactions` / timeline | Cần huy hiệu "Chưa đồng bộ" |
| S13 | Ngân sách | Ngân sách tổng (`limitCents`, `spentCents`, `remainingCents`, `percentUsed`, `isOverLimit`); ngân sách theo danh mục (cùng trường + tên + slug); mức chi an toàn mỗi ngày (tính ở app = còn lại / số ngày còn); số ngày còn lại | `GET /budgets`, đặt: `POST/PUT /budgets` | – |
| S14 | Mục tiêu tiết kiệm | `name`, `targetCents`, `savedCents`, `remainingCents`, `percentComplete`, `status`, `deadline`, `completedAt` | `GET /saving-goals`, tạo, nạp tiền | Bỏ trường `celebration` (gamification) khỏi UI |
| S15 | Thống kê (ngày/tuần/tháng/năm) | Với mỗi kỳ: tổng chi, tổng thu, chênh lệch, so với kỳ trước; chuỗi theo đơn vị (giờ/ngày/tháng): số tiền chi và thu; khi chạm cột: tổng ngày đó, chia theo danh mục, danh sách giao dịch; breakdown danh mục cả kỳ (`spentCents`, `percent`) | Hiện có: `GET /reports/monthly-summary` và `/reports/category-breakdown` (chỉ `year`+`month`). Ngày/tuần/năm và số tiền theo từng ngày: ghép từ `GET /transactions` (có `fromDate`/`toDate`) hoặc endpoint timeline (đã có fixture `timeline.json`, app chưa dùng, chưa kiểm chứng) | **Chưa có API báo cáo theo ngày/tuần/năm**: tính phía app từ danh sách giao dịch hoặc nhờ BE thêm; cần phân trang đủ cả kỳ |
| S16 | Dự báo | `spentSoFarCents`, `projectedSpendCents`, `daysElapsed`, `daysInMonth`, `basedOnDays`, `confidence` (low/medium/high), `advice.monthlyIncomeCents`, `advice.projectedBalanceCents`, `advice.suggestedDailyCutCents` (có thể null); ngân sách tháng (ngưỡng trên biểu đồ) | `GET /reports/forecast`, `GET /budgets` | **Biểu đồ theo ngày cần chuỗi chi theo ngày** – xem Phần 4 |
| S17 | Cá nhân & Cài đặt | `displayName`, email, `monthlyIncomeCents`, `pushEnabled`, `budgetAlertsEnabled`; giá trị tóm tắt của từng mục cài đặt; số giao dịch chưa đồng bộ | `GET/PATCH /users/me`, lưu cục bộ, hàng đợi cục bộ | `missionRemindersEnabled` còn trong API nhưng thuộc gamification → ẩn |
| S23 | Giao diện & hiển thị | Chế độ màu (sáng/tối/hệ thống), cỡ chữ, cờ ẩn số dư, định dạng tiền | Lưu cục bộ trên máy | Không cần API; cờ ẩn số dư dùng chung với widget Android |
| S24 | Ngưỡng cảnh báo | Ngưỡng "sắp chạm" (mặc định 80%) và "vượt" (100%), ngưỡng riêng theo danh mục, công tắc mascot / thông báo đẩy, giờ nhắc; danh sách ngân sách (`percentUsed`) cho phần xem trước | `GET /budgets`; **lưu giá trị ngưỡng: chưa có trường nào trong API** | Hiện API chỉ có cờ `budgetAlertsEnabled`; cần lưu cục bộ hoặc nhờ BE thêm trường |
| S25 | Sao lưu dữ liệu | Thời điểm sao lưu gần nhất, kích thước file, danh sách nội dung (giao dịch, tài khoản, danh mục, ngân sách, mục tiêu, cài đặt); phạm vi ngày cho xuất báo cáo | Gom từ các API đọc hiện có; **chưa có endpoint export** | Có thể tạo file JSON/CSV ngay trên máy từ dữ liệu đã tải, hoặc nhờ BE thêm export |
| S26 | Nhập dữ liệu | File đã chọn, số bản ghi tìm thấy, ánh xạ cột CSV, danh sách trùng lặp, kết quả (đã nhập / bỏ qua / lỗi theo dòng) | `POST /transactions` từng giao dịch hoặc **endpoint import (chưa có)**; kiểm trùng bằng `clientRequestId` | Nhập số lượng lớn cần BE hỗ trợ để nhanh và an toàn |
| S18 | Tài khoản | Danh sách tài khoản (loại, tên, nhà cung cấp, `isMonitored`, `balanceCents`) | `GET/POST /financial-accounts` | – |
| S19 | Điều khoản sử dụng | Nội dung văn bản + ngày cập nhật | Tĩnh trong app hoặc tải từ URL do bạn cấp | **Nội dung pháp lý do bạn cung cấp** – prompt chỉ dùng placeholder |
| S20 | Chính sách bảo mật | Nội dung văn bản + ngày cập nhật | Như S19 | Cùng ghi chú; phần quyền truy cập khớp quyền thật: micro, camera, thông báo, INTERNET |
| S21 | Màn hỏi quyền | Loại quyền (micro / camera / thông báo), trạng thái hiện tại | Trạng thái quyền hệ thống | Hiện trước hộp thoại hệ thống |
| S22 | Widget Android | Mức chi an toàn hôm nay (= ngân sách tháng còn lại ÷ số ngày còn lại); `percentUsed`, `isOverLimit`; tổng số dư; đã chi tháng này; dự báo (`projectedSpendCents`, `confidence`); 3 giao dịch gần nhất; cờ "Ẩn số dư"; thời điểm cập nhật; trạng thái đăng nhập | `GET /budgets`, `GET /financial-accounts`, `GET /reports/monthly-summary`, `GET /reports/forecast`, `GET /transactions` | Widget không gọi API trực tiếp: app đẩy dữ liệu ra widget định kỳ và khi có giao dịch mới; deep link: Trang chủ, Ghi chép, `/assistant`, `/assistant?start=voice`, `/assistant?start=scan` |
| – | Mascot alert | Mức dùng ngân sách (`percentUsed`), `isOverLimit`, số tiền còn/vượt, mức chi an toàn/ngày | Tính từ `GET /budgets` | Chỉ hiện khi vượt ngưỡng 80% và 100% |

### Dữ liệu mẫu để Stitch điền (minh hoạ, không phải dữ liệu thật)
- Người dùng: "Minh Tuấn". Tài khoản: Vietcombank 30.955.000 ₫, Ví tiền mặt 4.000.000 ₫ → tổng 34.955.000 ₫.
- Giao dịch: "Cafe Highlands" −55.000 ₫ (Ăn uống, 12:12); "Lương tháng 10" +20.000.000 ₫; "Rút tiền" chuyển 1.000.000 ₫.
- Ngân sách tháng 15.000.000 ₫; Ăn uống 6.000.000 ₫ (đã chi 45.000 ₫ = 1%).
- Mục tiêu "Quỹ khẩn cấp" 45.000.000 ₫, đã có 1.000.000 ₫ (2%), hạn 31/12/2026.
- Dự báo: đã chi 45.000 ₫, dự kiến 45.000 ₫, số dư cuối tháng 14.955.000 ₫, độ tin cậy Trung bình.
- Cho trạng thái mascot: ví dụ dùng 85% ngân sách (sắp chạm) và 102% (vượt).

---

## PHẦN 4 – ĐIỂM CẦN BẠN QUYẾT ĐỊNH / ĐIỂM LỆCH VỚI APP HIỆN TẠI

1. **Mascot:** app hiện **không còn mascot** (tôi đã gỡ cùng gamification ở Task 1). Prompt này thiết kế mascot chỉ làm cảnh báo ngưỡng an toàn như bạn nói; phần code cảnh báo cần làm thêm sau khi có thiết kế (cần dữ liệu ngân sách ở S13).
2. **Biểu đồ dự báo theo ngày (S16):** API forecast chỉ trả tổng (`spentSoFar`, `projectedSpend`, số dư dự kiến), **chưa có chuỗi chi theo ngày**. Có thể ghép từ timeline giao dịch (`GET /transactions` nhóm theo ngày, có `totalSpentCents` mỗi ngày). Nếu không muốn ghép phía app, cần BE bổ sung.
3. **Màu:** tôi chọn Style A; nền sáng là mặc định. Hiện app đang ép theme tối, nên dùng bộ này sẽ cần đổi theme (đã nằm trong danh sách việc đợt 3 trước đó).
4. **Màn S18 và chi tiết giao dịch:** app hiện chưa có màn Tài khoản riêng hay bottom sheet chi tiết giao dịch; prompt có đề xuất. Bỏ nếu bạn không muốn mở rộng phạm vi.
4b. **Thống kê (S15):** app hiện chỉ có thống kê theo tháng (Tuần và năm ghi "sắp có"); prompt thiết kế đủ ngày/tuần/tháng/năm kèm số tiền dưới từng cột. API báo cáo chỉ nhận `year`+`month`, nên ngày/tuần/năm phải tính từ danh sách giao dịch hoặc nhờ BE bổ sung.
5. **Cài đặt, sao lưu, nhập (S23–S26):** app hiện chỉ có màn Cá nhân đơn giản (thông tin, Zero-Credential, đăng xuất). Chưa có: đổi giao diện (theme đang ép tối), ngưỡng cảnh báo tùy chỉnh (API chưa lưu giá trị ngưỡng), sao lưu và nhập file. Cần quyết định: làm sao lưu/nhập hoàn toàn trên máy hay thêm endpoint export/import ở BE.
5b. **Widget Android (S22):** app hiện chưa có widget (không có `home_widget` hay mã Android App Widget). Cần cài thư viện (sẽ hỏi bạn trước) và viết phần Android native; dữ liệu cập nhật định kỳ, không theo thời gian thực. Deep link tới chat đã có sẵn trong app.
6. **Trang chính sách (S19, S20):** tôi không viết điều khoản pháp lý thật; bạn cần cung cấp nội dung hoặc URL. Hiện app chỉ có checkbox đồng ý, chưa có hai trang này.
7. **Thanh điều hướng dưới:** hiện chỉ có ở Trang chủ; prompt thiết kế thanh 4 tab cho cả 4 màn chính.

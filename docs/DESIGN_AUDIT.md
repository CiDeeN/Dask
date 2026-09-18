# DESIGN AUDIT — PWA "Nhắc việc chu kỳ" (vòng 3, chuẩn TickTick / Things 3 / Apple Reminders)

Ngày: 2026-09-18 · Phạm vi: `pwa/styles.css`, markup trong `pwa/app.js` · Không đụng logic JS.

## 9 lỗi "thiếu chuyên nghiệp" + nguyên tắc fix

| # | Lỗi cụ thể (file:dòng cũ) | Vì sao thiếu chuyên nghiệp | Nguyên tắc fix (vòng 3) |
|---|---|---|---|
| 1 | Hero cao ~230px, padding 26/30 + 2 bong bóng `::before/::after` + glass `backdrop-filter` (`styles.css:22-35`) | Ăn mất 1/3 viewport mobile, trang trí rẻ tiền, blur tốn GPU, chữ trắng trên gradient teal tương phản không ổn định | Hero gọn ≤180px: padding `12/16`, bỏ bong bóng + bỏ glass; stats thành hàng số + nhãn chia divider, viền trắng 18% |
| 2 | Không có type scale / letter-spacing: hero 20, card title 15.5, sec 15 chen nhau; label `.fl` uppercase nhưng `letter-spacing:.4px` tùy tiện (`styles.css:28,40,54,84`) | Mắt không biết đâu là chính/phụ — kiểu "web demo", không phải app thương mại | Scale cố định: hero 20 / card title 16 / sec 15 / body 14-15 / caption-count 12; heading `ls:-0.01em`, label uppercase `ls:+0.06em`, input 16px chống zoom iOS |
| 3 | `color-mix()` cho badge / progress / donebtn / dhero (`styles.css:55,57,58,61,76`) | Safari <16.2 và nhiều WebView cũ rớt → mất nền badge, chữ trôi trên nền trắng | Bỏ toàn bộ `color-mix`; tính sẵn 4 tint `rgba()` + 4 màu chữ `ink` + 4 dark variant; gắn qua class `.st-ok/.st-warn/.st-due/.st-over` trên card/dhero |
| 4 | Chip filter gộp đếm `"Tất cả · 12"` một chuỗi 600 (`app.js:63`, `styles.css:44`) | Số đếm tranh Aufmerksamkeit với nhãn, khó quét nhanh như TickTick | Tách đếm ra `<span class="chip-n">` mờ hơn, tabular-nums; chip cao ~40px, trạng thái `.on` nền ink đặc |
| 5 | Icon emoji 25px đặt trên gradient màu + `text-shadow` (`app.js:81`, `styles.css:52`) | Emoji trên nền rực khó đọc, loang màu, không giống Things/Reminders (tile trung tính) | Tile 44px nền `var(--uc-soft)` + viền `var(--uc-border)`, emoji 22px không shadow; màu urgency chỉ còn ở spine 4px + dot + progress |
| 6 | Không có safe-area: hero/FAB/main dùng px cứng (`styles.css:22,38,96`) | iPhone notch/home-indicator che FAB, hero dính tai thỏ | `env(safe-area-inset-*)`: hero `padding-top:calc(12px+inset-top)`, main `padding-bottom:calc(120px+inset-bottom)`, FAB `bottom:calc(16px+inset-bottom)` |
| 7 | Tap target fail: `.donebtn` padding 9/14 (~36px), `.bell` 42px, chip ~35px (`styles.css:30,44,61`) | Dưới chuẩn Apple HIG 44×44 → bấm trượt trên di động | `.donebtn{min-height:44px;min-width:72px}`, `.bell{44px}`, chip `padding:10px 16px`; thêm `:active{scale(.97)+darken}` và `:focus-visible` outline cho mọi control |
| 8 | Dark mode tương phản kém: chữ badge dùng đúng màu light (`#E69F00` trên `#17201F` ~2.5:1), muted `#93ABA6` lẫn vào nền (`styles.css:4-15,55,61`) | Vi phạm WCAG AA 4.5:1 cho text nhỏ | Bảng dark riêng: ink badge sáng (`#6FD598/#FFC53D/#FF9E70/#FF8A80` trên card tối ≥4.5:1), muted `#9DB4AF`, hairline đặc `#24312E`, bỏ shadow màu |
| 9 | Thiếu states + form chưa chuẩn mobile: chỉ có `:active{scale}`, không `:focus-visible`/`:disabled`; input 15px padding 13 (cao ~47, zoom iOS), CTA nằm giữa flow (`styles.css:85-89`) | Không dùng được bằng bàn phím, iOS auto-zoom, CTA trôi khỏi tầm tay | Input `min-height:48px;font-size:16px`, label `for=` đúng id, `:focus-visible{outline 2px teal2 offset 2px}`, CTA `position:sticky;bottom:calc(12px+inset-bottom)` |
| 10 | Lưới/template tràn chữ: spacing lẻ (26/18/30/14/10), `.tpl b/small` không truncate, `.ttitle` nowrap nhưng tpl không (`styles.css:38,48,67-72`) | Số lẻ phá lưới 8pt, tên mẫu dài đẩy vỡ 2 cột | Mọi spacing về bội số 8 (8/12→sửa 8/16, radius 12/16/20), `.tpl>div{min-width:0}`, `b/small` ellipsis 1 dòng, tôn trọng `prefers-reduced-motion` |

## Bảng màu urgency (tính sẵn, không `color-mix`)

Light (nền card `#FFFFFF`): chữ ink đậm để đạt ≥4.5:1, dot/spine giữ màu vivid nhận diện.

- ok: base `#2E9E5B` · ink `#1D7242` · soft `rgba(46,158,91,.12)` · border `rgba(46,158,91,.30)`
- warn (upcoming): base `#E69F00` · ink `#7A5800` · soft `rgba(230,159,0,.14)` · border `rgba(183,121,0,.35)`
- due (dueToday/dueGrace): base `#E86A2C` · ink `#B6471A` · soft `rgba(232,106,44,.12)` · border `rgba(232,106,44,.35)`
- over (overdue): base `#D64545` · ink `#B3261E` · soft `rgba(214,69,69,.10)` · border `rgba(214,69,69,.32)`

Dark (nền card `#17211F`): chữ sáng lên để giữ ≥4.5:1.

- ok ink `#6FD598` · soft `rgba(111,213,152,.14)`
- warn ink `#FFC53D` · soft `rgba(255,197,61,.14)`
- due ink `#FF9E70` · soft `rgba(255,158,112,.16)`
- over ink `#FF8A80` · soft `rgba(255,138,128,.14)`
- muted `#9DB4AF`, hairline `#24312E`, CTA teal giữ nguyên (trắng trên `#00695C` ~5.7:1).

## Không đổi (cam kết)

Logic `statusOf/nextDue/markDone/sorted`, CRUD, `localStorage`, router hash, Notification, mọi id (`data-f`, `data-t`, `#add`, `#notif`, `#done`, `#snz`, `#edit`, `#del`, `#f`, `#title`, `#icon`, `#cycle`, `#last`, `#rb`), tên file.

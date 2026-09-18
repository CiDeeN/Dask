# Design Language — Việc Nhà Định Kỳ 🏡

> Ngôn ngữ thiết kế "Nhà Gọn": teal chăm sóc nhà cửa, countdown Xanh/Vàng/Đỏ
> trực quan, card mềm thân thiện. Tiếng Việt, tối giản, Material3.

## 1. Palette (hex)

| Vai trò | Light | Dark | Ghi chú |
|---|---|---|---|
| Primary teal | `#00695C` | `#4DB6AC` (seed sinh) | Brand, header gradient, CTA |
| Secondary mint | `#80CBC4` | `#80CBC4` | Focus border, accent |
| Tertiary warm | `#FF8A65` | `#FF8A65` | Điểm nhấn hiếm (empty state) |
| Background | `#F6F8F7` | `#101414` | Nền app |
| Surface card | `#FFFFFF` | `#1A2120` | Mặt thẻ |
| On-surface | `#17211F` | `#FFFFFF` | Chữ chính |

### Urgency scale (5 mức)

| Mức | Hex | Khi nào |
|---|---|---|
| `urgencyFresh` teal tươi | `#26A69A` | Còn > 5 ngày — thảnh thơi |
| `urgencyOk` xanh | `#2E9E5B` | Còn 3–5 ngày — an toàn |
| `urgencySoon` vàng | `#E69F00` | Còn 1–2 ngày — sắp tới |
| `urgencyUrgent` cam đỏ | `#E86A2C` | Hôm nay / trong grace |
| `urgencyOverdue` đỏ | `#D64545` | Quá hạn |

API cũ giữ nguyên: `AppTheme.okGreen / warnAmber / overRed`,
`urgencyColor(daysLeft)` (3 mức). UI mới dùng `urgencyLevel(daysLeft)`
(5 mức) + `urgencyGradient(color)` cho badge/icon/header.

## 2. Typography scale (Material3)

| Token | Size / Weight | Dùng cho |
|---|---|---|
| displaySmall | 28 / w800, ls −0.5 | Số liệu hero (hiếm) |
| headlineSmall | 22 / w700 | Tiêu đề detail |
| titleLarge | 18 / w700 | Tiêu đề empty state |
| titleMedium | 16 / w600 | Tên TaskCard |
| titleSmall | 14 / w600 | Ngày "lần cuối làm" |
| bodyLarge/Medium | 16/14, h 1.5 | Nội dung, mô tả |
| bodySmall | 12.5, muted | Caption progress, subtitle |
| labelSmall | 11.5 / w700, caps | Nhãn section ("THÔNG TIN CHU KỲ") |

Font: hệ thống (nhẹ, không bundle). Giảm letter-spacing tiêu đề
(−0.1 → −0.5) cho cảm giác hiện đại.

## 3. Spacing / Radius / Elevation

- **Spacing** (`AppSpacing`): xs 4 / sm 8 / md 12 / lg 16 / xl 24 /
  xxl 32 / hero 48.
- **Radius** (`AppRadius`): sm 8 / md 12 / lg 16 / xl 24 / pill 999.
- **Elevation**: gần như flat — card `elevation: 0` + viền hairline
  (`outlineVariant` 60% light / trắng 8% dark). Bóng duy nhất là
  `softShadow()`: teal 10% blur 16, offset (0,6); dark: đen 45%.
- Progress/track bo **pill 999**, dày **8px**, fill dùng gradient urgency
  + glow nhẹ cùng màu.

## 4. Anatomy TaskCard

```
┌ Card 16px, viền hairline ─────────────────┐
│ [icon 48px]  Tên việc (max 2 dòng)  (pill)│
│  gradient       bodyMedium           countdown│
│  urgency  ━━━━━━━━━━●━━━━ 8px pill   │
│            caption 12.5 muted    (done)│
└───────────────────────────────────────────┘
```

1. **Icon badge 48px**: gradient `urgencyGradient(color)`, emoji 24px,
   glow cùng màu urgency (blur 10).
2. **Tiêu đề + countdown pill**: `UrgencyBadge` — chấm tròn 7px +
   text đậm + viền 30% + nền tint 13% (dark 22%). Text đậm hóa qua HSL
   để đủ tương phản WCAG trên nền tint.
3. **Progress 8px** (`TaskProgress`): `FractionallySizedBox` fill gradient,
   caption `Hạn dd/MM • chu kỳ N ngày`.
4. **Nút Done**: `IconButton.filledTonal` check — gọn hơn outline cũ.
5. **Swipe phải**: nền gradient xanh + "Hoàn thành", `confirmDismiss`
   markDone rồi snackBar (không xóa card).

## 5. Dark mode rule

- Không dùng màu cứng cho chữ/nền — luôn qua `ColorScheme` / `TextTheme`.
- Urgency trên nền tối: **sáng hóa (+0.18 lightness)** thay vì đậm hóa,
  nền tint tăng lên 22% + viền 45%.
- Header/hero dùng `headerGradient(dark: true)`: `#00332C → #00695C`
  (trầm hơn light `#00695C → #26A69A`).
- Input fill dark `#222B2A`, viền trắng 12%, focus `secondaryMint`.
- Bóng dark = đen 45% (không dùng teal).

## 6. Onboarding 30s flow (mục tiêu)

```
Mở app → Empty state 🏡 → "Thêm việc mới"
  → Form (tên + icon + chu kỳ mặc định 7 ngày) → Lưu
  → TaskCard đầu tiên hiện countdown xanh + progress
```

- Form chia 2 section đánh số (`01 Thông tin`, `02 Chu kỳ`) + CTA
  full-width 52px + "Hủy bỏ" text.
- Icon mặc định 🧹, chu kỳ mặc định 7 — user chỉ cần gõ tên là xong.
- Detail hero gradient + 2 section card + CTA "Đánh dấu đã xong".

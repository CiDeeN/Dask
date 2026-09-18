# QA Checklist — Recurrence / Notification / Streak

> Phạm vi: task lặp lại (computeNextDue / getStatus / markDone / skip / snooze / đổi cycle).
> Logic chuẩn: `nextDue = lastDone + cycle*86400000`, `effectiveDue = max(nextDue, snoozedUntil)`,
> `diffDays = ceil((effectiveDue-now)/86400000)`, markDone early/late/done + reset `now+cycle`.
> File verify: `python test_verify_recurrence.py` + `flutter test test/recurrence_test.dart`.

## 1. Reboot máy — notification có mất không?
- [ ] Android: tạo 3 task due trong 10–30 phút tới → reboot → mở app sau reboot → task vẫn đúng `getStatus`, noti vẫn nổ đúng giờ (đã reschedule qua BOOT_COMPLETED / WorkManager / exact alarm).
- [ ] iOS: tương tự (ghi chú: iOS giới hạn ≤64 pending noti/request) → reboot → kiểm tra pending notifications còn đủ.
- [ ] Kill app (swipe away) rồi reboot → noti vẫn còn (không lưu in-memory).
- [ ] Ghi lại: số noti trước/sau reboot, có thiếu cái nào không.

## 2. Revoke quyền notification
- [ ] Tạo task due → vào Settings OS tắt quyền noti → quay lại app → banner/empty-state hướng dẫn bật lại (không crash, không báo "đã đặt noti" sai).
- [ ] Bật lại quyền → app tự re-register pending noti (không cần tạo lại task).
- [ ] Android 13+: test flow `POST_NOTIFICATIONS` runtime permission lần đầu (allow/deny/deny+don't ask again).

## 3. Đổi múi giờ HN (UTC+7) ↔ Tokyo (UTC+9)
- [ ] Logic lưu **UTC ms** (không lưu giờ local). Test: task due 08:00 01/03 HN → đổi máy sang Tokyo → due hiển thị 10:00 JST cùng thời điểm UTC (status không đổi đột ngột).
- [ ] Bay HN→Tokyo: task `due_today` không nhảy thành `overdue`/`upcoming` chỉ vì lệch +2h (diffDays dùng ceil theo UTC ms).
- [ ] Task tạo lúc 23:30 HN (cycle 1 ngày): sang Tokyo vẫn due đúng +24h ms, không "mất 1 ngày".
- [ ] DST/travel edge: log `now`, `nextDue`, `effectiveDue` (UTC ISO) khi đổi múi giờ để đối chiếu.

## 4. Đổi giờ hệ thống để cheat streak
- [ ] Tắt mạng → chỉnh giờ máy +2 ngày → mở app → `markDone` có bị tính `done`/`late` giả không? Kỳ vọng: phát hiện clock skew (so với lastDone/server time hoặc elapsedRealtime) → chặn hoặc cảnh báo, không cộng streak.
- [ ] Chỉnh giờ lùi về quá khứ → `computeNextDue`/`getStatus` không kẹt `overdue` vĩnh viễn, không cho farm `early` → `done`.
- [ ] Bật lại giờ tự động + mạng → streak tự hồi về đúng, `nextDue` recompute từ `lastDone` thật.
- [ ] Ghi lại: chính sách chống cheat (monotonic clock / server timestamp / grace 1 ngày cho late).

## 5. 50 task cùng lúc — có gộp notification không?
- [ ] Tạo 50 task cùng `nextDue` (1 phút tới) → kỳ vọng: **gộp thành 1 summary noti** (InboxStyle / group summary Android, threadIdentifier iOS), không spam 50 noti rời.
- [ ] Mở 1 task từ noti gộp → deep-link đúng task (không mở nhầm).
- [ ] `markDone` 1 task trong cụm gộp → cụm cập nhật số lượng, không bắn lại full 50.
- [ ] Đo: thời gian schedule 50 task < 2s, không ANR/jank, không trùng ID noti.

## 6. Xóa app cài lại — export/import JSON
- [ ] Export JSON (gồm `lastDone`, `nextDue`, `cycle`, `snoozedUntil`, timezone) → xóa app → cài lại → import → mọi task về đúng `getStatus` như trước.
- [ ] Import file JSON hỏng/thiếu field → báo lỗi rõ ràng, không crash, không ghi đè data hiện tại.
- [ ] Import JSON từ múi giờ khác (Tokyo) sang máy HN → due quy về UTC đúng.
- [ ] Round-trip: export → import → export → diff 2 file export phải giống nhau (trừ `exportedAt`).

## 7. Offline 7 ngày
- [ ] Tắt mạng 7 ngày, vẫn mở app mỗi ngày offline → `markDone`/`skip`/`snooze` queue local, `getStatus` chạy local đúng (overdue → done → nextDue mới).
- [ ] Mở lại mạng ngày 8 → sync 1 lần, không mất log, không duplicate task, `nextDue` server == local.
- [ ] Noti offline vẫn nổ (local schedule, không phụ thuộc push server).
- [ ] Kiểm tra pin/battery-optimization (Android Doze) không giết lịch 7 ngày.

## 8. Case bổ sung từ test tự động (đối chiếu)
- [ ] done sớm (`early`): now < nextDue − 1d → reset `now+cycle`.
- [ ] đúng hạn (`done`): now ∈ [nextDue−1d, nextDue].
- [ ] trễ (`late`): now > nextDue → reset `now+cycle`.
- [ ] skip giữ nhịp (`nextDue+cycle`), snooze đẩy `effectiveDue`, đổi cycle recompute từ `lastDone`.
- [ ] Feb29 (2024-02-29 +1d = 01/03; +365d = 28/02/2025), cycle 1 ngày (grace) vs 180 ngày (ok).

---
**Cách đánh dấu:** tick checkbox + ghi build/version, thiết bị, múi giờ, kết quả PASS/FAIL và log UTC (`now/nextDue/effectiveDue`) cho mỗi mục FAIL.

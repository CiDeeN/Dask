# PWA — Nhắc việc chu kỳ

Bản web cài được (Installable PWA), dùng chung logic `recurrence` + 15 template với bản Flutter (`lib/`).

## Chạy local (không cần Node/Flutter)

```bat
cd C:\Users\namcd\Projects\MobileApp\pwa
python -m http.server 8080
```

Mở `http://localhost:8080` → DevTools → Application → Manifest/Service Worker để kiểm tra cài đặt.
Dùng `http://127.0.0.1:8080` nếu `localhost` bị chặn.

## Tính năng

- Home countdown sort gấp nhất, filter Tất cả/Quá hạn/Sắp tới/An toàn, progress `còn X/Y ngày`.
- Thêm/sửa/xóa, Done 1 chạm reset chu kỳ, hoãn 1 ngày, mẫu 1 chạm (15 template VN).
- Lưu `localStorage` (`habit_pwa_v1`), seed 3 việc đầu để aha-moment 30s.
- Nhắc việc: Notification API khi mở app (quá hạn/đến hạn, tối đa 3 cái) + service worker cache-first offline.

## Logic (canonical, giống `recurrence.dart`)

- `nextDue = lastDone + cycle*86400000`, `diff = floor((eff-now)/86400000)`, `eff = snoozedUntil còn hiệu lực ? snoozedUntil : nextDue`.
- `diff < -grace → overdue`, `diff < 0 → dueGrace`, `== 0 → dueToday`, `<= remindBefore → upcoming`, còn lại `ok`.
- `markDone`: early (`now < nextDue-1d`), late (`now > nextDue`), else done; reset từ `now`.

# PWA — Nhắc việc chu kỳ

Bản web cài được (Installable PWA), dùng chung logic `recurrence` + 15 template với bản Flutter (`lib/`).

> Định hướng: app này khác TickTick về mục đích — TickTick quản lý task/deadline,
> app này là **bộ nhớ ngoài cho việc nhà định kỳ** (reset chu kỳ theo lần cuối làm,
> countdown `còn X/Y ngày`, template VN). Chỉ mượn **phong cách thị giác** của
> TickTick (hàng phẳng, checkbox tròn, nhóm theo thời gian, tab bar đáy), không
> copy khái niệm của nó (priority/flag, project, pomodoro...).

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

## Thông báo đẩy nền (Web Push)

App mở vẫn nhắc foreground như cũ. Để nhận push lúc **7h sáng kể cả khi tắt app**:

1. Vercel dashboard → Storage → Create **KV** (free) → Connect vào project (tự sinh `KV_REST_API_URL/TOKEN`).
2. Settings → Environment Variables, thêm:
   - `VAPID_PUBLIC_KEY` = public key trong `pwa/app.js` (`VAPID_PUBLIC`)
   - `VAPID_PRIVATE_KEY` = **private key do dev giao riêng, KHÔNG commit**
   - `VAPID_SUBJECT` = `https://dask-kappa.vercel.app/` (hoặc `mailto:bạn`)
   - `CRON_SECRET` = chuỗi ngẫu nhiên (khuyên dùng, để khóa `/api/cron`)
3. Deploy lại. Vercel tự chạy cron `0 0 * * *` (7h VN) gọi `/api/cron`.
4. Trên điện thoại: mở app → bấm chuông 🔔 → Allow → thấy báo "đã bật nhắc lúc 7h sáng".
5. Kiểm tra: DevTools → Application → Service Workers + Push; gọi thử `GET /api/cron` với header `Authorization: Bearer <CRON_SECRET>` để test (trả `{ok, checked, sent, cleaned}`).

Cơ chế: bấm chuông → trình duyệt tạo push subscription → app POST sub + copy task lên `/api/subscribe` (KV, TTL 90 ngày, tự đồng bộ lại mỗi lần mở app/sửa task) → cron quét và gửi 1 push tóm tắt/ngày.

## Tài khoản — mỗi người 1 danh sách riêng

- Nút 👤 trên topbar → màn hình Tài khoản: **Đăng ký / Đăng nhập** (tên 2–30 ký tự, mật khẩu ≥ 6, hash scrypt, phiên 180 ngày, chống dò 20 lần/10 phút).
- List lưu theo user trên server (`/api/sync` GET/PUT, last-writer-wins theo `savedAt`), tự hội tụ đa máy: mở máy khác + đăng nhập là có đúng list của mình. Đăng xuất xóa list khỏi máy (server giữ).
- Chuông 🔔 yêu cầu đăng nhập trước để push gắn đúng user; cron gửi push theo list của từng user tới mọi máy đã đăng ký.

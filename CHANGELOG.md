# Changelog — Nhắc việc chu kỳ

## [0.5.0] - 2026-09-19 — Tài khoản theo user
### Added
- `api/auth.js` + `api/_auth.js`: đăng ký/đăng nhập (scrypt, session 180 ngày, chống dò mật khẩu).
- `api/sync.js`: list theo user, đồng bộ đa máy (last-writer-wins theo `savedAt`).
- `api/subscribe.js`/`cron.js`: gắn subscription và gửi push theo từng user.
- PWA: nút 👤 + màn hình Tài khoản, chuông yêu cầu đăng nhập, seed demo không lấn bản server.
### Verified
- Logic lõi 18/18 PASS, PWA serve 200 local. Auth/push cần Vercel env + KV thật để test end-to-end.

## [0.4.0] - 2026-09-18 — Web Push (đẩy nền 7h sáng)
### Added
- `api/subscribe.js` + `api/_kv.js`: nhận push subscription + copy task vào Vercel KV (TTL 90 ngày).
- `api/cron.js`: Vercel Cron `0 0 * * *` quét hạn (logic floor giống app) và gửi 1 push tóm tắt/ngày qua `web-push`; tự dọn sub hết hạn/bị thu hồi.
- PWA: `sw.js` nghe sự kiện `push`, `app.js` đăng ký PushManager (VAPID) + tự đồng bộ task lên backend.
- `package.json` (`web-push`), `vercel.json` thêm `crons`. Hướng dẫn setup KV + env trong `pwa/README.md`.
### Verified
- Logic lõi 18/18 PASS, PWA serve 200 local. Push end-to-end cần Vercel env + KV thật để test.

## [0.3.0] - 2026-09-18 — PWA
### Added
- `pwa/` bản web cài được: `index.html`, `styles.css` (design Nhà Gọn), `app.js` (port recurrence floor + CRUD localStorage + hash router + Notification API), `manifest.webmanifest`, `sw.js` (cache-first), `icon.svg`, `README.md`.
- Seed 3 việc đầu, 15 template VN 1 chạm, seed aha-moment 30s.
### Verified
- Manifest JSON hợp lệ (2 icons), `http.server` serve `index.html` 200, logic lõi 18/18 PASS.

## [0.2.0] - 2026-09-18 — Designer + Tích hợp
### Added
- Design system "Nhà Gọn" (`AppTheme`): palette teal #00695C, urgency 5 mức, `AppSpacing`/`AppRadius`, gradient + soft shadow, dark mode (docs/DESIGN.md).
- Widgets mới: `urgency_badge.dart`, `task_progress.dart`; làm lại `home/detail/form` (header gradient, TaskCard pill, CTA full-width).
- 15 template VN (`builtin_templates.dart`), router go_router (`/`, `/detail/:id`, `/form`).
### Changed
- `lib/main.dart`: bỏ `_PlaceholderHome`, dùng `MaterialApp.router` + `AppTheme.light/dark` + `AppRouter.router`.
- Chuẩn logic: `recurrence.dart` (floor + grace/remindBefore) là canonical cho UI.
### Verified
- `python test_verify_recurrence.py`: 18/18 PASS. Tổng 23 file.

## [0.1.0] - 2026-09-18 — Scaffold MVP (4 agents)
- Dev1: pubspec, Drift schema (tasks/task_logs), models, recurrence engine.
- Dev2: theme M3, router, notification_service, providers, home/detail/form.
- Tester: `recurrence_test.dart`, `test_verify_recurrence.py`, QA checklist, metrics.
- Reviewer: `docs/REVIEW.md` (5 issue P0).

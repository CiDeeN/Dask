# Nhắc việc chu kỳ — Flutter MVP + PWA

App nhắc việc định kỳ: thay bàn chải 90 ngày, dọn toilet 7 ngày...

> Hướng phát triển: **PWA** — thư mục `pwa/` là bản web cài được (manifest + service worker + localStorage),
> dùng chung logic `recurrence` và 15 template VN với bản Flutter (`lib/`). Xem `pwa/README.md` và `CHANGELOG.md`.

## Vai trò Dev1 (Backend/Data) — đã scaffold

- `pubspec.yaml` — Flutter 3.x + riverpod, drift, go_router, flutter_local_notifications, workmanager, timezone, intl, uuid
- `lib/main.dart` — bootstrap tối giản, gọi `HabitApp`
- `lib/src/core/database/app_db.dart` — Drift tables: categories, tasks, task_logs
- `lib/src/features/habits/data/models.dart` — Task, TaskLog, TaskStatus + fromJson/toJson
- `lib/src/features/reminders/recurrence.dart` — `computeNextDue`, `getStatus`, `markDone` thuần Dart

## Cài Flutter (Windows, 1 lần)

1. Tải Flutter SDK 3.x: https://docs.flutter.dev/get-started/install/windows
2. Giải nén, thêm `flutter\bin` vào PATH.
3. Kiểm tra:
   ```bat
   flutter doctor
   flutter --version
   ```

## Chạy MVP

```bat
cd C:\Users\namcd\Projects\MobileApp
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## Logic chu kỳ (recurrence.dart)

- `computeNextDue(lastDoneMs, cycleDays) = lastDoneMs + cycleDays * 86400000`
- `getStatus(task, now)`: overdue (`diffDays < -grace`), due_grace, due_today, upcoming (`diffDays <= remindBefore`), else ok + text tiếng Việt.
- `markDone`: early (`now < nextDue - 1 ngày`), late (`now > nextDue`), else done; reset `nextDue = now + cycle`, xóa `snoozedUntil`.

## Seed mẫu

- Thay bàn chải — 90 ngày
- Dọn toilet — 7 ngày

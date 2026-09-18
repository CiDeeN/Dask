# CODE REVIEW — App Nhắc Việc Chu Kỳ (Flutter + Riverpod + Drift + go_router + flutter_local_notifications)

> Vai trò: Agent Reviewer — CHỈ ĐỌC, KHÔNG SỬA code Dev1/Dev2. File sở hữu duy nhất: `docs/REVIEW.md`.
> Trạng thái repo tại thời điểm review (2026-09-18): repo trống (chỉ có `.git/` + `docs/`), chưa có `pubspec.yaml`, `lib/**/*.dart`. Báo cáo dưới đây là **review tiêu chuẩn / pre-review** dựa trên spec stack, để Dev1+Dev2 đối chiếu ngay khi push code. Khi có code thật, map từng mục sang `file:line` thực tế.

Cấu trúc chuẩn giả định để review:
```
lib/src/app/router.dart
lib/src/features/reminders/presentation/*_screen.dart
lib/src/features/reminders/application/*_provider.dart (Riverpod)
lib/src/features/reminders/data/reminder_repository.dart
lib/src/features/reminders/data/reminder_dao.dart / app_database.dart (Drift)
lib/src/features/reminders/recurrence.dart (computeNextDue)
lib/src/core/notifications/notification_service.dart
lib/src/core/time/clock.dart + timezone init
pubspec.yaml
android/app/src/main/AndroidManifest.xml + MainActivity
ios/Runner/Info.plist + AppDelegate.swift
```

---

## 1. Checklist Clean Architecture: Screen -> Provider -> Repo -> DAO

- [ ] **Dependency direction 1 chiều:** `Screen -> Provider (Riverpod Notifier/AsyncNotifier) -> Repository (interface) -> DAO (Drift)` — Không có `import` ngược (DAO import Provider, Screen import DAO trực tiếp).
- [ ] **Repository che Drift:** Screen/Provider chỉ thấy `Reminder` entity + `Failure/Either`, không thấy `AppDatabase`, `Table`, `Companion`, `Query`.
- [ ] **Provider mỏng:** Provider chỉ orchestrate `watch/read repository + notification_service`, không chứa SQL, không chứa `DateTime.now()` trực tiếp (inject `Clock`), không chứa logic recurrence phức tạp (đẩy sang `recurrence.dart` pure + unit test).
- [ ] **DAO mỏng:** DAO chỉ CRUD + query typed của Drift, không gọi `flutter_local_notifications`, không navigate (`go_router` chỉ ở presentation/router).
- [ ] **go_router tách riêng:** `lib/src/app/router.dart` khai báo `GoRouter` via `riverpod`; Screen nhận `id` qua `pathParam`, tự `ref.watch(reminderByIdProvider(id))` — không truyền object mutable qua `extra` rồi mutate.
- [ ] **State handling:** `AsyncValue.when(data/loading/error)` đầy đủ, không `!` sau `valueOrNull`, không `FutureBuilder` lồng `ref.watch`.

## 2. Null-safety / Dart

- [ ] Không dùng `!` trừ khi đã `assert`/early-return ngay dòng trên. Cấm `lat!`, `payload!`, `snapshot.data!`.
- [ ] Model Drift nullable đúng: `dueAt DateTime?` vs `nextDueAt DateTime NOT NULL`, `recurrenceRule TEXT NULL`. Companion dùng `Value.absent()` không phải `Value(null)` bừa.
- [ ] JSON/payload notification `try/catch + fallback`, không `jsonDecode(payload!)['id'] as int` trực tiếp.
- [ ] `DateTime` phân biệt `isUtc`: DB lưu UTC, UI hiển thị local. Cấm `.toLocal()` 2 lần / so sánh UTC vs local lẫn lộn.
- [ ] Riverpod: dùng `ref.watch` trong `build`, `ref.read` trong callback; `autoDispose` cho detail/edit; `keepAlive` có lý do cho list/stream.

## 3. Drift — SQL injection / Migration

- [ ] **Không SQL raw nối chuỗi:** cấm `customSelect("SELECT * WHERE title = '"+input+"'")`. Bắt buộc dùng `where((t) => t.title.equals(name))` hoặc `customSelect(..., variables: [Variable.withString(input)])`.
- [ ] **Migration có version + test:** `schemaVersion` tăng mỗi lần sửa table; viết `onUpgrade: from 1 to 2 addColumn`, `migrationTests`/`schema dump`. Cấm `delete db + recreate` trên production, cấm `DROP TABLE` mất dữ liệu.
- [ ] **Transaction cho write kép:** tạo reminder + schedule notification phải trong `transaction(() async {...})` hoặc compensate (rollback unschedule nếu insert fail).
- [ ] **Index + paged query:** `CREATE INDEX ON reminders(next_due_at)`, query list dùng `limit/offset` hoặc `watch` có `orderBy + limit`, không `select(all).get()` rồi `sort` in-memory.
- [ ] **Type converter explicit:** `RecurrenceRule` enum <-> `String/Int` qua `TypeConverter`, không lưu `toString()` thô rồi `parse` bằng `split` dễ vỡ.

## 4. Notifications — Permission / Exact Alarm / iOS limit

- [ ] **Android 13+ (API 33) `POST_NOTIFICATIONS` runtime:** `requestPermission` trước `schedule`, xử lý `deniedPermanently -> openAppSettings`. Không schedule câm khi chưa có quyền.
- [ ] **Android 12+ (API 31) `SCHEDULE_EXACT_ALARM`:** dùng `zonedSchedule(..., androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle)` chỉ khi đã `canScheduleExactAlarms() == true`; nếu false -> fallback `inexact` + banner trong app giải thích + deep-link `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`. Cấm `exact` mà không check (ném `SecurityException` / im lặng).
- [ ] **AndroidManifest khai báo đủ:** `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` (nếu đủ điều kiện Play policy), `RECEIVE_BOOT_COMPLETED` + `BootReceiver` reschedule sau reboot. Kênh `NotificationChannel (importance: max)` tạo 1 lần.
- [ ] **iOS 64 pending limit:** `getPendingNotificationRequests().length + newCount <= 64`. App chu kỳ vô hạn phải chỉ schedule N kỳ tới (vd 10–20), reschedule khi user mở app / khi 1 notification fire (dùng `onDidReceive...` + background fetch). Không `for (i=0;i<1000;i++) schedule`.
- [ ] **Timezone init đúng:** `tz.initializeTimeZones(); tz.setLocalLocation(getLocation(localName))` trước mọi `zonedSchedule`; dùng `tz.TZDateTime.from(dueUtc, tz.local)`, xử lý DST (giờ 2:30 ngày chuyển DST -> dời lên 3:00, không crash).
- [ ] **ID ổn định + idempotent:** notification `id = reminderId.hashCode ^ occurrenceIndex` (int32), `cancel(id)` trước `schedule(id)` khi edit/delete; payload là JSON `{"reminderId":x,"occurrence":"ISO8601"}` có version.

## 5. Performance list 50+ item

- [ ] `ListView.builder` + `const` item, không `Column + SingleChildScrollView` cho list dài, không `ListView(children: [...])` build hết 1 lần.
- [ ] Drift `watchReminders(limit, offset)` + pagination (`infinite_scroll` / `limit 50`), `select` chỉ cột cần thiết, có `index(next_due_at)`.
- [ ] `Provider.select` để item không rebuild cả list khi 1 checkbox đổi; `Equatable/freezed` cho entity; ảnh/icon cache.
- [ ] Không `zonedSchedule` / `computeNextDue` trong `itemBuilder` (O(n) schedule mỗi frame) — precompute ở Repo/Isolate, cache `nextDueAt` trong DB.
- [ ] Profile: `flutter build apk --release`, test với 200 item seed, check jank (`PerformanceOverlay`), DB query time (`EXPLAIN QUERY PLAN`).

## 6. Race condition khi 2 Dev cùng sửa

- [ ] **Git:** 2 dev chạm `pubspec.yaml`, `router.dart`, `app_database.dart` dễ conflict. Quy ước: Dev1 sở hữu `presentation+router`, Dev2 sở hữu `data+notifications`; merge qua PR + `dart format + flutter analyze` bắt buộc.
- [ ] **Drift concurrent write:** 2 isolate/tab cùng `update nextDueAt` -> dùng `transaction` + `optimistic lock (updatedAt/version column)`; UI dùng `ref.invalidate` sau write, không giữ stale `AsyncValue`.
- [ ] **Notification double-schedule:** edit nhanh 2 lần / tap Save 2 lần -> debounce Save button (`isLoading` disable), `cancel+schedule` nguyên tử trong cùng async block, dùng cùng `id` ổn định.
- [ ] **Timezone/clock race:** `initializeTimeZones()` gọi 1 lần ở `main()` trước `runApp`, không gọi lazy trong từng schedule (race init chưa xong -> schedule sai giờ).

---

## 7. Top Issues (P0) — Đối chiếu ngay khi có code

### [P0-1] `lib/src/features/reminders/recurrence.dart:computeNextDue()` — tràn số + sai timezone/DST
**Dấu hiệu:** `due.add(Duration(days: 30*count))`, `DateTime.now()` trong pure function, so sánh `isBefore(DateTime.now())` lẫn UTC/local.
**Rủi ro:** reminder hàng tháng lệch ngày (31/1 -> 2/3), vòng lặp `while (next.isBefore(now)) next += interval` treo khi interval = 0/âm, DST làm fire sớm/muộn 1h, tràn `int` khi `repeatCount * intervalMs` lớn.
**Fix:**
```dart
// trước (sai):
DateTime computeNextDue(DateTime due, int intervalDays) {
  var n = due; while (n.isBefore(DateTime.now())) n = n.add(Duration(days: intervalDays)); return n;
}
// sau (đúng):
DateTime computeNextDue({required DateTime dueUtc, required Recurrence r, required DateTime nowUtc, int maxIter = 1000}) {
  assert(!dueUtc.isBefore(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
  if (r.interval <= 0) throw ArgumentError('interval>0');
  var n = dueUtc; var i = 0;
  while (n.isBefore(nowUtc) && i++ < maxIter) { n = r.addTo(n); } // addTo xử lý month-end + tz
  return n.toUtc();
}
```
Inject `Clock.nowUtc()`, test month-end (31/1 monthly -> 28/2), DST (tz America/New_York 2026-03-08), interval 0/âm, maxIter guard.

### [P0-2] `lib/src/core/notifications/notification_service.dart:schedule()` — thiếu quyền + exact alarm Android 12+/13+
**Dấu hiệu:** gọi thẳng `zonedSchedule(...)` không check `requestPermission` / `canScheduleExactAlarms`, không `initializeTimeZones`.
**Rủi ro:** Android 13 không hiện gì; Android 12+ crash/im lặng exact; sau reboot mất hết lịch; iOS vượt 64 pending bị drop không báo.
**Fix (file:line `notification_service.dart:40-90`):**
```dart
await tzInitOnce();
if (Platform.isAndroid) {
  final p = await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
  final notifGranted = await p.requestNotificationsPermission() ?? false;
  if (!notifGranted) { state.showPermissionBanner(); return; }
  final exactOk = await p.canScheduleExactNotifications() ?? false;
  final mode = exactOk ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  // + hướng dẫn mở Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM khi !exactOk
}
final pending = await plugin.pendingNotificationRequests();
assert(pending.length < 64, 'iOS limit');
await plugin.zonedSchedule(id, title, body, tz.TZDateTime.from(nextUtc, tz.local),
  details, androidScheduleMode: mode, uiLocalNotificationDateInterpretation: null, matchDateTimeComponents: ...);
```
+ `AndroidManifest.xml: uses-permission SCHEDULE_EXACT_ALARM, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED` và `BootReceiver` reschedule.

### [P0-3] `lib/src/features/reminders/data/app_database.dart:migration` + `reminder_dao.dart:customSelect` — mất dữ liệu / SQL injection
**Dấu hiệu:** `schemaVersion = 1` mãi dù đã thêm cột `recurrenceRule`; `customSelect('... title = $q ...')`; `onUpgrade` rỗng.
**Rủi ro:** user update app mất DB / crash `column not found`; search title chứa `'; DROP TABLE--` gây injection nếu dùng raw.
**Fix (`app_database.dart:12-30`, `reminder_dao.dart:50-70`):**
```dart
@override int get schemaVersion => 2;
@override MigrationStrategy get migration => MigrationStrategy(onUpgrade: (m, from, to) async {
  if (from < 2) await m.addColumn(reminders, reminders.recurrenceRule);
});
// DAO:
Future<List<ReminderRow>> search(String q) =>
  (select(reminders)..where((t) => t.title.contains(q))).get(); // drift escape sẵn
// nếu bắt buộc raw:
customSelect('SELECT * FROM reminders WHERE title LIKE ?', variables: [Variable.withString('%$q%')]);
```
Thêm `test/migration_test.dart` + `EXPLAIN QUERY PLAN` cho query sort theo `next_due_at`.

### [P0-4] `lib/src/features/reminders/presentation/reminder_list_screen.dart:itemBuilder` + `application/reminder_list_provider.dart` — jank + rebuild cả list với 50+ item
**Dấu hiệu:** `ListView(children: reminders.map(...).toList())`, `ref.watch(listProvider)` ở cả list + từng row, `computeNextDue`/`zonedSchedule` trong `build`.
**Rủi ro:** 50–200 item lag, scroll jank, schedule trùng mỗi frame, pin tăng.
**Fix (`reminder_list_screen.dart:60-120`):**
```dart
ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
  final id = list[i].id;
  return ProviderScope(child: ReminderTile(id: id)); // tile tự ref.watch(itemProvider(id).select((v)=>v.status))
});
// provider paged:
final pagedProvider = StateNotifierProvider<...>; // limit 50, fetchMore on scroll end
```
Precompute `nextDueAt` ở Repo (background), DB có index, Screen chỉ render.

### [P0-5] `lib/src/features/reminders/data/reminder_repository.dart:save()` + `lib/src/app/router.dart` — race 2 dev / double-submit / navigate với object stale
**Dấu hiệu:** `save()` không transaction, không debounce, `goNamed('detail', extra: reminder)` rồi mutate object; 2 dev cùng sửa `router.dart`/`pubspec.yaml` conflict.
**Rủi ro:** tap Save 2 lần tạo 2 reminder + 2 alarm; edit đồng thời ghi đè nhau; `extra` stale sau update.
**Fix (`reminder_repository.dart:20-60`, `router.dart:15-40`):**
```dart
Future<void> saveReminder(Reminder r) async {
  if (_saving) return; _saving = true; try {
    await db.transaction(() async { final id = await dao.upsert(r); await notifications.cancelFor(id); await notifications.scheduleNext(id); });
    ref.invalidate(reminderListProvider);
  } finally { _saving = false; }
}
// router: chỉ truyền id
GoRoute(path: '/r/:id', builder: (_, s) => DetailScreen(id: int.parse(s.pathParameters['id']!)));
```
Git: `CODEOWNERS` (Dev1: `presentation/** + router.dart`, Dev2: `data/** + notifications/**`), PR squash, `flutter analyze --fatal-infos` ở CI.

---

## 8. Lệnh verify nhanh (chạy trước khi merge)
```
flutter analyze --fatal-infos
dart format --set-exit-if-changed lib test
flutter test test/recurrence_test.dart test/migration_test.dart
flutter test --coverage
adb shell dumpsys alarm | grep <package>   # kiểm tra exact alarm Android
xcrun simctl push <udid> <bundle> payload.json  # kiểm tra iOS (đếm pending <=64)
flutter build apk --release --dart-define=ENV=prod
```

*Reviewer không sửa code — mọi fix trên là gợi ý theo `file:line` để Dev1/Dev2 tự áp dụng.*

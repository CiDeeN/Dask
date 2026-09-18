// Drift database: categories / tasks / task_logs.
// Chạy gen code: flutter pub run build_runner build --delete-conflicting-outputs

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'app_db.g.dart';

/// Nhóm việc, vd: Vệ sinh, Sức khỏe.
class Categories extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text()(); // tên nhóm
  TextColumn get icon => text().nullable()(); // emoji/icon
  IntColumn get createdAt => integer()(); // epoch ms

  @override
  Set<Column> get primaryKey => {id};
}

/// Việc định kỳ, vd: thay bàn chải 90 ngày, dọn toilet 7 ngày.
class Tasks extends Table {
  TextColumn get id => text()(); // uuid PK
  TextColumn get title => text()(); // tên việc
  TextColumn get icon => text().withDefault(const Constant('🔔'))(); // emoji
  // FK mềm sang categories, xóa category thì set null.
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  IntColumn get cycleDays => integer().check(cycleDays.isBiggerOrEqualValue(1))(); // >= 1
  IntColumn get lastDoneAt => integer().nullable()(); // epoch ms
  IntColumn get nextDueAt => integer()(); // epoch ms NOT NULL
  IntColumn get gracePeriodDays => integer().withDefault(const Constant(0))(); // ngày gia hạn
  IntColumn get remindBeforeDays => integer().withDefault(const Constant(1))(); // nhắc trước X ngày
  IntColumn get snoozedUntil => integer().nullable()(); // epoch ms
  BoolColumn get isActive => boolean().withDefault(const Constant(true))(); // 1 = bật
  IntColumn get createdAt => integer()(); // epoch ms
  IntColumn get updatedAt => integer()(); // epoch ms

  @override
  Set<Column> get primaryKey => {id};
}

/// Lịch sử hoàn thành / bỏ qua.
class TaskLogs extends Table {
  TextColumn get id => text()(); // uuid PK
  // Xóa task thì xóa log theo (CASCADE).
  TextColumn get taskId => text().references(Tasks, #id,
      onDelete: KeyAction.cascade)();
  IntColumn get doneAt => integer()(); // epoch ms
  // done | early | late | skip
  TextColumn get status =>
      text().check(status.isIn(const ['done', 'early', 'late', 'skip']))();
  TextColumn get note => text().nullable()(); // ghi chú
  TextColumn get photoUri => text().nullable()(); // ảnh minh chứng
  IntColumn get cycleDaysSnapshot => integer()(); // cycle tại lúc done

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Tasks, TaskLogs])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  AppDb.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  // --- DAO gọn cho MVP (chi tiết Dev2 mở rộng ở data source) ---

  /// Tất cả task đang bật, xếp theo nextDue gần nhất.
  Future<List<Task>> getActiveTasks() {
    return (select(tasks)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.nextDueAt)]))
        .get();
  }

  /// Log của 1 task, mới nhất trước.
  Future<List<TaskLog>> getLogsForTask(String taskId) {
    return (select(taskLogs)
          ..where((l) => l.taskId.equals(taskId))
          ..orderBy([(l) => OrderingTerm.desc(l.doneAt)]))
        .get();
  }
}

/// Mở sqlite file trong app documents.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'habit_reminder.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

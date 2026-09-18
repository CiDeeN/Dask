// Model thuần Dart cho Task / TaskLog — KHÔNG import Flutter.
// Dùng chung cho recurrence.dart (logic) và drift (DB).

/// Trạng thái 1 lần hoàn thành (lưu trong task_logs.status).
enum TaskStatus {
  done, // đúng hạn
  early, // làm sớm (>1 ngày trước nextDue)
  late, // làm trễ (sau nextDue)
  skip, // bỏ qua chu kỳ
}

/// Công việc định kỳ, ví dụ: thay bàn chải 90 ngày, dọn toilet 7 ngày.
class Task {
  final String id;
  final String title;
  final String icon;
  final String? categoryId;
  final int cycleDays; // >= 1
  final int? lastDoneAt; // epoch ms, nullable
  final int nextDueAt; // epoch ms, NOT NULL
  final int gracePeriodDays; // default 0
  final int remindBeforeDays; // default 1
  final int? snoozedUntil; // epoch ms, nullable
  final bool isActive; // default true
  final int createdAt; // epoch ms
  final int updatedAt; // epoch ms

  const Task({
    required this.id,
    required this.title,
    this.icon = '🔔',
    this.categoryId,
    required this.cycleDays,
    this.lastDoneAt,
    required this.nextDueAt,
    this.gracePeriodDays = 0,
    this.remindBeforeDays = 1,
    this.snoozedUntil,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(cycleDays >= 1, 'cycleDays phải >= 1');

  /// Clone có chỉnh sửa (dùng khi markDone / snooze).
  Task copyWith({
    String? title,
    String? icon,
    String? categoryId,
    int? cycleDays,
    int? Function()? lastDoneAt,
    int? nextDueAt,
    int? gracePeriodDays,
    int? remindBeforeDays,
    int? Function()? snoozedUntil,
    bool? isActive,
    int? updatedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      categoryId: categoryId ?? this.categoryId,
      cycleDays: cycleDays ?? this.cycleDays,
      lastDoneAt: lastDoneAt != null ? lastDoneAt() : this.lastDoneAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      snoozedUntil: snoozedUntil != null ? snoozedUntil() : this.snoozedUntil,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      icon: (json['icon'] as String?) ?? '🔔',
      categoryId: json['category_id'] as String?,
      cycleDays: (json['cycle_days'] as num).toInt(),
      lastDoneAt: (json['last_done_at'] as num?)?.toInt(),
      nextDueAt: (json['next_due_at'] as num).toInt(),
      gracePeriodDays: ((json['grace_period_days'] as num?) ?? 0).toInt(),
      remindBeforeDays: ((json['remind_before_days'] as num?) ?? 1).toInt(),
      snoozedUntil: (json['snoozed_until'] as num?)?.toInt(),
      isActive: (json['is_active'] as num? ?? 1) == 1,
      createdAt: (json['created_at'] as num).toInt(),
      updatedAt: (json['updated_at'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'category_id': categoryId,
        'cycle_days': cycleDays,
        'last_done_at': lastDoneAt,
        'next_due_at': nextDueAt,
        'grace_period_days': gracePeriodDays,
        'remind_before_days': remindBeforeDays,
        'snoozed_until': snoozedUntil,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// 1 dòng lịch sử hoàn thành / bỏ qua.
class TaskLog {
  final String id;
  final String taskId;
  final int doneAt; // epoch ms
  final TaskStatus status;
  final String? note;
  final String? photoUri;
  final int cycleDaysSnapshot;

  const TaskLog({
    required this.id,
    required this.taskId,
    required this.doneAt,
    required this.status,
    this.note,
    this.photoUri,
    required this.cycleDaysSnapshot,
  });

  factory TaskLog.fromJson(Map<String, dynamic> json) {
    return TaskLog(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      doneAt: (json['done_at'] as num).toInt(),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.done,
      ),
      note: json['note'] as String?,
      photoUri: json['photo_uri'] as String?,
      cycleDaysSnapshot: (json['cycle_days_snapshot'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_id': taskId,
        'done_at': doneAt,
        'status': status.name,
        'note': note,
        'photo_uri': photoUri,
        'cycle_days_snapshot': cycleDaysSnapshot,
      };
}

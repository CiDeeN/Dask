// Engine tính chu kỳ nhắc việc — thuần Dart, KHÔNG phụ thuộc Flutter.
// Dùng được cho UI, notification scheduler và unit test.

import '../habits/data/models.dart';

/// 1 ngày = 86_400_000 ms.
const int kMsPerDay = 86400000;

/// Tính lần đến hạn tiếp theo từ lần làm cuối.
int computeNextDue(int lastDoneMs, int cycleDays) {
  assert(cycleDays >= 1, 'cycleDays phải >= 1');
  return lastDoneMs + cycleDays * kMsPerDay;
}

/// Trạng thái hiển thị của 1 task tại thời điểm [nowMs].
enum DueState {
  inactive, // task đã tắt
  overdue, // quá cả grace: diffDays < -grace
  dueGrace, // trễ nhưng còn trong grace
  dueToday, // đến hạn hôm nay
  upcoming, // sắp đến hạn (diffDays <= remindBefore)
  ok, // còn xa
}

/// Kết quả getStatus: state + số ngày chênh + text tiếng Việt.
class DueStatus {
  final DueState state;
  final int diffDays; // effectiveDue - now (làm tròn floor theo ngày)
  final int effectiveDueAt; // đã xét snoozedUntil
  final bool isSnoozed;
  final String countdownText; // text tiếng Việt hiển thị UI

  const DueStatus({
    required this.state,
    required this.diffDays,
    required this.effectiveDueAt,
    required this.isSnoozed,
    required this.countdownText,
  });
}

/// Xếp trạng thái task tại [nowMs].
DueStatus getStatus(Task task, {required int nowMs}) {
  // Task tắt thì không nhắc.
  if (!task.isActive) {
    return DueStatus(
      state: DueState.inactive,
      diffDays: 0,
      effectiveDueAt: task.nextDueAt,
      isSnoozed: false,
      countdownText: 'Đã tắt',
    );
  }

  // Ưu tiên snooze nếu còn hiệu lực.
  final bool isSnoozed =
      task.snoozedUntil != null && task.snoozedUntil! > nowMs;
  final int effectiveDue = isSnoozed ? task.snoozedUntil! : task.nextDueAt;

  // floor theo ngày để -1h vẫn tính là hôm nay (diffDays = 0).
  final int diffDays = ((effectiveDue - nowMs) / kMsPerDay).floor();

  final int grace = task.gracePeriodDays;
  final int remindBefore = task.remindBeforeDays;

  late final DueState state;
  late final String text;

  if (diffDays < -grace) {
    // Quá hạn cả grace.
    state = DueState.overdue;
    text = 'Quá hạn ${-diffDays} ngày';
  } else if (diffDays < 0) {
    // Trễ nhưng còn trong grace.
    state = DueState.dueGrace;
    text = 'Trễ ${-diffDays} ngày (gia hạn còn ${grace + diffDays + 1} ngày)';
  } else if (diffDays == 0) {
    state = DueState.dueToday;
    text = 'Đến hạn hôm nay';
  } else if (diffDays <= remindBefore) {
    state = DueState.upcoming;
    text = 'Còn $diffDays ngày';
  } else {
    state = DueState.ok;
    text = 'Còn $diffDays ngày';
  }

  final String prefix = isSnoozed ? 'Tạm hoãn • ' : '';
  return DueStatus(
    state: state,
    diffDays: diffDays,
    effectiveDueAt: effectiveDue,
    isSnoozed: isSnoozed,
    countdownText: '$prefix$text',
  );
}

/// Kết quả sau khi hoàn thành: task mới + log + status.
class MarkDoneResult {
  final Task updatedTask;
  final TaskStatus status;
  final int doneAt;

  const MarkDoneResult({
    required this.updatedTask,
    required this.status,
    required this.doneAt,
  });
}

/// Đánh dấu hoàn thành tại [nowMs]:
/// - early nếu now < nextDue - 1 ngày
/// - late nếu now > nextDue
/// - còn lại là done (đúng hạn)
/// Sau đó: lastDone = now, nextDue = now + cycle, xóa snooze.
MarkDoneResult markDone(
  Task task, {
  required int nowMs,
  String? logId, // gọi bên ngoài truyền uuid; null thì dùng nowMs làm id tạm
}) {
  final TaskStatus status;
  if (nowMs < task.nextDueAt - kMsPerDay) {
    status = TaskStatus.early; // làm sớm
  } else if (nowMs > task.nextDueAt) {
    status = TaskStatus.late; // làm trễ
  } else {
    status = TaskStatus.done; // đúng hạn
  }

  final Task updated = task.copyWith(
    lastDoneAt: () => nowMs,
    nextDueAt: computeNextDue(nowMs, task.cycleDays),
    snoozedUntil: () => null, // xóa snooze
    updatedAt: nowMs,
  );

  return MarkDoneResult(updatedTask: updated, status: status, doneAt: nowMs);
}

/// Tạo TaskLog tương ứng sau markDone (gọi UUID ở tầng gọi).
TaskLog buildDoneLog({
  required String logId,
  required Task task,
  required MarkDoneResult result,
  String? note,
  String? photoUri,
}) {
  return TaskLog(
    id: logId,
    taskId: task.id,
    doneAt: result.doneAt,
    status: result.status,
    note: note,
    photoUri: photoUri,
    cycleDaysSnapshot: task.cycleDays,
  );
}

/// Bỏ qua chu kỳ hiện tại: dời nextDue thêm 1 cycle, giữ lastDone.
Task markSkip(Task task, {required int nowMs}) {
  return task.copyWith(
    nextDueAt: computeNextDue(task.nextDueAt, task.cycleDays),
    snoozedUntil: () => null,
    updatedAt: nowMs,
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notification/notification_service.dart';
import '../../reminders/recurrence.dart' as rec;
import '../data/models.dart';

/// Dev2 sở hữu: state quản lý danh sách Task (Riverpod Notifier).
///
/// Dùng model Dev1: `Task` trong `../data/models.dart` (epoch ms).
/// Tái dùng engine Dev1 `recurrence.dart`: getStatus / markDone / markSkip / computeNextDue.
///
/// NOTE tích hợp Dev1: nối [TasksNotifier.load] với AppDb (drift).
/// Hiện load giữ state in-memory; Dev1/DB gọi [seed] sau khi đọc SQLite.
enum TaskFilter { all, overdue, upcoming, done }

class TaskStats {
  final int overdue;
  final int upcoming;
  final int total;
  const TaskStats({
    required this.overdue,
    required this.upcoming,
    required this.total,
  });
}

/// Filter đang chọn trên Home.
final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void set(TaskFilter f) => state = f;
}

/// Nguồn sự thật: toàn bộ tasks (đã sort theo gấp nhất).
final tasksProvider =
    NotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

class TasksNotifier extends Notifier<List<Task>> {
  @override
  List<Task> build() => const <Task>[];

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  // ---------- Load / seed ----------

  /// Điểm nối DB Dev1: đọc AppDb.getActiveTasks() rồi gọi seed(rows).
  Future<void> load() async {
    // PLACEHOLDER: giữ nguyên state hiện tại.
    // Ví dụ khi Dev1 xong: state = _sorted(await db.getActiveTasks());
    state = _sorted(state, nowMs: _nowMs());
    _refreshDigest();
  }

  /// Nạp danh sách ban đầu (từ DB Dev1 / template / test).
  void seed(List<Task> tasks) {
    state = _sorted(tasks, nowMs: _nowMs());
    _refreshDigest();
  }

  // ---------- Helpers (delegate sang recurrence của Dev1) ----------

  static rec.DueStatus statusOf(Task t, {int? nowMs}) => rec.getStatus(
        t,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      );

  static int daysLeft(Task t, {int? nowMs}) =>
      statusOf(t, nowMs: nowMs).diffDays;

  static bool isOverdue(Task t, {int? nowMs}) {
    final rec.DueStatus s = statusOf(t, nowMs: nowMs);
    return s.state == rec.DueState.overdue ||
        s.state == rec.DueState.dueGrace;
  }

  /// Sort theo gấp nhất: quá hạn (diffDays âm nhất) lên đầu,
  /// sau đó theo effectiveDue tăng dần.
  List<Task> _sorted(List<Task> input, {required int nowMs}) {
    final List<Task> list = List<Task>.from(input);
    list.sort((Task a, Task b) {
      final rec.DueStatus sa = rec.getStatus(a, nowMs: nowMs);
      final rec.DueStatus sb = rec.getStatus(b, nowMs: nowMs);
      final bool oa = sa.diffDays < 0;
      final bool ob = sb.diffDays < 0;
      if (oa && ob) return sa.diffDays.compareTo(sb.diffDays);
      if (oa) return -1;
      if (ob) return 1;
      return sa.effectiveDueAt.compareTo(sb.effectiveDueAt);
    });
    return list;
  }

  // ---------- CRUD ----------

  void add(Task task) {
    state = _sorted(<Task>[...state, task], nowMs: _nowMs());
    _schedule(task);
    _refreshDigest();
    // TODO(Dev1): insert vào AppDb.tasks ở đây.
  }

  void update(Task task) {
    state = _sorted(
      <Task>[for (final Task t in state) if (t.id == task.id) task else t],
      nowMs: _nowMs(),
    );
    _schedule(task);
    _refreshDigest();
    // TODO(Dev1): update AppDb.tasks ở đây.
  }

  Future<void> remove(String id) async {
    state = state.where((Task t) => t.id != id).toList();
    await NotificationService.instance.cancelTask(id);
    _refreshDigest();
    // TODO(Dev1): delete khỏi AppDb + cascade logs.
  }

  /// Vuốt Done / bấm Done: dùng engine Dev1 `markDone` (tính early/done/late,
  /// lastDone=now, nextDue=now+cycle, xóa snooze). Sau đó reschedule noti.
  Future<void> markDone(String id) async {
    final int nowMs = _nowMs();
    Task? updated;
    state = _sorted(
      <Task>[
        for (final Task t in state)
          if (t.id == id)
            () {
              updated =
                  rec.markDone(t, nowMs: nowMs).updatedTask;
              return updated!;
            }()
          else
            t,
      ],
      nowMs: nowMs,
    );
    if (updated != null) {
      await NotificationService.instance.scheduleTask(updated!);
    }
    _refreshDigest();
    // TODO(Dev1): persist updated + insert TaskLog (buildDoneLog) vào AppDb.
  }

  /// Snooze: set snoozedUntil (mặc định +1 ngày). Không đổi nextDueAt gốc.
  /// copyWith của Dev1 yêu cầu closure: snoozedUntil: () => ms.
  Future<void> snooze(String id, {DateTime? until}) async {
    final int targetMs = (until ?? DateTime.now().add(const Duration(days: 1)))
        .millisecondsSinceEpoch;
    final int nowMs = _nowMs();
    Task? updated;
    state = _sorted(
      <Task>[
        for (final Task t in state)
          if (t.id == id)
            () {
              updated = t.copyWith(
                snoozedUntil: () => targetMs,
                updatedAt: nowMs,
              );
              return updated!;
            }()
          else
            t,
      ],
      nowMs: nowMs,
    );
    if (updated != null) {
      await NotificationService.instance.scheduleTask(updated!);
    }
    _refreshDigest();
    // TODO(Dev1): persist snoozedUntil vào SQLite.
  }

  void clearSnooze(String id) {
    final int nowMs = _nowMs();
    final List<Task> next = <Task>[
      for (final Task t in state)
        if (t.id == id)
          t.copyWith(snoozedUntil: () => null, updatedAt: nowMs)
        else
          t,
    ];
    state = _sorted(next, nowMs: nowMs);
    _schedule(state.firstWhere((Task e) => e.id == id));
    _refreshDigest();
  }

  // ---------- Derived ----------

  Future<void> _schedule(Task t) async {
    try {
      await NotificationService.instance.scheduleTask(t);
    } catch (_) {
      // Bỏ qua khi chạy test/widget không có plugin native.
    }
  }

  Future<void> _refreshDigest() async {
    try {
      final TaskStats s = stats();
      await NotificationService.instance.scheduleDigest(
        overdueCount: s.overdue,
        upcomingCount: s.upcoming,
      );
    } catch (_) {
      // Bỏ qua trên test.
    }
  }

  TaskStats stats({int? nowMs}) {
    final int n = nowMs ?? _nowMs();
    int over = 0;
    int up = 0;
    for (final Task t in state) {
      final rec.DueStatus s = rec.getStatus(t, nowMs: n);
      if (s.state == rec.DueState.overdue ||
          s.state == rec.DueState.dueGrace) {
        over++;
      } else if (s.state == rec.DueState.upcoming ||
          s.state == rec.DueState.dueToday) {
        up++;
      }
    }
    return TaskStats(overdue: over, upcoming: up, total: state.length);
  }
}

/// Danh sách đã lọc + sort để Home render.
final filteredTasksProvider = Provider<List<Task>>((Ref ref) {
  final List<Task> all = ref.watch(tasksProvider);
  final TaskFilter filter = ref.watch(taskFilterProvider);
  final int nowMs = DateTime.now().millisecondsSinceEpoch;
  Iterable<Task> out = all;
  switch (filter) {
    case TaskFilter.overdue:
      out = out.where((Task t) {
        final rec.DueStatus s = rec.getStatus(t, nowMs: nowMs);
        return s.state == rec.DueState.overdue ||
            s.state == rec.DueState.dueGrace;
      });
      break;
    case TaskFilter.upcoming:
      out = out.where((Task t) {
        final rec.DueStatus s = rec.getStatus(t, nowMs: nowMs);
        return s.state == rec.DueState.upcoming ||
            s.state == rec.DueState.dueToday;
      });
      break;
    case TaskFilter.done:
      // Các task vừa done hôm nay (lastDoneAt là hôm nay).
      out = out.where((Task t) {
        if (t.lastDoneAt == null) return false;
        final DateTime l =
            DateTime.fromMillisecondsSinceEpoch(t.lastDoneAt!);
        final DateTime n =
            DateTime.fromMillisecondsSinceEpoch(nowMs);
        return l.year == n.year && l.month == n.month && l.day == n.day;
      });
      break;
    case TaskFilter.all:
      break;
  }
  return out.toList();
});

/// Header "X quá hạn, Y sắp tới".
final taskStatsProvider = Provider<TaskStats>((Ref ref) {
  final List<Task> all = ref.watch(tasksProvider);
  final int nowMs = DateTime.now().millisecondsSinceEpoch;
  int over = 0;
  int up = 0;
  for (final Task t in all) {
    final rec.DueStatus s = rec.getStatus(t, nowMs: nowMs);
    if (s.state == rec.DueState.overdue ||
        s.state == rec.DueState.dueGrace) {
      over++;
    } else if (s.state == rec.DueState.upcoming ||
        s.state == rec.DueState.dueToday) {
      up++;
    }
  }
  return TaskStats(overdue: over, upcoming: up, total: all.length);
});

/// Lookup 1 task cho DetailScreen.
final taskByIdProvider =
    Provider.family<Task?, String>((Ref ref, String id) {
  final List<Task> all = ref.watch(tasksProvider);
  for (final Task t in all) {
    if (t.id == id) return t;
  }
  return null;
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../reminders/recurrence.dart' as rec;
import '../data/models.dart';
import 'providers.dart';
import 'widgets/task_progress.dart';
import 'widgets/urgency_badge.dart';

/// Màn hình chính — header gradient + filter chips + TaskCard + FAB.
/// Logic providers/recurrence giữ nguyên, chỉ nâng cấp UI.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Task> tasks = ref.watch(filteredTasksProvider);
    final TaskStats stats = ref.watch(taskStatsProvider);
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final TasksNotifier notifier = ref.read(tasksProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Việc nhà định kỳ'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Thêm việc',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/form'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm việc',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: <Widget>[
          _OverviewHeader(stats: stats),
          _FilterBar(filter: filter),
          Expanded(
            child: tasks.isEmpty
                ? _EmptyState(filter: filter)
                : RefreshIndicator(
                    onRefresh: () => notifier.load(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.sm,
                        bottom: 96, // chừa chỗ FAB
                      ),
                      itemCount: tasks.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        final Task task = tasks[i];
                        return _TaskCard(task: task);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Header tổng quan: gradient + 3 stat pill ──────────────────

class _OverviewHeader extends StatelessWidget {
  final TaskStats stats;
  const _OverviewHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool allClear = stats.total > 0 && stats.overdue == 0;
    final String headline = stats.total == 0
        ? 'Bắt đầu ngôi nhà gọn gàng'
        : allClear
            ? 'Tuyệt vời, không việc trễ hạn 🎉'
            : '${stats.overdue} quá hạn • ${stats.upcoming} sắp tới';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient(dark: dark),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppTheme.softShadow(dark: dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  stats.overdue > 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats.total == 0
                          ? 'Thêm việc đầu tiên trong 30 giây'
                          : 'Tổng ${stats.total} việc đang theo dõi',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.total > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                _StatPill(
                  label: 'Quá hạn',
                  value: '${stats.overdue}',
                  tint: AppTheme.overRed,
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatPill(
                  label: 'Sắp tới',
                  value: '${stats.upcoming}',
                  tint: AppTheme.warnAmber,
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatPill(
                  label: 'Tổng',
                  value: '${stats.total}',
                  tint: Colors.white,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;
  const _StatPill({
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWhite = tint == Colors.white;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!isWhite)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chips ─────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final TaskFilter filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotifierProvider<TaskFilterNotifier, TaskFilter> p =
        taskFilterProvider;

    ChoiceChip chip(String label, TaskFilter value, IconData icon) {
      final bool selected = filter == value;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor:
            Theme.of(context).colorScheme.primaryContainer,
        onSelected: (_) => ref.read(p.notifier).set(value),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          chip('Tất cả', TaskFilter.all, Icons.grid_view_rounded),
          const SizedBox(width: AppSpacing.sm),
          chip('Quá hạn', TaskFilter.overdue, Icons.error_outline_rounded),
          const SizedBox(width: AppSpacing.sm),
          chip(
            'Sắp tới',
            TaskFilter.upcoming,
            Icons.schedule_rounded,
          ),
          const SizedBox(width: AppSpacing.sm),
          chip('Xong hôm nay', TaskFilter.done, Icons.check_circle_outline),
        ],
      ),
    );
  }
}

// ── Empty state thân thiện ───────────────────────────────────

class _EmptyState extends StatelessWidget {
  final TaskFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final bool isAll = filter == TaskFilter.all;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTheme.headerGradient(
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                shape: BoxShape.circle,
                boxShadow: AppTheme.softShadow(
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              child: Text(
                isAll ? '🏡' : '✨',
                style: const TextStyle(fontSize: 44),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isAll ? 'Nhà gọn bắt đầu từ đây' : 'Không có việc nào ở mục này',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isAll
                  ? 'Thêm việc đầu tiên hoặc chọn nhanh từ 15 mẫu có sẵn — chỉ mất 30 giây.'
                  : 'Mọi thứ đều ổn. Thử xem mục khác nhé!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.go('/form'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm việc mới'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TaskCard: icon badge gradient + progress 8px + badge pill ─

class _TaskCard extends ConsumerWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final rec.DueStatus st = rec.getStatus(task, nowMs: nowMs);
    // Map DueState -> urgency 5 mức.
    final Color color = switch (st.state) {
      rec.DueState.overdue => AppTheme.urgencyOverdue,
      rec.DueState.dueGrace => AppTheme.urgencyUrgent,
      rec.DueState.dueToday => AppTheme.urgencyUrgent,
      rec.DueState.upcoming => AppTheme.urgencySoon,
      _ => AppTheme.okGreen,
    };
    final double progress = _progress(task, st);
    final String countdown = st.countdownText;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey<String>('done-${task.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppTheme.urgencyGradient(AppTheme.okGreen, dark: dark),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Hoàn thành',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await ref.read(tasksProvider.notifier).markDone(task.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xong "${task.title}" 🎉')),
          );
        }
        return false; // không xóa card, chỉ markDone + resort
      },
      child: Card(
        child: InkWell(
          onTap: () => context.go('/detail/${task.id}'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _IconBadge(icon: task.icon, color: color, dark: dark),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              task.title,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          UrgencyBadge(text: countdown, color: color),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TaskProgress(
                        value: progress,
                        color: color,
                        caption:
                            'Hạn ${_fmt(task.nextDueAt)} • chu kỳ ${task.cycleDays} ngày',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _DoneButton(taskId: task.id),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _progress(Task t, rec.DueStatus st) {
    if (st.diffDays < 0) return 1.0;
    if (t.cycleDays <= 0) return 0.0;
    final double done = (t.cycleDays - st.diffDays) / t.cycleDays;
    return done.clamp(0.0, 1.0);
  }

  String _fmt(int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

class _IconBadge extends StatelessWidget {
  final String icon;
  final Color color;
  final bool dark;
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppTheme.urgencyGradient(color, dark: dark),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(icon, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _DoneButton extends ConsumerWidget {
  final String taskId;
  const _DoneButton({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton.filledTonal(
      tooltip: 'Đánh dấu xong',
      icon: const Icon(Icons.check_rounded, size: 20),
      onPressed: () =>
          ref.read(tasksProvider.notifier).markDone(taskId),
    );
  }
}

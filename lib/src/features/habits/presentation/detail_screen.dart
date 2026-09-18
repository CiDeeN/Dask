import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../reminders/recurrence.dart' as rec;
import 'providers.dart';
import 'widgets/urgency_badge.dart';

/// Màn hình chi tiết 1 task.
/// Route: `/detail/:id`. Nút Sửa -> `/form?edit=<id>`, Xóa -> về `/`.
/// Đọc text/countdown từ engine Dev1 (recurrence.getStatus).
class DetailScreen extends ConsumerWidget {
  final String taskId;
  const DetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskByIdProvider(taskId));

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('🏚️', style: TextStyle(fontSize: 56)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Không tìm thấy công việc',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Có thể việc này đã bị xóa.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final rec.DueStatus st = rec.getStatus(task, nowMs: nowMs);
    final Color color = switch (st.state) {
      rec.DueState.overdue => AppTheme.urgencyOverdue,
      rec.DueState.dueGrace => AppTheme.urgencyUrgent,
      rec.DueState.dueToday => AppTheme.urgencyUrgent,
      rec.DueState.upcoming => AppTheme.urgencySoon,
      _ => AppTheme.okGreen,
    };
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sửa',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/form?edit=${task.id}'),
          ),
          IconButton(
            tooltip: 'Xóa',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final bool? ok = await showDialog<bool>(
                context: context,
                builder: (BuildContext ctx) => AlertDialog(
                  title: const Text('Xóa việc này?'),
                  content: Text('"${task.title}" sẽ bị xóa vĩnh viễn.'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(tasksProvider.notifier).remove(task.id);
                if (context.mounted) context.go('/');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          // ── Hero card: icon gradient + tiêu đề + badge ──
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient(dark: dark),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppTheme.softShadow(dark: dark),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius:
                        BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    task.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          st.countdownText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Section: thông tin chu kỳ ──
          _SectionCard(
            title: 'Thông tin chu kỳ',
            icon: Icons.repeat_rounded,
            color: color,
            children: <Widget>[
              _Row(label: 'Chu kỳ', value: '${task.cycleDays} ngày/lần'),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: 'Lần cuối làm',
                value: task.lastDoneAt == null
                    ? 'Chưa làm lần nào'
                    : _fmtFull(task.lastDoneAt!),
              ),
              const Divider(height: AppSpacing.xl),
              _Row(label: 'Hạn tiếp theo', value: _fmtFull(task.nextDueAt)),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: 'Nhắc trước',
                value: '${task.remindBeforeDays} ngày',
              ),
              const Divider(height: AppSpacing.xl),
              _Row(
                label: 'Grace period',
                value: '${task.gracePeriodDays} ngày',
              ),
              if (task.snoozedUntil != null) ...<Widget>[
                const Divider(height: AppSpacing.xl),
                _Row(
                  label: 'Snooze tới',
                  value: _fmtFull(task.snoozedUntil!),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Section: trạng thái ──
          _SectionCard(
            title: 'Trạng thái',
            icon: Icons.info_outline_rounded,
            color: color,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Mức độ gấp',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  UrgencyBadge(text: st.countdownText, color: color),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── CTA full-width ──
          FilledButton.icon(
            onPressed: () async {
              await ref.read(tasksProvider.notifier).markDone(task.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đánh dấu xong 🎉'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Đánh dấu đã xong'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(tasksProvider.notifier).snooze(
                    task.id,
                    until:
                        DateTime.now().add(const Duration(days: 1)),
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã snooze tới ngày mai'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.snooze_rounded),
            label: const Text('Snooze 1 ngày'),
          ),
        ],
      ),
    );
  }

  String _fmtFull(int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

/// Section card tái dùng: tiêu đề + icon + nội dung.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

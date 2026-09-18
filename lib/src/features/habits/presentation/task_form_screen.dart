import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../reminders/recurrence.dart' as rec;
import '../data/models.dart';
import 'providers.dart';

/// Form tạo/sửa task.
/// Route: `/form` (tạo mới) hoặc `/form?edit=<id>` (sửa).
/// Fields: tên, icon (emoji), chu kỳ (ngày), lần cuối, nhắc trước, grace period.
/// Ghi theo model Dev1 (epoch ms) + computeNextDue của recurrence.
class TaskFormScreen extends ConsumerStatefulWidget {
  final String? editTaskId;
  const TaskFormScreen({super.key, this.editTaskId});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final GlobalKey<FormState> _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _cycle;
  late final TextEditingController _remindBefore;
  late final TextEditingController _grace;

  String _icon = '🧹';
  DateTime _lastDone = DateTime.now();
  bool _loaded = false;

  static const List<String> _iconChoices = <String>[
    '🧹',
    '🚽',
    '🛏️',
    '🧺',
    '🌬️',
    '🪥',
    '💧',
    '💇',
    '🦷',
    '🌱',
    '🧊',
    '🛵',
    '🛋️',
    '👕',
    '🧽',
  ];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _cycle = TextEditingController(text: '7');
    _remindBefore = TextEditingController(text: '2');
    _grace = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _title.dispose();
    _cycle.dispose();
    _remindBefore.dispose();
    _grace.dispose();
    super.dispose();
  }

  void _prefillIfEditing() {
    if (_loaded) return;
    _loaded = true;
    final String? id = widget.editTaskId;
    if (id == null) return;
    final Task? t = ref.read(taskByIdProvider(id));
    if (t == null) return;
    _title.text = t.title;
    _cycle.text = t.cycleDays.toString();
    _remindBefore.text = t.remindBeforeDays.toString();
    _grace.text = t.gracePeriodDays.toString();
    _icon = t.icon;
    if (t.lastDoneAt != null) {
      _lastDone =
          DateTime.fromMillisecondsSinceEpoch(t.lastDoneAt!);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _prefillIfEditing();
    final bool isEdit = widget.editTaskId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa việc' : 'Thêm việc'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            // ── Section: thông tin cơ bản ──
            _Section(
              title: 'Thông tin cơ bản',
              step: '01',
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Tên việc *',
                    hintText: 'VD: Lau nhà, Giặt ga giường…',
                    prefixIcon: Icon(Icons.cleaning_services_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Nhập tên việc';
                    }
                    if (v.trim().length > 80) {
                      return 'Tên quá dài (max 80)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Chọn icon',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String e in _iconChoices)
                      _IconChoice(
                        emoji: e,
                        selected: _icon == e,
                        onTap: () => setState(() => _icon = e),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Section: chu kỳ & nhắc nhở ──
            _Section(
              title: 'Chu kỳ & nhắc nhở',
              step: '02',
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _cycle,
                        decoration: const InputDecoration(
                          labelText: 'Chu kỳ (ngày) *',
                          prefixIcon:
                              Icon(Icons.repeat_rounded, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                        validator: _positiveInt,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _remindBefore,
                        decoration: const InputDecoration(
                          labelText: 'Nhắc trước',
                          suffixText: 'ngày',
                          prefixIcon:
                              Icon(Icons.notifications_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                        validator: _nonNegativeInt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _grace,
                  decoration: const InputDecoration(
                    labelText: 'Grace period (ngày)',
                    helperText:
                        'Số ngày trễ cho phép trước khi tính quá hạn nặng',
                    prefixIcon:
                        Icon(Icons.hourglass_empty_rounded, size: 20),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _nonNegativeInt,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Lần cuối làm',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall,
                            ),
                            Text(
                              _fmt(_lastDone),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                        onPressed: _pickDate,
                        child: const Text('Chọn ngày'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── CTA full-width ──
            FilledButton.icon(
              onPressed: _save,
              icon: Icon(isEdit ? Icons.save_outlined : Icons.add_rounded),
              label: Text(isEdit ? 'Lưu thay đổi' : 'Thêm việc'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Hủy bỏ'),
            ),
          ],
        ),
      ),
    );
  }

  String? _positiveInt(String? v) {
    final int? n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Nhập số';
    if (n < 1) return 'Phải ≥ 1';
    if (n > 365) return 'Tối đa 365';
    return null;
  }

  String? _nonNegativeInt(String? v) {
    final int? n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Nhập số';
    if (n < 0) return 'Phải ≥ 0';
    if (n > 30) return 'Tối đa 30';
    return null;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastDone,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _lastDone = picked);
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final int cycle = int.parse(_cycle.text.trim());
    final int remind = int.parse(_remindBefore.text.trim());
    final int grace = int.parse(_grace.text.trim());
    final String title = _title.text.trim();
    final TasksNotifier notifier = ref.read(tasksProvider.notifier);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int lastMs = DateTime(
      _lastDone.year,
      _lastDone.month,
      _lastDone.day,
      8,
    ).millisecondsSinceEpoch;

    if (widget.editTaskId != null) {
      final Task? old = ref.read(taskByIdProvider(widget.editTaskId!));
      if (old == null) {
        context.go('/');
        return;
      }
      notifier.update(
        old.copyWith(
          title: title,
          icon: _icon,
          cycleDays: cycle,
          lastDoneAt: () => lastMs,
          nextDueAt: rec.computeNextDue(lastMs, cycle),
          remindBeforeDays: remind,
          gracePeriodDays: grace,
          updatedAt: nowMs,
        ),
      );
    } else {
      final Task task = Task(
        id: nowMs.toString(),
        title: title,
        icon: _icon,
        cycleDays: cycle,
        lastDoneAt: lastMs,
        nextDueAt: rec.computeNextDue(lastMs, cycle),
        remindBeforeDays: remind,
        gracePeriodDays: grace,
        createdAt: nowMs,
        updatedAt: nowMs,
      );
      notifier.add(task);
    }
    context.go('/');
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Section card cho form: số bước + tiêu đề + nội dung.
class _Section extends StatelessWidget {
  final String title;
  final String step;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.step,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    step,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Ô chọn icon emoji: viền teal + nền tint khi selected.
class _IconChoice extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Thanh tiến độ chu kỳ dày 8px, bo tròn pill, gradient theo urgency.
/// [value] 0.0–1.0 (tỉ lệ thời gian đã trôi qua trong chu kỳ).
class TaskProgress extends StatelessWidget {
  final double value;
  final Color color;
  final String? caption;

  const TaskProgress({
    super.key,
    required this.value,
    required this.color,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.12)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v <= 0 ? 0 : v,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.urgencyGradient(color, dark: dark),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (caption != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            caption!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

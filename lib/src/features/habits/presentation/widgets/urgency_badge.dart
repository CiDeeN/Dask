import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Badge countdown pill tái dùng — chấm tròn + text, nền tint theo urgency.
class UrgencyBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool compact;

  const UrgencyBadge({
    super.key,
    required this.text,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: dark ? 0.45 : 0.30),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: dark ? _onDarkTint(color) : _darken(color),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Làm đậm màu urgency để đủ tương phản trên nền tint (light mode).
  Color _darken(Color c) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
  }

  /// Trên dark mode cần sáng hơn để đọc được trên nền tối.
  Color _onDarkTint(Color c) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
  }
}

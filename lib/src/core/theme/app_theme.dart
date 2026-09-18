import 'package:flutter/material.dart';

/// Design System — "Nhà Gọn" (teal chăm sóc nhà cửa, Material3).
/// Giữ API cũ: [AppTheme], [AppTheme.urgencyColor], okGreen/warnAmber/overRed.
///
/// Palette:
/// - primary teal #00695C, secondary #4DB6AC, tertiary warm #FF8A65
/// - urgency 5 mức: fresh → ok → soon → urgent → overdue
/// - background light #F6F8F7, dark #101414
class AppTheme {
  AppTheme._();

  // ── Brand ──────────────────────────────────────────────
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color secondaryMint = Color(0xFF80CBC4);
  static const Color tertiaryWarm = Color(0xFFFF8A65);

  // ── Urgency (giữ tên cũ để không vỡ API) ───────────────
  static const Color okGreen = Color(0xFF2E9E5B);
  static const Color warnAmber = Color(0xFFE69F00);
  static const Color overRed = Color(0xFFD64545);

  // Thang urgency 5 mức (mới, dùng cho gradient/badge/progress).
  static const Color urgencyFresh = Color(0xFF26A69A); // còn xa, teal tươi
  static const Color urgencyOk = okGreen; // an toàn
  static const Color urgencySoon = warnAmber; // sắp tới
  static const Color urgencyUrgent = Color(0xFFE86A2C); // cam đỏ, hôm nay/grace
  static const Color urgencyOverdue = overRed; // quá hạn

  static const Color lightBackground = Color(0xFFF6F8F7);
  static const Color darkBackground = Color(0xFF101414);
  static const Color darkSurface = Color(0xFF1A2120);

  static const Color _seed = primaryTeal;

  static final ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
    surface: const Color(0xFFFFFFFF),
  ).copyWith(
    // Nền app hơi ngả xanh-xám cho dịu mắt.
    surfaceContainerLowest: const Color(0xFFF6F8F7),
  );

  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
    surface: darkSurface,
  );

  // ── Helpers ────────────────────────────────────────────

  /// Gradient 2 màu từ urgency color → nhạt dần (dùng cho icon badge, header).
  static LinearGradient urgencyGradient(Color color, {bool dark = false}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        color,
        Color.lerp(color, dark ? Colors.black : Colors.white, 0.35)!,
      ],
    );
  }

  /// Gradient header trang chủ (teal brand, tương phản tốt cả 2 mode).
  static LinearGradient headerGradient({bool dark = false}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const <Color>[Color(0xFF00332C), Color(0xFF00695C)]
          : const <Color>[Color(0xFF00695C), Color(0xFF26A69A)],
    );
  }

  /// Bóng mềm chuẩn toàn app.
  static List<BoxShadow> softShadow({bool dark = false}) => <BoxShadow>[
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: 0.45)
              : primaryTeal.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
      ];

  // ── Theme ──────────────────────────────────────────────

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: lightBackground,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: lightBackground,
        foregroundColor: lightScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: Color(0xFF17211F),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: lightScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: lightScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      chipTheme: ChipThemeData.fromDefaults(
        primaryColor: lightScheme.primary,
        secondaryColor: lightScheme.secondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ).copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: lightScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: lightScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: primaryTeal, width: 1.6),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: lightScheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: darkBackground,
        foregroundColor: darkScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      chipTheme: ChipThemeData.fromDefaults(
        primaryColor: darkScheme.primary,
        secondaryColor: darkScheme.secondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ).copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF222B2A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide(color: secondaryMint, width: 1.6),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }

  /// Typography Material3 — giữ font hệ thống, chuẩn scale + weight rõ ràng.
  static TextTheme _textTheme(Brightness brightness) {
    final Color base =
        brightness == Brightness.dark ? Colors.white : const Color(0xFF17211F);
    final Color muted = brightness == Brightness.dark
        ? const Color(0xFFB7C4C1)
        : const Color(0xFF5B6B68);
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.2,
        color: base,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
        color: base,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: base,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: base,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: base),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: base),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
      labelLarge: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }

  /// Màu countdown theo số ngày còn lại (giữ API cũ).
  /// - daysLeft < 0  -> đỏ (quá hạn)
  /// - daysLeft <= warnThreshold -> vàng (sắp tới)
  /// - còn lại -> xanh (an toàn)
  static Color urgencyColor(int daysLeft, {int warnThreshold = 2}) {
    if (daysLeft < 0) return overRed;
    if (daysLeft <= warnThreshold) return warnAmber;
    return okGreen;
  }

  /// Thang urgency 5 mức cho UI mới (chi tiết hơn urgencyColor 3 mức).
  static Color urgencyLevel(int daysLeft) {
    if (daysLeft < 0) return urgencyOverdue;
    if (daysLeft == 0) return urgencyUrgent;
    if (daysLeft <= 2) return urgencySoon;
    if (daysLeft <= 5) return urgencyOk;
    return urgencyFresh;
  }
}

/// Spacing chuẩn 4/8/12/16/24 (+32/48 cho section lớn).
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double hero = 48;
}

/// Radius chuẩn: sm 8 / md 12 / lg 16 / xl 24 / pill 999.
abstract class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

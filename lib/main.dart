import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/core/router/app_router.dart';
import 'src/core/theme/app_theme.dart';

/// Điểm vào app — đã tích hợp Router + Design System "Nhà Gọn".
Future<void> main() async {
  // Cần để dùng path_provider / notifications sau này.
  WidgetsFlutterBinding.ensureInitialized();

  // Load locale tiếng Việt cho intl (định dạng ngày).
  await initializeDateFormatting('vi_VN', null);

  runApp(const ProviderScope(child: HabitApp()));
}

/// Widget gốc của app nhắc việc chu kỳ.
class HabitApp extends StatelessWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nhắc việc chu kỳ',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi', 'VN'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}

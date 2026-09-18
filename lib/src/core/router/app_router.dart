import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/habits/presentation/detail_screen.dart';
import '../../../features/habits/presentation/home_screen.dart';
import '../../../features/habits/presentation/task_form_screen.dart';

/// Dev2 sở hữu: router go_router.
/// Routes:
/// - `/`        -> HomeScreen (danh sách countdown)
/// - `/detail/:id` -> DetailScreen(id)
/// - `/form`    -> TaskFormScreen (tạo mới; khi sửa truyền extra = taskId)
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const MaterialPage<void>(child: HomeScreen());
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'detail/:id',
            name: 'detail',
            pageBuilder: (BuildContext context, GoRouterState state) {
              final String id = state.pathParameters['id'] ?? '';
              return MaterialPage<void>(child: DetailScreen(taskId: id));
            },
          ),
          GoRoute(
            path: 'form',
            name: 'form',
            pageBuilder: (BuildContext context, GoRouterState state) {
              // Sửa: /form?edit=<id> hoặc extra = id. Tạo mới: không param.
              final String? editId =
                  state.uri.queryParameters['edit'] ?? state.extra as String?;
              return MaterialPage<void>(
                child: TaskFormScreen(editTaskId: editId),
              );
            },
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Route không tồn tại: ${state.uri}'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

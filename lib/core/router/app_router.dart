import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/students/pages/students_page.dart';
import '../../features/attendance/pages/attendance_page.dart';
import '../../features/history/pages/history_page.dart';
import '../../features/reports/pages/reports_page.dart';
import '../../features/settings/pages/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShellWrapper(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (c, s) => const DashboardPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/students', builder: (c, s) => const StudentsPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/attendance', builder: (c, s) => const TakeAttendancePage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/history', builder: (c, s) => const AttendanceHistoryPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/reports', builder: (c, s) => const ReportsPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (c, s) => const SettingsPage())],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found')),
    ),
  );
});

class NavigationShellWrapper extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShellWrapper({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
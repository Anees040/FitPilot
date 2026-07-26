import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/features/today/presentation/today_screen.dart';
import 'package:fitpilot/features/log/presentation/log_screen.dart';
import 'package:fitpilot/features/plan/presentation/plan_screen.dart';
import 'package:fitpilot/features/progress/presentation/progress_screen.dart';
import 'package:fitpilot/features/profile/presentation/profile_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorTodayKey = GlobalKey<NavigatorState>(debugLabel: 'today');
final shellNavigatorLogKey = GlobalKey<NavigatorState>(debugLabel: 'log');
final shellNavigatorPlanKey = GlobalKey<NavigatorState>(debugLabel: 'plan');
final shellNavigatorProgressKey = GlobalKey<NavigatorState>(debugLabel: 'progress');
final shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/today',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: shellNavigatorTodayKey,
          routes: [
            GoRoute(
              path: '/today',
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: shellNavigatorLogKey,
          routes: [
            GoRoute(
              path: '/log',
              builder: (context, state) => const LogScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: shellNavigatorPlanKey,
          routes: [
            GoRoute(
              path: '/plan',
              builder: (context, state) => const PlanScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: shellNavigatorProgressKey,
          routes: [
            GoRoute(
              path: '/progress',
              builder: (context, state) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ColoredBox(
        color: AppTheme.surface,
        child: SafeArea(
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.hairline,
                  width: 1.0,
                ),
              ),
            ),
            child: BottomNavigationBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              currentIndex: navigationShell.currentIndex,
              selectedItemColor: AppTheme.accent,
              unselectedItemColor: AppTheme.secondaryText,
              onTap: _goBranch,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.today),
                  label: 'Today',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt),
                  label: 'Log',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.track_changes),
                  label: 'Plan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up),
                  label: 'Progress',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

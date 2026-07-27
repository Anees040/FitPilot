import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/features/today/presentation/today_screen.dart';
import 'package:fitpilot/features/log/presentation/log_screen.dart';
import 'package:fitpilot/features/plan/presentation/plan_screen.dart';
import 'package:fitpilot/features/progress/presentation/progress_screen.dart';
import 'package:fitpilot/features/profile/presentation/profile_screen.dart';

import 'package:fitpilot/features/auth/presentation/welcome_screen.dart';
import 'package:fitpilot/features/auth/presentation/sign_up_screen.dart';
import 'package:fitpilot/features/auth/presentation/sign_in_screen.dart';
import 'package:fitpilot/features/auth/presentation/otp_verify_screen.dart';
import 'package:fitpilot/features/auth/presentation/forgot_password_screen.dart';
import 'package:fitpilot/features/capture/presentation/capture_screen.dart';
import 'package:fitpilot/data/local/app_database.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorTodayKey = GlobalKey<NavigatorState>(debugLabel: 'today');
final shellNavigatorLogKey = GlobalKey<NavigatorState>(debugLabel: 'log');
final shellNavigatorPlanKey = GlobalKey<NavigatorState>(debugLabel: 'plan');
final shellNavigatorProgressKey = GlobalKey<NavigatorState>(
  debugLabel: 'progress',
);
final shellNavigatorProfileKey = GlobalKey<NavigatorState>(
  debugLabel: 'profile',
);

bool? _isFirstLaunch;

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/today',
  redirect: (context, state) async {
    if (_isFirstLaunch == null) {
      final db = await AppDatabase.instance();
      final rows = await db.query('profile');
      _isFirstLaunch = rows.isEmpty;
    }

    if (_isFirstLaunch! && state.uri.path == '/today') {
      _isFirstLaunch = false;
      return '/welcome';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/signup',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/signin',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/otp',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          OtpVerifyScreen(email: state.extra as String),
    ),
    GoRoute(
      path: '/forgot-password',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/capture',
      parentNavigatorKey: rootNavigatorKey, // Overlay above bottom nav
      builder: (context, state) => const CaptureScreen(),
    ),
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
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

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
                top: BorderSide(color: AppTheme.hairline, width: 1.0),
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

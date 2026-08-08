import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/features/today/presentation/today_screen.dart';
import 'package:fitpilot/features/log/presentation/log_screen.dart';
import 'package:fitpilot/features/plan/presentation/plan_screen.dart';
import 'package:fitpilot/features/progress/presentation/progress_screen.dart';
import 'package:fitpilot/features/profile/presentation/profile_screen.dart';


import 'package:fitpilot/features/splash/presentation/splash_screen.dart';

import 'package:fitpilot/features/auth/presentation/auth_screen.dart';
import 'package:fitpilot/features/auth/presentation/welcome_screen.dart';
import 'package:fitpilot/features/auth/presentation/otp_verify_screen.dart';
import 'package:fitpilot/features/auth/presentation/forgot_password_screen.dart';
import 'package:fitpilot/features/auth/presentation/update_password_screen.dart';
import 'package:fitpilot/features/auth/presentation/change_password_screen.dart';
import 'package:fitpilot/features/profile/presentation/profile_setup_screen.dart';
import 'package:fitpilot/features/capture/presentation/capture_screen.dart';
import 'package:fitpilot/features/exercises/presentation/exercise_library_screen.dart';
import 'package:fitpilot/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:fitpilot/features/exercises/presentation/workout_hub_screen.dart';
import 'package:fitpilot/features/exercises/presentation/category_detail_screen.dart';
import 'package:fitpilot/features/exercises/presentation/muscle_detail_screen.dart';
import 'package:fitpilot/features/coach/presentation/chat_screen.dart';
import 'package:fitpilot/features/log/presentation/protein_guide_screen.dart';
import 'package:fitpilot/features/exercises/presentation/form_check_screen.dart';
import 'package:fitpilot/features/exercises/presentation/machine_scanner_screen.dart';
import 'package:fitpilot/features/exercises/presentation/machine_camera_screen.dart';
import 'package:fitpilot/features/exercises/presentation/machine_result_screen.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';
import 'package:fitpilot/features/programs/presentation/programs_screen.dart';
import 'package:fitpilot/features/programs/presentation/program_detail_screen.dart';
import 'package:fitpilot/features/programs/presentation/session_detail_screen.dart';
import 'package:fitpilot/features/programs/presentation/program_complete_screen.dart';
import 'package:fitpilot/features/today/presentation/notification_screen.dart';
import 'package:fitpilot/features/settings/presentation/notification_prefs_screen.dart';
import 'package:fitpilot/features/settings/presentation/app_settings_screen.dart';
import 'package:fitpilot/features/settings/presentation/image_credits_screen.dart';
import 'package:fitpilot/features/today/presentation/all_meals_screen.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/offline_banner.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorTodayKey = GlobalKey<NavigatorState>(debugLabel: 'today');
final shellNavigatorLogKey = GlobalKey<NavigatorState>(debugLabel: 'log');
final shellNavigatorPlanKey = GlobalKey<NavigatorState>(debugLabel: 'plan');
final shellNavigatorProgressKey = GlobalKey<NavigatorState>(
  debugLabel: 'progress',
);
final shellNavigatorProgramsKey = GlobalKey<NavigatorState>(
  debugLabel: 'programs',
);

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final indexStr = state.uri.queryParameters['initialIndex'];
        final index = int.tryParse(indexStr ?? '0') ?? 0;
        return WelcomeScreen(initialIndex: index);
      },
    ),
    GoRoute(
      path: '/auth',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => AuthScreen(
        initialMode: state.uri.queryParameters['mode'],
      ),
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
      path: '/update-password',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const UpdatePasswordScreen(),
    ),
    GoRoute(
      path: '/change-password',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/capture',
      parentNavigatorKey: rootNavigatorKey, // Overlay above bottom nav
      builder: (context, state) => const CaptureScreen(),
    ),
    GoRoute(
      path: '/exercises',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ExerciseLibraryScreen(),
    ),
    GoRoute(
      path: '/exercises/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => ExerciseDetailScreen(
        exerciseId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/workout-hub',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const WorkoutHubScreen(),
      routes: [
        GoRoute(
          path: 'category/:id',
          builder: (context, state) => CategoryDetailScreen(
            categoryId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: 'muscle/:id',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return MuscleDetailScreen(
              muscleId: state.pathParameters['id']!,
              customTitle: extra?['title'] as String?,
              customImage: extra?['image'] as String?,
            );
          },
        ),
      ]
    ),
    GoRoute(
      path: '/form-check',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const FormCheckScreen(),
    ),
    GoRoute(
      path: '/machine-scanner',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const MachineScannerScreen(),
      routes: [
        GoRoute(
          path: 'camera',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return MachineCameraScreen(
              startInGallery: extra?['source'] == 'gallery',
            );
          },
        ),
        GoRoute(
          path: 'result',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final analysis = extra?['analysis'];
            // A direct hit on this route (deep link, hot restart) carries no
            // analysis, so send the user to the scanner rather than crash.
            if (analysis is! MachineAnalysis) {
              return const MachineScannerScreen();
            }
            return MachineResultScreen(
              analysis: analysis,
              fromHistory: extra?['fromHistory'] == true,
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/protein-guide',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ProteinGuideScreen(),
    ),
    GoRoute(
      path: '/coach',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AppSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/notifications',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationPrefsScreen(),
    ),
    GoRoute(
      path: '/settings/credits',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ImageCreditsScreen(),
    ),
    // Profile moved off the bottom nav: it is a settings destination reached
    // from the Today avatar, so Programs can take the fifth tab.
    GoRoute(
      path: '/profile',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/meals',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AllMealsScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MaxWidthCenter(
          child: ScaffoldWithNavBar(navigationShell: navigationShell),
        );
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
        // Programs are addressed by id rather than passed as `extra`, so a deep
        // link (and a hot reload mid-session) resolves without a prior push.
        // The list is a tab; its details push full-screen over the nav bar.
        StatefulShellBranch(
          navigatorKey: shellNavigatorProgramsKey,
          routes: [
            GoRoute(
              path: '/programs',
              builder: (context, state) => const ProgramsScreen(),
              routes: [
                GoRoute(
                  path: 'complete/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => ProgramCompleteScreen(
                    programId: state.pathParameters['id']!,
                    sessions: int.tryParse(
                          state.uri.queryParameters['sessions'] ?? '',
                        ) ??
                        0,
                    kcal:
                        int.tryParse(state.uri.queryParameters['kcal'] ?? '') ??
                        0,
                  ),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      ProgramDetailScreen(programId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'session/:sessionId',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => SessionDetailScreen(
                        programId: state.pathParameters['id']!,
                        sessionId: state.pathParameters['sessionId']!,
                      ),
                    ),
                  ],
                ),
              ],
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
    if (index != navigationShell.currentIndex) {
      HapticFeedback.lightImpact();
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: ext.hairline, width: 1.0),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 80,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: ext.accentSoft,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final color = states.contains(WidgetState.selected)
                  ? theme.colorScheme.primary
                  : theme.textTheme.caption.color;
              return theme.textTheme.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(color: theme.colorScheme.primary, size: 24);
              }
              return IconThemeData(color: theme.textTheme.caption.color, size: 24);
            }),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.local_fire_department_outlined),
                selectedIcon: _AnimatedIconWrapper(child: Icon(Icons.local_fire_department)),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: _AnimatedIconWrapper(child: Icon(Icons.search)),
                label: 'Log',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: _AnimatedIconWrapper(child: Icon(Icons.calendar_today)),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart),
                selectedIcon: _AnimatedIconWrapper(child: Icon(Icons.bar_chart)),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: _AnimatedIconWrapper(child: Icon(Icons.fitness_center)),
                label: 'Programs',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedIconWrapper extends StatefulWidget {
  final Widget child;
  const _AnimatedIconWrapper({required this.child});

  @override
  State<_AnimatedIconWrapper> createState() => _AnimatedIconWrapperState();
}

class _AnimatedIconWrapperState extends State<_AnimatedIconWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInCubic)), weight: 50),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

class MaxWidthCenter extends StatelessWidget {
  final Widget child;
  const MaxWidthCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }
}



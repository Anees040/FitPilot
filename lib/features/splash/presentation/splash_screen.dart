import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/application/bootstrap.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isInitStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitStarted) {
        _isInitStarted = true;
        _initializeApp();
      }
    });
  }

  Future<void> _initializeApp() async {
    // Wait for the animation to finish
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final db = await AppDatabase.instance();
      await FitPilotBootstrap.importSeedData();
      final rows = await db.query('profile');
      final isFirstLaunch = rows.isEmpty;

      if (mounted) {
        if (isFirstLaunch) {
          context.go('/welcome');
        } else {
          context.go('/today');
        }
      }
    } catch (e) {
      if (mounted) {
        // Fallback on error
        context.go('/welcome');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 96,
                  height: 96,
                  errorBuilder: (c, e, s) => Icon(
                    Icons.local_fire_department,
                    size: 64,
                    color: Theme.of(c).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'FitPilot',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Eat it. Burn it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

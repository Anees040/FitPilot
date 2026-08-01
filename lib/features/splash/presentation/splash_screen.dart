import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/application/bootstrap.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _mottoFadeAnimation;
  late Animation<Offset> _mottoSlideAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isInitStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // 1s
    );

    // Scale 0.9 -> 1.0
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Fade motto starting at 300ms (0.3 to 1.0)
    _mottoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    // Slide motto starting at 300ms
    _mottoSlideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
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
    await Future.delayed(const Duration(milliseconds: 2500));

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final logoPath = isDark 
        ? 'assets/images/logo_mark_white.png' 
        : 'assets/images/logo_mark_orange.png';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.scaffoldBackgroundColor,
                ],
                radius: 1.5,
              ),
            ),
          ),
          // Logo in the center
          Center(
            child: FadeTransition(
              opacity: _scaleAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Image.asset(
                    logoPath,
                    width: 144, // Make it big enough to match the generated native splash
                    height: 144,
                    errorBuilder: (c, e, s) => Icon(
                      Icons.local_fire_department,
                      size: 64,
                      color: Theme.of(c).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Motto fading in below the logo
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.5 - 120, // positioned nicely below center
            child: FadeTransition(
              opacity: _mottoFadeAnimation,
              child: SlideTransition(
                position: _mottoSlideAnimation,
                child: Text(
                  'Eat it. Burn it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

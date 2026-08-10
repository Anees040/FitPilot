import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/application/bootstrap.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  bool _isInitStarted = false;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Opacity 0 -> 1 over 600ms (600/1400 = 0.428)
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.428, curve: Curves.easeOut),
      ),
    );

    // Scale 1.05 -> 1.0 over 1400ms (1400/1400 = 1.0)
    _scale = Tween<double>(begin: 1.05, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitStarted) {
        _isInitStarted = true;
        _initializeApp();
      }
    });
  }

  Future<void> _initializeApp() async {
    // Enough for the fade-in to read as intentional rather than a flicker, and
    // no more. It runs *alongside* the real work below instead of before it, so
    // on a warm start the two overlap and cost nothing extra.
    final minimumOnScreen = Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    try {
      // Supabase is initialized after the first frame. Routing before it
      // resolves would read a session that is not restored yet and bounce a
      // signed-in user to /welcome.
      await FitPilotBootstrap.warmUp();

      final db = await AppDatabase.instance();
      await FitPilotBootstrap.importSeedData();
      final rows = await db.query('profile');
      final isFirstLaunch = rows.isEmpty;

      await minimumOnScreen;
      if (mounted) {
        if (isFirstLaunch) {
          context.go('/welcome');
        } else {
          context.go('/today');
        }
      }
    } catch (e) {
      await minimumOnScreen;
      if (mounted) {
        // Fallback on error
        context.go('/welcome');
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/splash_bg.webp'), context);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFE56A2B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Image.asset(
                      'assets/images/splash_bg.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

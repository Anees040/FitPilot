import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/application/bootstrap.dart';

/// The first Flutter screen, showing the same artwork the Android launch
/// window already painted.
///
/// It deliberately does not animate. The native `launch_background.xml` draws
/// `splash_bg` from process start, so this widget's job is to continue that
/// image without a seam — fading or scaling it in made the handoff look like a
/// second splash screen appearing on top of the first, which is exactly the
/// double-splash the app used to show.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitStarted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitStarted) {
        _isInitStarted = true;
        _initializeApp();
      }
    });
  }

  Future<void> _initializeApp() async {
    // A floor on how long the splash stays up, so a warm start does not blink
    // through it in two frames. It runs alongside the real work rather than
    // before it, so on a slow start it costs nothing at all.
    final minimumOnScreen = Future<void>.delayed(
      const Duration(milliseconds: 400),
    );

    try {
      // Started together, awaited together. The warm-up is network-bound and
      // the database work is disk-bound, so running them in sequence spent the
      // sum of both for no reason — on a first launch the seed import alone is
      // most of a second.
      final warmUp = FitPilotBootstrap.warmUp();
      final dbReady = AppDatabase.instance();

      // Routing has to wait for the warm-up: until Supabase has restored its
      // session, authRepositoryProvider still reports a guest, and /today
      // rendered as a guest would write rows that never get queued for upload.
      await warmUp;
      final db = await dbReady;
      await FitPilotBootstrap.importSeedData();

      final rows = await db.query('profile', limit: 1);
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
  Widget build(BuildContext context) {
    // Matches @color/splash_color, so the fill behind the artwork is identical
    // to the one the native launch window used.
    const bgColor = Color(0xFFE56A2B);

    return const Scaffold(
      backgroundColor: bgColor,
      body: SizedBox.expand(
        child: Image(
          // Not Image.asset: that resolves the asset during the first build,
          // and the one-frame gap before it decodes showed the bare background
          // colour as a flash between the native splash and this one.
          image: AssetImage('assets/images/splash_bg.webp'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          // The image is already on screen from the native window, so there is
          // nothing to fade in and no placeholder worth showing.
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/application/bootstrap.dart';

/// The first Flutter screen, and the only thing in the whole startup that draws
/// the splash artwork.
///
/// It deliberately does not animate. The native launch window and the Android
/// 12+ system splash are both a flat fill of `@color/splash_color` — the same
/// orange as this artwork's own background — so when Flutter's first frame lands
/// the picture simply appears on an already-orange screen. Fading or scaling it
/// in, or letting the native side draw a copy of it at a different scale, is
/// what made the handoff look like a second, slightly zoomed splash appearing on
/// top of the first. That was the blink; there is one image now, drawn once.
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
    // to the one the native launch window and the Android 12+ system splash
    // both used — which is what lets the artwork appear without a seam.
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
          // Nothing to fade in: the screen underneath is already this exact
          // orange, so the artwork landing in one frame is the seamless case.
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

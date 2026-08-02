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
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _nameOpacity;
  late Animation<double> _mottoOpacity;
  late Animation<double> _trailOpacity;

  bool _isInitStarted = false;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Logo scales in from 0.7 → 1.0 over first 600ms
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
      ),
    );

    // Logo fades in 0→1 over first 400ms
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    // Name fades in after logo: 300ms–600ms
    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.4, curve: Curves.easeIn),
      ),
    );

    // Motto fades in: 500ms–900ms
    _mottoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.55, curve: Curves.easeIn),
      ),
    );

    // Trail glows in: 400ms–800ms
    _trailOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.5, curve: Curves.easeIn),
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
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Always dark splash regardless of system theme
    const bgColor = Color(0xFF0E0D0B);
    const accentOrange = Color(0xFFFF8A4C);
    const textWhite = Color(0xFFF5F1E8);
    const textDim = Color(0xFF8A8375);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Runner silhouette background
          Positioned.fill(
            child: CustomPaint(
              painter: _RunnerSilhouettePainter(
                silhouetteColor: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Orange trail arc at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.25,
            child: AnimatedBuilder(
              animation: _trailOpacity,
              builder: (context, child) {
                return Opacity(
                  opacity: _trailOpacity.value,
                  child: CustomPaint(
                    painter: _OrangeTrailPainter(
                      trailColor: accentOrange,
                    ),
                  ),
                );
              },
            ),
          ),

          // Main content
          SafeArea(
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, _) {
                  return Column(
                    children: [
                      const Spacer(flex: 3),

                      // Logo
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Image.asset(
                            'assets/images/logo_mark_orange.png',
                            width: 120,
                            height: 120,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.local_fire_department,
                              size: 80,
                              color: accentOrange,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // App name
                      Opacity(
                        opacity: _nameOpacity.value,
                        child: const Text(
                          'FitPilot',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: textWhite,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Motto: "Eat Better. Burn Smarter. Live Stronger"
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Opacity(
                          opacity: _mottoOpacity.value,
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textDim,
                                letterSpacing: 1.5,
                              ),
                              children: [
                                const TextSpan(text: 'EAT BETTER. '),
                                TextSpan(
                                  text: 'BURN SMARTER.',
                                  style: TextStyle(
                                    color: accentOrange,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        accentOrange.withValues(alpha: 0.5),
                                  ),
                                ),
                                const TextSpan(text: ' LIVE STRONGER'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a subtle runner silhouette in the right-center of the screen.
class _RunnerSilhouettePainter extends CustomPainter {
  final Color silhouetteColor;

  _RunnerSilhouettePainter({required this.silhouetteColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = silhouetteColor
      ..style = PaintingStyle.fill;

    // Stylized running figure silhouette — right side of screen
    final cx = size.width * 0.6;
    final cy = size.height * 0.42;
    final scale = size.height / 800;

    // Head
    canvas.drawCircle(
      Offset(cx + 10 * scale, cy - 120 * scale),
      22 * scale,
      paint,
    );

    // Torso
    final torso = Path()
      ..moveTo(cx - 5 * scale, cy - 95 * scale)
      ..lineTo(cx + 25 * scale, cy - 95 * scale)
      ..lineTo(cx + 15 * scale, cy - 20 * scale)
      ..lineTo(cx - 15 * scale, cy - 20 * scale)
      ..close();
    canvas.drawPath(torso, paint);

    // Left arm (extended forward)
    final leftArm = Path()
      ..moveTo(cx - 5 * scale, cy - 85 * scale)
      ..lineTo(cx - 50 * scale, cy - 60 * scale)
      ..lineTo(cx - 45 * scale, cy - 50 * scale)
      ..lineTo(cx, cy - 75 * scale)
      ..close();
    canvas.drawPath(leftArm, paint);

    // Right arm (extended backward)
    final rightArm = Path()
      ..moveTo(cx + 20 * scale, cy - 85 * scale)
      ..lineTo(cx + 60 * scale, cy - 55 * scale)
      ..lineTo(cx + 55 * scale, cy - 45 * scale)
      ..lineTo(cx + 15 * scale, cy - 75 * scale)
      ..close();
    canvas.drawPath(rightArm, paint);

    // Left leg (forward stride)
    final leftLeg = Path()
      ..moveTo(cx - 10 * scale, cy - 20 * scale)
      ..lineTo(cx - 55 * scale, cy + 60 * scale)
      ..lineTo(cx - 45 * scale, cy + 65 * scale)
      ..lineTo(cx, cy - 10 * scale)
      ..close();
    canvas.drawPath(leftLeg, paint);

    // Right leg (back stride)
    final rightLeg = Path()
      ..moveTo(cx + 10 * scale, cy - 20 * scale)
      ..lineTo(cx + 50 * scale, cy + 55 * scale)
      ..lineTo(cx + 40 * scale, cy + 60 * scale)
      ..lineTo(cx, cy - 10 * scale)
      ..close();
    canvas.drawPath(rightLeg, paint);
  }

  @override
  bool shouldRepaint(covariant _RunnerSilhouettePainter oldDelegate) => false;
}

/// Paints the orange glowing trail arc at the bottom of the splash screen.
class _OrangeTrailPainter extends CustomPainter {
  final Color trailColor;

  _OrangeTrailPainter({required this.trailColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Main trail arc
    final trailPaint = Paint()
      ..color = trailColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Sweeping arc from left-bottom to right
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.3,
      size.width * 0.7,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.6,
      size.width,
      size.height * 0.4,
    );
    canvas.drawPath(path, trailPaint);

    // Glow effect — wider, softer stroke behind
    final glowPaint = Paint()
      ..color = trailColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawPath(path, glowPaint);

    // Ambient glow at bottom-right
    final ambientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          trailColor.withValues(alpha: 0.12),
          trailColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.7),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      ambientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrangeTrailPainter oldDelegate) => false;
}

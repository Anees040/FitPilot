import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _timer;
  
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack)
    );
    
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn))
    );
    
    _logoController.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextIndex = (_currentIndex + 1) % 3;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Premium Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor,
                    theme.colorScheme.primary.withValues(alpha: 0.03),
                  ],
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Animated Logo Section
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          isDark ? 'assets/images/logo_mark_white.png' : 'assets/images/logo_mark_orange.png',
                          width: 80,
                          height: 80,
                          errorBuilder: (c, e, s) => Icon(Icons.local_fire_department, color: theme.colorScheme.primary, size: 80),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'FitPilot',
                        style: theme.textTheme.display.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          fontSize: 40,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Eat it. Burn it.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Carousel
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    children: [
                      _buildSlide(
                        theme,
                        ext,
                        title: 'Honest calorie ranges',
                        subtitle: '350-520 kcal — because nobody\nreally knows it\'s exactly 437.',
                        graphic: const _CalorieRangeGraphic(),
                      ),
                      _buildSlide(
                        theme,
                        ext,
                        title: 'Earn your meals',
                        subtitle: 'Convert your overeating directly\ninto concrete burn plans.',
                        graphic: const _BurnPlanGraphic(),
                      ),
                      _buildSlide(
                        theme,
                        ext,
                        title: 'Desi Food First',
                        subtitle: 'From Biryani to Gulab Jamun,\ntrack it all effortlessly.',
                        graphic: const _DesiFoodGraphic(),
                      ),
                    ],
                  ),
                ),
                
                // Page Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isActive = _currentIndex == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutQuint,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: isActive ? 32 : 8,
                      decoration: BoxDecoration(
                        color: isActive ? theme.colorScheme.primary : ext.hairline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 48),
                
                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PrimaryButton(
                    label: 'Get started',
                    onPressed: () {
                      context.push('/auth?mode=signup');
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SecondaryButton(
                    label: 'I already have an account',
                    onPressed: () {
                      context.push('/auth?mode=login');
                    },
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    context.go('/today');
                  },
                  child: Text(
                    'Continue without an account',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(ThemeData theme, AppColors ext, {required String title, required String subtitle, required Widget graphic}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          SizedBox(
            height: 180,
            child: graphic,
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _CalorieRangeGraphic extends StatefulWidget {
  const _CalorieRangeGraphic();

  @override
  State<_CalorieRangeGraphic> createState() => _CalorieRangeGraphicState();
}

class _CalorieRangeGraphicState extends State<_CalorieRangeGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _slideAnimation = Tween<double>(begin: -30, end: 30).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        final val = (435 + _slideAnimation.value).toInt();
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 100,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Transform.translate(
              offset: Offset(_slideAnimation.value, -40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: theme.shadowColor.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Text(
                  '$val',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_slideAnimation.value, -14),
              child: Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BurnPlanGraphic extends StatefulWidget {
  const _BurnPlanGraphic();

  @override
  State<_BurnPlanGraphic> createState() => _BurnPlanGraphicState();
}

class _BurnPlanGraphicState extends State<_BurnPlanGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: _controller.value,
                strokeWidth: 12,
                backgroundColor: ext.hairline,
                color: theme.colorScheme.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_run_rounded, size: 56, color: theme.colorScheme.primary),
            ),
          ],
        );
      },
    );
  }
}

class _DesiFoodGraphic extends StatelessWidget {
  const _DesiFoodGraphic();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 0,
          left: 20,
          child: _buildFoodBadge(theme, ext, isDark, 'Biryani', Icons.rice_bowl, -15),
        ),
        Positioned(
          top: 30,
          right: 20,
          child: _buildFoodBadge(theme, ext, isDark, 'Samosa', Icons.change_history, 10),
        ),
        Positioned(
          bottom: 20,
          child: _buildFoodBadge(theme, ext, isDark, 'Gulab Jamun', Icons.cookie, -5),
        ),
      ],
    );
  }

  Widget _buildFoodBadge(ThemeData theme, AppColors ext, bool isDark, String name, IconData icon, double angle) {
    return Transform.rotate(
      angle: angle * pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ext.hairline, width: 1.5),
          boxShadow: [
            BoxShadow(color: theme.shadowColor.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}


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

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                    theme.scaffoldBackgroundColor,
                    theme.colorScheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      isDark ? 'assets/images/logo_mark_white.png' : 'assets/images/logo_mark_orange.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (c, e, s) => Icon(Icons.local_fire_department, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FitPilot',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Eat it. Burn it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
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
                        subtitle: '350-520 kcal — because nobody\nreally knows it''s exactly 437.',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isActive = _currentIndex == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: isActive ? 24 : 8,
                      decoration: BoxDecoration(
                        color: isActive ? theme.colorScheme.primary : ext.hairline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PrimaryButton(
                    label: 'Get started',
                    onPressed: () {
                      context.push('/auth');
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SecondaryButton(
                    label: 'I already have an account',
                    onPressed: () {
                      context.push('/auth');
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
          const Spacer(),
          SizedBox(
            height: 200,
            child: graphic,
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
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
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 160,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              width: 80,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Transform.translate(
              offset: Offset(_slideAnimation.value, -30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: theme.shadowColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(
                  '\${(435 + _slideAnimation.value).toInt()}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_slideAnimation.value, -10),
              child: Container(
                width: 2,
                height: 20,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
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
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: _controller.value,
                strokeWidth: 8,
                backgroundColor: ext.hairline,
                color: theme.colorScheme.primary,
              ),
            ),
            Icon(Icons.directions_run_rounded, size: 48, color: theme.colorScheme.primary),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFoodBadge(theme, ext, isDark, 'Biryani', Icons.rice_bowl, -15),
            const SizedBox(width: 16),
            _buildFoodBadge(theme, ext, isDark, 'Samosa', Icons.change_history, 10),
          ],
        ),
        Positioned(
          bottom: 20,
          child: _buildFoodBadge(theme, ext, isDark, 'Gulab Jamun', Icons.cookie, 0),
        )
      ],
    );
  }

  Widget _buildFoodBadge(ThemeData theme, AppColors ext, bool isDark, String name, IconData icon, double angle) {
    return Transform.rotate(
      angle: angle * pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.hairline),
          boxShadow: [
            BoxShadow(color: theme.shadowColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

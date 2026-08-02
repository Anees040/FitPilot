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

  static const int _totalPages = 4;

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentIndex < _totalPages - 1) {
      _goToPage(_currentIndex + 1);
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _goToPage(_currentIndex - 1);
    }
  }

  /// Skip always skips to the main welcome page (index 3)
  void _skipToMainWelcome() {
    _goToPage(3);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMainWelcome = _currentIndex == 3;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: [
                  const _FeaturePage(
                    imagePath: 'assets/illustrations/log_meals.png',
                    title: 'Log meals honestly',
                    subtitle: 'We show calorie ranges, not\nfalse precision.',
                  ),
                  const _FeaturePage(
                    imagePath: 'assets/illustrations/burn_smart.png',
                    title: 'Burn smarter',
                    subtitle:
                        'Get personalized burn plans\nbased on your surplus and equipment.',
                  ),
                  const _FeaturePage(
                    imagePath: 'assets/illustrations/streak_flame.png',
                    title: 'Protect your streak',
                    subtitle:
                        'Cheat today? Burn tomorrow.\nKeep your streak alive.',
                  ),
                  _WelcomePage(
                    onCreateAccount: () => context.push('/auth?mode=signup'),
                    onGuest: () => context.go('/today'),
                    onLogin: () => context.push('/auth?mode=login'),
                  ),
                ],
              ),
            ),

            // Top Bar overlaid
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: isMainWelcome,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isMainWelcome ? 0.0 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        // Dot indicators
                        Expanded(
                          child: Row(
                            children: List.generate(3, (i) {
                              final isActive = _currentIndex == i;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: isActive ? 12 : 8,
                                  height: isActive ? 12 : 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.15),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        // Skip button
                        GestureDetector(
                          onTap: _skipToMainWelcome,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Skip',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Bar overlaid
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: isMainWelcome,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isMainWelcome ? 0.0 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        // Back arrow
                        if (_currentIndex > 0)
                          GestureDetector(
                            onTap: _prevPage,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_back,
                                size: 20,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48, height: 48),

                        const Spacer(),

                        // Next / Get Started button
                        SizedBox(
                          width: 160,
                          child: PrimaryButton(
                            label: _currentIndex == 2 ? 'Get Started' : 'Next',
                            onPressed: _currentIndex == 2
                                ? _skipToMainWelcome
                                : _nextPage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// MAIN WELCOME PAGE (Page 3)
// =============================================================

class _WelcomePage extends StatelessWidget {
  final VoidCallback onCreateAccount;
  final VoidCallback onGuest;
  final VoidCallback onLogin;

  const _WelcomePage({
    required this.onCreateAccount,
    required this.onGuest,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // "Welcome to" + "FitPilot"
          Text(
            'Welcome to',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 36,
              color: theme.colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          Text(
            'FitPilot',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 36,
              color: theme.colorScheme.primary,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Your smart companion for\nhonest tracking and real results.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Hero illustration
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageSize = constraints.maxHeight < constraints.maxWidth
                      ? constraints.maxHeight * 0.95
                      : constraints.maxWidth * 0.95;
                  return Image.asset(
                    'assets/illustrations/welcome_hero.png',
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Icon(
                      Icons.restaurant,
                      size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Create Account button
          PrimaryButton(
            label: 'Create Account',
            onPressed: onCreateAccount,
          ),

          const SizedBox(height: 12),

          // Continue as Guest button (outlined)
          _OutlinedButton(
            label: 'Continue as Guest',
            onPressed: onGuest,
          ),

          const SizedBox(height: 16),

          // Already have an account? Login
          Center(
            child: GestureDetector(
              onTap: onLogin,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account?  '),
                      TextSpan(
                        text: 'Login',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// =============================================================
// FEATURE PAGES (Pages 0-2)
// =============================================================

class _FeaturePage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;

  const _FeaturePage({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 72), // Space for top nav bar

          // Illustration image
          Expanded(
            child: Center(
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Icon(
                  Icons.image_outlined,
                  size: 80,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            title,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 28,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 96), // Space for bottom nav bar
        ],
      ),
    );
  }
}

// =============================================================
// SHARED WIDGETS
// =============================================================

/// Outlined secondary-style button (hairline border, no fill)
class _OutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _OutlinedButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScaleButton(
      onPressed: onPressed,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: theme.extension<AppColors>()!.hairline, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface, // Force black text on white bg
          ),
        ),
      ),
    );
  }
}

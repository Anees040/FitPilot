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

  final List<_SlideData> _slides = [
    _SlideData(
      title: 'Honest calorie ranges',
      description:
          'Stop guessing. We show you a realistic range for every meal, complete with confidence levels.',
      illustration: Icons.restaurant,
    ),
    _SlideData(
      title: 'Overeat? Burn it.',
      description:
          'Over your limit? We give you concrete burn plans tailored to your equipment.',
      illustration: Icons.local_fire_department,
    ),
    _SlideData(
      title: 'Works offline. Free.',
      description:
          'Your data stays on your device. Burn off yesterday\'s surplus to keep your streak alive.',
      illustration: Icons.verified,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.illustration, size: 80, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          slide.title,
                          style: theme.textTheme.h1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.description,
                          style: theme.textTheme.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == index
                        ? theme.colorScheme.primary
                        : ext.hairline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Create your account',
                    onPressed: () => context.push('/signup'),
                  ),
                  const SizedBox(height: 8),
                  TertiaryButton(
                    label: 'Log in',
                    onPressed: () => context.push('/signin'),
                  ),
                  // Hidden guest access for testing, not in primary UI
                  GestureDetector(
                    onDoubleTap: () => context.go('/today'),
                    child: const SizedBox(height: 16, width: 44),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final String title;
  final String description;
  final IconData illustration;

  _SlideData({
    required this.title,
    required this.description,
    required this.illustration,
  });
}

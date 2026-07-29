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
      headline: 'Honest calorie ranges',
      support: '350–520 kcal — because nobody really knows it\'s exactly 437.',
      illustration: 'range_slider.png',
    ),
    _SlideData(
      headline: 'Overeat? Burn it.',
      support: 'Go over and FitPilot gives you real options: a 34 min walk or 13 min of jump rope.',
      illustration: 'walker_rope.png',
    ),
    _SlideData(
      headline: 'Works offline. Free.',
      support: 'Log anywhere. Everything syncs when you\'re back online.',
      illustration: 'phone_check.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _skip() {
    context.go('/today'); // Skip directly to app
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    // UI_SPEC: Top to bottom: logo 96 dp (radius 24) at ~12% height; "FitPilot" 32/w800; 
    // "Eat it. Burn it." 15 textSecondary; flexible hero illustration area; 
    // headline 28/w700 centered; support line 16 textSecondary, max 2 lines; 
    // page dots (active = 24x6 accent pill); PrimaryButton "Get started"; 
    // SecondaryButton "I already have an account"; TertiaryButton "Continue without an account".

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section (Fixed)
            Padding(
              padding: const EdgeInsets.only(top: 32.0, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 48), // spacer to balance skip button
                  Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/logo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Fallback if logo not found
                        child: Image.asset('assets/images/logo.png', errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(Icons.fitness_center, size: 48, color: theme.colorScheme.primary),
                        )),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'FitPilot',
                        style: theme.textTheme.display,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Eat it. Burn it.',
                        style: theme.textTheme.body.copyWith(color: theme.textTheme.caption.color),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.textTheme.caption.color,
                      textStyle: theme.textTheme.bodyStrong,
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Middle Section (Swipeable)
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 200),
                            child: Image.asset(
                              'assets/illustrations/${slide.illustration}',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: 100, color: ext.hairline),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.headline,
                          style: theme.textTheme.display.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.support,
                          style: theme.textTheme.body.copyWith(color: theme.textTheme.caption.color, fontSize: 16),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Page Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 24 : 8,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == index
                        ? theme.colorScheme.primary
                        : ext.hairline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Bottom Section (Fixed Buttons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Get started',
                    onPressed: () => context.push('/signup'),
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'I already have an account',
                    onPressed: () => context.push('/signin'),
                  ),
                  const SizedBox(height: 4),
                  TertiaryButton(
                    label: 'Continue without an account',
                    onPressed: _skip,
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
  final String headline;
  final String support;
  final String illustration;

  _SlideData({
    required this.headline,
    required this.support,
    required this.illustration,
  });
}

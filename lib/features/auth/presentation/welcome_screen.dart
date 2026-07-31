import 'dart:async';
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
  bool _isInteracting = false;

  final List<_SlideData> _slides = [
    _SlideData(
      headline: 'Log food in seconds',
      support: 'Scan, snap or search.',
      illustration: 'range_slider.png', // Or update to match "scan" if you prefer, but sticking to existing assets
    ),
    _SlideData(
      headline: 'See your day at a glance',
      support: 'Ate extra? Burn it your way.',
      illustration: 'walker_rope.png',
    ),
    _SlideData(
      headline: 'Works offline. Free.',
      support: 'Log anywhere. Everything syncs when you\'re back online.',
      illustration: 'phone_check.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    if (!mounted) return;
    
    if (MediaQuery.disableAnimationsOf(context)) {
      return; // Respect reduced motion
    }

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_isInteracting || !mounted) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentIndex + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _stopTimer();
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section (Skip button)
            Padding(
              padding: const EdgeInsets.only(top: 16.0, right: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.caption.color,
                    textStyle: theme.textTheme.bodyStrong,
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),
            
            // Middle Section (Swipeable with parallax)
            Expanded(
              child: GestureDetector(
                onPanDown: (_) => _isInteracting = true,
                onPanCancel: () => _isInteracting = false,
                onPanEnd: (_) => _isInteracting = false,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double pageOffset = 0.0;
                        if (_pageController.position.haveDimensions) {
                          pageOffset = _pageController.page! - index;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 200),
                                  child: Transform.translate(
                                    offset: Offset(pageOffset * 100, 0), // Parallax effect
                                    child: Image.asset(
                                      'assets/illustrations/${slide.illustration}',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Icon(Icons.image_not_supported, size: 100, color: ext.hairline),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Transform.translate(
                                offset: Offset(pageOffset * 50, 0),
                                child: Text(
                                  slide.headline,
                                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Transform.translate(
                                offset: Offset(pageOffset * 25, 0),
                                child: Text(
                                  slide.support,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.caption.color, fontSize: 16),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
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

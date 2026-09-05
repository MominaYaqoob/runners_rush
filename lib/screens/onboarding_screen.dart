import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/screens/consent_screen.dart';
import 'package:runners_rush/services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.heading,
    required this.subtext,
    required this.imageAsset,
  });

  final String heading;
  final String subtext;
  final String imageAsset;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const _slides = [
    _OnboardingSlide(
      imageAsset: 'assets/images/onboarding_1_run.png',
      heading: 'Run & Escape',
      subtext: 'Dash through the wild and dodge every obstacle in your path',
    ),
    _OnboardingSlide(
      imageAsset: 'assets/images/onboarding_2_jump.png',
      heading: 'Jump at the Right Time',
      subtext: 'Tap to leap over obstacles — timing is everything',
    ),
    _OnboardingSlide(
      imageAsset: 'assets/images/onboarding_3_win.png',
      heading: 'Beat Your High Score',
      subtext: 'Challenge yourself and climb to the top of the leaderboard',
    ),
  ];

  late final PageController _pageController;
  int _currentPage = 0;

  bool get _isLastSlide => _currentPage == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goConsent() async {
    await OnboardingService.markOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: AppRoutes.consent),
        transitionDuration: const Duration(milliseconds: 560),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const ConsentScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.07),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/background_evening.png',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x59000000),
                    Color(0x59000000),
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  children: [
                    _TopBar(
                      showSkip: !_isLastSlide,
                      showGetStarted: _isLastSlide,
                      onSkip: _goConsent,
                      onGetStarted: _goConsent,
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          return _SlidePage(slide: _slides[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DotIndicators(
                      count: _slides.length,
                      currentIndex: _currentPage,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showSkip,
    required this.showGetStarted,
    required this.onSkip,
    required this.onGetStarted,
  });

  final bool showSkip;
  final bool showGetStarted;
  final VoidCallback onSkip;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: showGetStarted
              ? _GetStartedButton(onPressed: onGetStarted)
              : showSkip
                  ? _GlassSkipButton(onPressed: onSkip)
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _GlassSkipButton extends StatelessWidget {
  const _GlassSkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('skip'),
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              'Skip',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Pixel-art is ~120px intrinsic; scale to fill most of the slide
          // (~2.5–3× the old 160px glow / tiny intrinsic render).
          final illustrationHeight =
              (constraints.maxHeight * 0.92).clamp(300.0, 560.0);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 45,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Align(
                    alignment: Alignment.center,
                    child: _SlideIllustration(
                      asset: slide.imageAsset,
                      height: illustrationHeight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 55,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.heading,
                          style: GoogleFonts.baloo2(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            slide.subtext,
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlideIllustration extends StatelessWidget {
  const _SlideIllustration({
    required this.asset,
    required this.height,
  });

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final glowSize = height * 0.72;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: const Color(0xFFFF8A3D).withValues(alpha: 0.28),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Image.asset(
            asset,
            height: height,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            alignment: Alignment.center,
          ),
        ],
      ),
    );
  }
}

class _DotIndicators extends StatelessWidget {
  const _DotIndicators({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('get-started'),
      onTap: onPressed,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF8A3D), Color(0xFF6B3FA0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B3FA0).withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get Started',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

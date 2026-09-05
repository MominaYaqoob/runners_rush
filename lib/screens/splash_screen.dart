import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/screens/consent_screen.dart';
import 'package:runners_rush/screens/home_screen.dart';
import 'package:runners_rush/screens/onboarding_screen.dart';
import 'package:runners_rush/services/onboarding_service.dart';
import 'package:runners_rush/services/shop_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const _defaultBackgroundAsset =
      'assets/images/background_evening.png';
  static const _introDuration = Duration(seconds: 3);
  static const _navigateAfter = Duration(seconds: 5);
  static const _routeFadeDuration = Duration(milliseconds: 600);

  late final AnimationController _introController;
  late final AnimationController _pulseController;
  Timer? _navigationTimer;

  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _taglineOpacity;

  String _backgroundAsset = _defaultBackgroundAsset;

  @override
  void initState() {
    super.initState();
    _setEdgeToEdge();
    _loadBackground();

    _introController = AnimationController(
      vsync: this,
      duration: _introDuration,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    // Icon: first 1s — fade + elastic scale.
    _iconOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 1 / 3, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 1 / 3, curve: Curves.elasticOut),
      ),
    );

    // Title slightly after the icon starts.
    _titleOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.12, 0.38, curve: Curves.easeOut),
    );

    // Tagline after the icon animation.
    _taglineOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.32, 0.52, curve: Curves.easeOut),
    );

    _introController.forward();
    _navigationTimer = Timer(_navigateAfter, _continueAfterSplash);
  }

  Future<void> _loadBackground() async {
    final path = await ShopService.getSelectedBackgroundAssetPath();
    if (!mounted) return;
    final asset = 'assets/images/$path';
    if (asset == _backgroundAsset) return;
    setState(() => _backgroundAsset = asset);
  }

  Future<void> _setEdgeToEdge() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  }

  Future<void> _continueAfterSplash() async {
    if (!mounted) return;
    _pulseController.stop();

    final firstLaunchDone = await OnboardingService.hasCompletedFirstLaunch();
    if (!mounted) return;
    if (firstLaunchDone) {
      _fadeTo(
        name: AppRoutes.home,
        page: const HomeScreen(),
      );
      return;
    }

    final onboardingDone = await OnboardingService.isOnboardingCompleted();
    if (!mounted) return;
    if (onboardingDone) {
      _fadeTo(
        name: AppRoutes.consent,
        page: const ConsentScreen(),
      );
      return;
    }

    _fadeTo(
      name: AppRoutes.onboarding,
      page: const OnboardingScreen(),
    );
  }

  void _fadeTo({required String name, required Widget page}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: name),
        opaque: false,
        transitionDuration: _routeFadeDuration,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
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
              _backgroundAsset,
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.78,
                  colors: [
                    Color(0x99000000),
                    Color(0x59000000),
                    Color(0x33000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _BrandBlock(
                    iconOpacity: _iconOpacity,
                    iconScale: _iconScale,
                    titleOpacity: _titleOpacity,
                    taglineOpacity: _taglineOpacity,
                  ),
                  const Spacer(flex: 2),
                  _PulsingDots(animation: _pulseController),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({
    required this.iconOpacity,
    required this.iconScale,
    required this.titleOpacity,
    required this.taglineOpacity,
  });

  final Animation<double> iconOpacity;
  final Animation<double> iconScale;
  final Animation<double> titleOpacity;
  final Animation<double> taglineOpacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: iconOpacity,
          child: ScaleTransition(
            scale: iconScale,
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeTransition(
          opacity: titleOpacity,
          child: Text(
            'Runners Rush',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.2,
              height: 1.1,
              shadows: const [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        FadeTransition(
          opacity: taglineOpacity,
          child: Text(
            'Run. Jump. Survive.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingDots extends StatelessWidget {
  const _PulsingDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final t = (animation.value + index * 0.22) % 1.0;
            final pulse = 1 - (2 * t - 1).abs();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Opacity(
                opacity: 0.28 + (pulse * 0.72),
                child: Transform.scale(
                  scale: 0.82 + (pulse * 0.18),
                  child: child,
                ),
              ),
            );
          }),
        );
      },
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: 8, height: 8),
      ),
    );
  }
}

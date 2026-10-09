import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/ads/ads_service.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/services/onboarding_service.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const _hudFill = Color(0xE62A1A3A);
  static const _hudBorder = Color(0x38FFFFFF);
  static const _linkColor = Color(0xFFFF8A3D);

  bool _agreed = false;

  void _openTerms() {
    Navigator.pushNamed(context, AppRoutes.termsOfService);
  }

  void _openPrivacy() {
    Navigator.pushNamed(context, AppRoutes.privacyPolicy);
  }

  Future<void> _continue() async {
    if (!_agreed) return;
    await OnboardingService.markConsentAccepted();
    unawaited(AdsService.ensureInitialized());
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home);
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
            // Fixed evening: consent runs before any shop purchase/theme pick.
            Image.asset(
              'assets/images/background_evening.png',
              fit: BoxFit.cover,
            ),
            const ColoredBox(color: Color(0x80000000)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                      decoration: BoxDecoration(
                        color: _hudFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _hudBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x73000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Before You Start',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'By continuing, you agree to our ',
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: _openTerms,
                                    child: Text(
                                      'Terms of Service',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _linkColor,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _linkColor,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: _openPrivacy,
                                    child: Text(
                                      'Privacy Policy',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _linkColor,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _linkColor,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => setState(() => _agreed = !_agreed),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Checkbox(
                                    value: _agreed,
                                    onChanged: (value) {
                                      setState(() => _agreed = value ?? false);
                                    },
                                    activeColor: const Color(0xFFFF8A3D),
                                    checkColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'I have read and agree to the above',
                                    style: GoogleFonts.baloo2(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: _agreed ? _continue : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                gradient: _agreed
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFF8A3D),
                                          Color(0xFF6B3FA0),
                                        ],
                                      )
                                    : null,
                                color: _agreed
                                    ? null
                                    : Colors.white.withValues(alpha: 0.18),
                              ),
                              child: Text(
                                'Continue',
                                style: GoogleFonts.baloo2(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(
                                    alpha: _agreed ? 1 : 0.45,
                                  ),
                                  letterSpacing: 0.4,
                                  height: 1,
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
            ),
          ],
        ),
      ),
    );
  }
}

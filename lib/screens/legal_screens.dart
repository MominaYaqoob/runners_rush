import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runners_rush/ui/hud_style.dart';
import 'package:runners_rush/widgets/themed_background.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Privacy Policy',
      body: _privacyBody,
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Terms of Service',
      body: _termsBody,
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  void _onBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
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
            const ThemedBackground(
              child: ColoredBox(color: Color(0x66000000)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => _onBack(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HudStyle.fill,
                                  border: Border.all(
                                    color: HudStyle.borderColor,
                                  ),
                                  boxShadow: HudStyle.shadow,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          Text(title, style: HudStyle.title(size: 22)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: HudStyle.panel(),
                        child: SingleChildScrollView(
                          child: Text(
                            body,
                            style: HudStyle.body(
                              size: 14,
                              weight: FontWeight.w500,
                            ).copyWith(
                              height: 1.45,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                    ),
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

const _privacyBody = '''
Last updated: October 9, 2026

Runners Rush ("we", "our", or "the app") respects your privacy. This Privacy Policy explains what information the app may collect and how it is used.

1. Information we collect
• Local gameplay data such as high scores, coins, unlocked items, and settings stored on your device.
• Advertising identifiers and diagnostic data when ads are shown, processed by Google Mobile Ads / AdMob according to your consent choices.
• Approximate device information needed to serve ads and keep the app stable (for example device type and OS version).

2. How we use information
• To save your progress and preferences on this device.
• To show personalized or non-personalized ads based on your consent.
• To measure ad performance and improve app reliability.

3. Ads and consent
On supported regions we may show a consent form (UMP) before personalized ads. You can open privacy options from Settings when required by law. You can reset advertising preferences through your device settings.

4. Data storage
Gameplay progress is stored locally with SharedPreferences on your device. We do not operate a Runners Rush account system or cloud save in this version.

5. Third parties
Google Mobile Ads / AdMob and related Google services may process data under their own policies when ads are loaded or shown.

6. Children
Runners Rush is intended for a general audience. Do not use the app if you are not permitted to under applicable law.

7. Changes
We may update this Privacy Policy. Continued use of the app after an update means you accept the revised policy.

8. Contact
For privacy questions about Runners Rush, contact the developer using the store listing support channel for this app.
''';

const _termsBody = '''
Last updated: October 9, 2026

Welcome to Runners Rush. By downloading, installing, or using the app, you agree to these Terms of Service.

1. License
We grant you a personal, non-exclusive, non-transferable license to use Runners Rush on devices you own or control, solely for entertainment.

2. Virtual items
Coins, characters, backgrounds, and other in-app items have no real-world cash value. They may be reset, adjusted, or removed if we update the game. Purchased or earned items are licensed, not sold.

3. Acceptable use
You agree not to cheat, reverse engineer, disrupt services, or use the app in any unlawful way.

4. Ads
The free version may display advertisements. Ad availability and frequency may change. Rewarded ads are optional and may grant in-game benefits when completed successfully.

5. Disclaimer
The app is provided "as is" without warranties of any kind. We do not guarantee uninterrupted or error-free play.

6. Limitation of liability
To the maximum extent permitted by law, we are not liable for indirect, incidental, or consequential damages arising from use of the app.

7. Termination
Your license ends if you stop using the app or if we discontinue it. Sections that by nature should survive (disclaimer, liability limits) will survive.

8. Changes
We may update these Terms. Continued use after changes means you accept the new Terms.

9. Contact
For questions about these Terms, contact the developer using the store listing support channel for this app.
''';

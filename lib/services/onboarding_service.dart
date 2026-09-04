import 'package:shared_preferences/shared_preferences.dart';

/// Tracks first-launch funnel: onboarding → consent → home.
class OnboardingService {
  static const _onboardingDoneKey = 'onboarding_completed';
  static const _consentDoneKey = 'consent_accepted';

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
  }

  static Future<bool> isConsentAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentDoneKey) ?? false;
  }

  static Future<void> markConsentAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentDoneKey, true);
    // Consent is the last first-launch step — treat onboarding as done too.
    await prefs.setBool(_onboardingDoneKey, true);
  }

  /// True when the user has finished consent (return users skip the funnel).
  static Future<bool> hasCompletedFirstLaunch() async {
    return isConsentAccepted();
  }
}

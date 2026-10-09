/// Pure frequency / expiry rules for ads (injectable clock for unit tests).
class AdsPolicy {
  AdsPolicy({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const interstitialCooldown = Duration(minutes: 3);
  static const interstitialMaxAge = Duration(minutes: 55);
  static const appOpenMaxAge = Duration(hours: 3, minutes: 50);
  static const appOpenMinBackground = Duration(seconds: 15);
  static const appOpenShowCooldown = Duration(minutes: 3);

  DateTime get now => _now();

  /// After [triggerCount] is incremented for this Restart/Home tap.
  /// Skips the first trigger ever (count == 1), then every 2nd with cooldown.
  bool shouldShowInterstitial({
    required int triggerCount,
    required DateTime? lastShownAt,
  }) {
    if (triggerCount <= 0) return false;
    // Very first trigger of a brand-new install.
    if (triggerCount == 1) return false;
    if (triggerCount % 2 != 0) return false;
    if (lastShownAt != null &&
        now.difference(lastShownAt) < interstitialCooldown) {
      return false;
    }
    return true;
  }

  /// Whether the *next* trigger (currentCount + 1) would show — used to preload.
  bool willNextInterstitialShow({
    required int currentTriggerCount,
    required DateTime? lastShownAt,
  }) {
    return shouldShowInterstitial(
      triggerCount: currentTriggerCount + 1,
      lastShownAt: lastShownAt,
    );
  }

  bool isInterstitialExpired(DateTime? loadedAt) {
    if (loadedAt == null) return true;
    return now.difference(loadedAt) > interstitialMaxAge;
  }

  bool isAppOpenExpired(DateTime? loadedAt) {
    if (loadedAt == null) return true;
    return now.difference(loadedAt) > appOpenMaxAge;
  }

  /// Cold start App Open: skip first process session after install.
  bool shouldShowAppOpenOnColdStart({
    required int installSessionCount,
    required bool onboardingComplete,
    required bool adLoaded,
  }) {
    if (!onboardingComplete || !adLoaded) return false;
    if (installSessionCount <= 1) return false;
    return true;
  }

  bool shouldShowAppOpenOnResume({
    required Duration backgroundDuration,
    required DateTime? lastShownAt,
    required bool gameplayActive,
    required bool isFullScreenAdShowing,
  }) {
    if (gameplayActive || isFullScreenAdShowing) return false;
    if (backgroundDuration < appOpenMinBackground) return false;
    if (lastShownAt != null &&
        now.difference(lastShownAt) < appOpenShowCooldown) {
      return false;
    }
    return true;
  }
}

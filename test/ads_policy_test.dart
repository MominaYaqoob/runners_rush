import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/ads/ads_policy.dart';

void main() {
  late DateTime now;
  late AdsPolicy policy;

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
    policy = AdsPolicy(now: () => now);
  });

  group('interstitial', () {
    test('skips the first trigger of a brand-new install', () {
      expect(
        policy.shouldShowInterstitial(triggerCount: 1, lastShownAt: null),
        isFalse,
      );
    });

    test('shows on every 2nd trigger after the first', () {
      expect(
        policy.shouldShowInterstitial(triggerCount: 2, lastShownAt: null),
        isTrue,
      );
      expect(
        policy.shouldShowInterstitial(triggerCount: 3, lastShownAt: null),
        isFalse,
      );
      expect(
        policy.shouldShowInterstitial(triggerCount: 4, lastShownAt: null),
        isTrue,
      );
    });

    test('enforces 3 minute cooldown', () {
      final last = now.subtract(const Duration(minutes: 2));
      expect(
        policy.shouldShowInterstitial(triggerCount: 2, lastShownAt: last),
        isFalse,
      );
      now = now.add(const Duration(minutes: 2));
      expect(
        policy.shouldShowInterstitial(triggerCount: 2, lastShownAt: last),
        isTrue,
      );
    });

    test('willNextInterstitialShow matches upcoming trigger rules', () {
      expect(
        policy.willNextInterstitialShow(
          currentTriggerCount: 0,
          lastShownAt: null,
        ),
        isFalse, // next is 1 → first skip
      );
      expect(
        policy.willNextInterstitialShow(
          currentTriggerCount: 1,
          lastShownAt: null,
        ),
        isTrue, // next is 2
      );
      expect(
        policy.willNextInterstitialShow(
          currentTriggerCount: 2,
          lastShownAt: null,
        ),
        isFalse, // next is 3
      );
    });

    test('interstitial expires after 55 minutes', () {
      final loaded = now;
      expect(policy.isInterstitialExpired(loaded), isFalse);
      now = now.add(const Duration(minutes: 56));
      expect(policy.isInterstitialExpired(loaded), isTrue);
    });
  });

  group('app open', () {
    test('expires after 3h50m', () {
      final loaded = now;
      expect(policy.isAppOpenExpired(loaded), isFalse);
      now = now.add(const Duration(hours: 3, minutes: 49));
      expect(policy.isAppOpenExpired(loaded), isFalse);
      now = now.add(const Duration(minutes: 2));
      expect(policy.isAppOpenExpired(loaded), isTrue);
    });

    test('cold start skips first install session', () {
      expect(
        policy.shouldShowAppOpenOnColdStart(
          installSessionCount: 1,
          onboardingComplete: true,
          adLoaded: true,
        ),
        isFalse,
      );
      expect(
        policy.shouldShowAppOpenOnColdStart(
          installSessionCount: 2,
          onboardingComplete: true,
          adLoaded: true,
        ),
        isTrue,
      );
      expect(
        policy.shouldShowAppOpenOnColdStart(
          installSessionCount: 2,
          onboardingComplete: false,
          adLoaded: true,
        ),
        isFalse,
      );
    });

    test('resume needs 15s background and 3 min cooldown', () {
      expect(
        policy.shouldShowAppOpenOnResume(
          backgroundDuration: const Duration(seconds: 10),
          lastShownAt: null,
          gameplayActive: false,
          isFullScreenAdShowing: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldShowAppOpenOnResume(
          backgroundDuration: const Duration(seconds: 15),
          lastShownAt: null,
          gameplayActive: false,
          isFullScreenAdShowing: false,
        ),
        isTrue,
      );
      final last = now.subtract(const Duration(minutes: 2));
      expect(
        policy.shouldShowAppOpenOnResume(
          backgroundDuration: const Duration(seconds: 20),
          lastShownAt: last,
          gameplayActive: false,
          isFullScreenAdShowing: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldShowAppOpenOnResume(
          backgroundDuration: const Duration(seconds: 20),
          lastShownAt: null,
          gameplayActive: true,
          isFullScreenAdShowing: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldShowAppOpenOnResume(
          backgroundDuration: const Duration(seconds: 20),
          lastShownAt: null,
          gameplayActive: false,
          isFullScreenAdShowing: true,
        ),
        isFalse,
      );
    });
  });
}

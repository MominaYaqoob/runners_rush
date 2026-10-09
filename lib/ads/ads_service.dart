import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:runners_rush/ads/ad_unit_ids.dart';
import 'package:runners_rush/ads/ads_policy.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mobile Ads + UMP. Never init from [main]; call [ensureInitialized] after consent.
class AdsService with WidgetsBindingObserver {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const _prefsSessionCount = 'ads_install_session_count';
  static const _prefsInterstitialTriggers = 'ads_interstitial_trigger_count';
  static const _prefsInterstitialLastShown = 'ads_interstitial_last_shown_ms';
  static const _prefsAppOpenLastShown = 'ads_app_open_last_shown_ms';
  static const _prefsRewardDay = 'ads_reward_day';
  static const _prefsRewardCount = 'ads_reward_count';

  static const _consentTimeout = Duration(seconds: 8);
  static const _mobileAdsTimeout = Duration(seconds: 12);
  static const _rewardedLoadTimeout = Duration(seconds: 7);
  static const _onlineLookupTimeout = Duration(seconds: 2);

  static bool gameplayActive = false;
  static bool isFullScreenAdShowing = false;

  static final AdsPolicy policy = AdsPolicy();

  static Future<void>? _initFuture;
  static bool _lifecycleObserverRegistered = false;
  static bool _sessionCounted = false;

  static AppOpenAd? _appOpenAd;
  static DateTime? _appOpenLoadedAt;
  static bool _appOpenLoading = false;

  static InterstitialAd? _interstitialAd;
  static DateTime? _interstitialLoadedAt;
  static bool _interstitialLoading = false;

  static RewardedAd? _rewardedAd;
  static Completer<RewardedAd?>? _rewardedLoadGate;

  static DateTime? _backgroundedAt;

  static bool get _inWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  static bool get adsAllowed => !_inWidgetTest;

  /// Idempotent: UMP → MobileAds → preload App Open. Never throws to callers.
  static Future<void> ensureInitialized() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  static Future<void> _doInit() async {
    if (_inWidgetTest) return;
    try {
      await _bumpInstallSessionOnce();
      _registerLifecycleObserver();
      await _runConsentFlow().timeout(_consentTimeout, onTimeout: () {});
      await MobileAds.instance
          .initialize()
          .timeout(_mobileAdsTimeout, onTimeout: () => InitializationStatus({}));
      await preloadAppOpen();
      // Cold-start App Open after preload settles.
      unawaited(_maybeShowAppOpenColdStart());
    } catch (_) {}
  }

  static Future<void> _bumpInstallSessionOnce() async {
    if (_sessionCounted) return;
    _sessionCounted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_prefsSessionCount) ?? 0) + 1;
      await prefs.setInt(_prefsSessionCount, next);
    } catch (_) {}
  }

  static void _registerLifecycleObserver() {
    if (_lifecycleObserverRegistered || _inWidgetTest) return;
    _lifecycleObserverRegistered = true;
    WidgetsBinding.instance.addObserver(instance);
  }

  static Future<void> _runConsentFlow() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!completer.isCompleted) completer.complete();
        });
      },
      (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  static Future<bool> isOnline() async {
    if (_inWidgetTest) return false;
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(_onlineLookupTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // --- App Open ---

  static Future<void> preloadAppOpen() async {
    if (!adsAllowed || _appOpenLoading) return;
    if (_appOpenAd != null &&
        !policy.isAppOpenExpired(_appOpenLoadedAt)) {
      return;
    }
    if (!await isOnline()) return;
    _discardAppOpen();
    _appOpenLoading = true;
    try {
      await AppOpenAd.load(
        adUnitId: AdUnitIds.appOpen,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _appOpenLoadedAt = policy.now;
            _appOpenLoading = false;
          },
          onAdFailedToLoad: (_) {
            _appOpenLoading = false;
            _discardAppOpen();
          },
        ),
      );
    } catch (_) {
      _appOpenLoading = false;
      _discardAppOpen();
    }
  }

  static void _discardAppOpen() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenLoadedAt = null;
  }

  static Future<void> _maybeShowAppOpenColdStart() async {
    if (!adsAllowed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = prefs.getInt(_prefsSessionCount) ?? 0;
      final onboarded = await OnboardingService.hasCompletedFirstLaunch();
      final loaded = _appOpenAd != null &&
          !policy.isAppOpenExpired(_appOpenLoadedAt);
      if (!policy.shouldShowAppOpenOnColdStart(
        installSessionCount: sessions,
        onboardingComplete: onboarded,
        adLoaded: loaded,
      )) {
        return;
      }
      await _showAppOpenInternal();
    } catch (_) {}
  }

  static Future<void> _maybeShowAppOpenOnResume() async {
    if (!adsAllowed) return;
    final bgAt = _backgroundedAt;
    if (bgAt == null) return;
    final bgDuration = policy.now.difference(bgAt);
    _backgroundedAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_prefsAppOpenLastShown);
      final lastShown =
          lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
      final loaded = _appOpenAd != null &&
          !policy.isAppOpenExpired(_appOpenLoadedAt);
      if (!loaded) {
        unawaited(preloadAppOpen());
        return;
      }
      if (!policy.shouldShowAppOpenOnResume(
        backgroundDuration: bgDuration,
        lastShownAt: lastShown,
        gameplayActive: gameplayActive,
        isFullScreenAdShowing: isFullScreenAdShowing,
      )) {
        return;
      }
      await _showAppOpenInternal();
    } catch (_) {}
  }

  static Future<void> _showAppOpenInternal() async {
    final ad = _appOpenAd;
    if (ad == null || isFullScreenAdShowing || gameplayActive) return;
    if (policy.isAppOpenExpired(_appOpenLoadedAt)) {
      _discardAppOpen();
      unawaited(preloadAppOpen());
      return;
    }
    isFullScreenAdShowing = true;
    unawaited(AudioService.pauseBgm());
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _appOpenLoadedAt = null;
        isFullScreenAdShowing = false;
        unawaited(_onFullScreenAdClosed());
        unawaited(preloadAppOpen());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _appOpenAd = null;
        _appOpenLoadedAt = null;
        isFullScreenAdShowing = false;
        unawaited(_onFullScreenAdClosed());
        unawaited(preloadAppOpen());
      },
    );
    try {
      await ad.show();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefsAppOpenLastShown,
        policy.now.millisecondsSinceEpoch,
      );
    } catch (_) {
      isFullScreenAdShowing = false;
      _discardAppOpen();
      unawaited(_onFullScreenAdClosed());
      unawaited(preloadAppOpen());
    }
  }

  static Future<void> _onFullScreenAdClosed() async {
    if (!AudioService.shouldPlayMusic) return;
    try {
      if (AudioService.currentMusicMode == MusicMode.gameplay) {
        await AudioService.playGameplayMusic();
      } else {
        await AudioService.playMenuMusic();
      }
    } catch (_) {}
  }

  // --- Interstitial ---

  static Future<void> prepareInterstitialIfDue() async {
    if (!adsAllowed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_prefsInterstitialTriggers) ?? 0;
      final lastMs = prefs.getInt(_prefsInterstitialLastShown);
      final lastShown =
          lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (!policy.willNextInterstitialShow(
        currentTriggerCount: count,
        lastShownAt: lastShown,
      )) {
        return;
      }
      if (_interstitialAd != null &&
          !policy.isInterstitialExpired(_interstitialLoadedAt)) {
        return;
      }
      await _loadInterstitial();
    } catch (_) {}
  }

  static Future<void> _loadInterstitial() async {
    if (!adsAllowed || _interstitialLoading) return;
    if (!await isOnline()) return;
    _discardInterstitial();
    _interstitialLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: AdUnitIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _interstitialLoadedAt = policy.now;
            _interstitialLoading = false;
          },
          onAdFailedToLoad: (_) {
            _interstitialLoading = false;
            _discardInterstitial();
          },
        ),
      );
    } catch (_) {
      _interstitialLoading = false;
      _discardInterstitial();
    }
  }

  static void _discardInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialLoadedAt = null;
  }

  /// Game Over Restart / Home. Navigates via [onComplete] immediately if no ad.
  static Future<void> showInterstitialIfDue({
    required VoidCallback onComplete,
  }) async {
    if (!adsAllowed) {
      onComplete();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final nextCount = (prefs.getInt(_prefsInterstitialTriggers) ?? 0) + 1;
      await prefs.setInt(_prefsInterstitialTriggers, nextCount);
      final lastMs = prefs.getInt(_prefsInterstitialLastShown);
      final lastShown =
          lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);

      final due = policy.shouldShowInterstitial(
        triggerCount: nextCount,
        lastShownAt: lastShown,
      );
      final ad = _interstitialAd;
      final ready = due &&
          ad != null &&
          !policy.isInterstitialExpired(_interstitialLoadedAt) &&
          !isFullScreenAdShowing;

      if (!ready) {
        if (policy.isInterstitialExpired(_interstitialLoadedAt)) {
          _discardInterstitial();
        }
        onComplete();
        return;
      }

      isFullScreenAdShowing = true;
      unawaited(AudioService.pauseBgm());
      var completed = false;
      void finish() {
        if (completed) return;
        completed = true;
        isFullScreenAdShowing = false;
        _interstitialAd = null;
        _interstitialLoadedAt = null;
        unawaited(_onFullScreenAdClosed());
        // Do NOT reload right after dismiss.
        onComplete();
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          finish();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          finish();
        },
      );
      await prefs.setInt(
        _prefsInterstitialLastShown,
        policy.now.millisecondsSinceEpoch,
      );
      await ad.show();
    } catch (_) {
      isFullScreenAdShowing = false;
      onComplete();
    }
  }

  // --- Rewarded ---

  static Future<void> preloadRewarded() async {
    if (!adsAllowed) return;
    await _ensureRewardedLoaded();
  }

  static Future<RewardedAd?> _ensureRewardedLoaded() async {
    if (!adsAllowed) return null;
    if (_rewardedAd != null) return _rewardedAd;
    if (_rewardedLoadGate != null) return _rewardedLoadGate!.future;
    if (!await isOnline()) return null;

    final gate = Completer<RewardedAd?>();
    _rewardedLoadGate = gate;
    try {
      await RewardedAd.load(
        adUnitId: AdUnitIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            if (!gate.isCompleted) gate.complete(ad);
          },
          onAdFailedToLoad: (_) {
            if (!gate.isCompleted) gate.complete(null);
          },
        ),
      ).timeout(_rewardedLoadTimeout);
      return await gate.future.timeout(
        _rewardedLoadTimeout,
        onTimeout: () => null,
      );
    } catch (_) {
      if (!gate.isCompleted) gate.complete(null);
      return null;
    } finally {
      _rewardedLoadGate = null;
    }
  }

  /// Shows rewarded with spinner; [onEarned] only from onUserEarnedReward.
  static Future<bool> showRewarded({
    required BuildContext context,
    required Future<void> Function() onEarned,
  }) async {
    if (!adsAllowed) return false;
    if (!await isOnline()) {
      if (context.mounted) {
        _snack(context, 'Ad not available, try again later');
      }
      return false;
    }
    if (!context.mounted) return false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    RewardedAd? ad;
    try {
      ad = await _ensureRewardedLoaded();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (ad == null) {
      if (context.mounted) {
        _snack(context, 'Ad not available, try again later');
      }
      return false;
    }

    final earned = Completer<bool>();
    isFullScreenAdShowing = true;
    unawaited(AudioService.pauseBgm());
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        isFullScreenAdShowing = false;
        unawaited(_onFullScreenAdClosed());
        if (!earned.isCompleted) earned.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        isFullScreenAdShowing = false;
        unawaited(_onFullScreenAdClosed());
        if (!earned.isCompleted) earned.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) async {
          try {
            await onEarned();
            if (!earned.isCompleted) earned.complete(true);
          } catch (_) {
            if (!earned.isCompleted) earned.complete(false);
          }
        },
      );
    } catch (_) {
      isFullScreenAdShowing = false;
      _rewardedAd = null;
      unawaited(_onFullScreenAdClosed());
      if (context.mounted) {
        _snack(context, 'Ad not available, try again later');
      }
      return false;
    }

    final ok = await earned.future;
    if (!ok && context.mounted) {
      // Dismiss without reward — no snack required by policy for cancel.
    }
    return ok;
  }

  static Future<int> rewardedClaimsToday() async {
    final prefs = await SharedPreferences.getInstance();
    final day = _dayKey(policy.now);
    if (prefs.getString(_prefsRewardDay) != day) return 0;
    return prefs.getInt(_prefsRewardCount) ?? 0;
  }

  static Future<bool> canClaimShopReward({int softCap = 5}) async {
    return (await rewardedClaimsToday()) < softCap;
  }

  static Future<void> recordShopRewardClaim() async {
    final prefs = await SharedPreferences.getInstance();
    final day = _dayKey(policy.now);
    if (prefs.getString(_prefsRewardDay) != day) {
      await prefs.setString(_prefsRewardDay, day);
      await prefs.setInt(_prefsRewardCount, 1);
    } else {
      final n = (prefs.getInt(_prefsRewardCount) ?? 0) + 1;
      await prefs.setInt(_prefsRewardCount, n);
    }
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _backgroundedAt = policy.now;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.resumed:
        unawaited(_maybeShowAppOpenOnResume());
    }
  }
}

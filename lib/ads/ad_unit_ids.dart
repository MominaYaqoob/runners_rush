import 'package:flutter/foundation.dart';

/// AdMob unit IDs. Currently Google TEST IDs only — swap prod later via [kDebugMode].
class AdUnitIds {
  AdUnitIds._();

  // Google sample App ID (manifest). Later: kDebugMode ? test : prod.
  static const appId = 'ca-app-pub-3940256099942544~3347511713';

  // Later: return kDebugMode ? _testX : _prodX;
  static String get appOpen =>
      kDebugMode ? _testAppOpen : _testAppOpen; // prod TBD

  static String get interstitial =>
      kDebugMode ? _testInterstitial : _testInterstitial;

  static String get rewarded => kDebugMode ? _testRewarded : _testRewarded;

  static String get native => kDebugMode ? _testNative : _testNative;

  static const _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testNative = 'ca-app-pub-3940256099942544/2247696110';
}

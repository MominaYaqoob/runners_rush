import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:runners_rush/ads/ad_unit_ids.dart';
import 'package:runners_rush/ads/ads_service.dart';

/// Settings-only small native card (custom Android factory `nativeAdSmall`).
class SettingsNativeAd extends StatefulWidget {
  const SettingsNativeAd({super.key});

  static const height = 168.0;

  @override
  State<SettingsNativeAd> createState() => _SettingsNativeAdState();
}

class _SettingsNativeAdState extends State<SettingsNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _startedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryLoad();
  }

  Future<void> _tryLoad() async {
    if (_startedLoad || !mounted) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    if (!AdsService.adsAllowed) return;

    // Claim the load slot before any await so rebuilds don't double-start.
    _startedLoad = true;

    if (!await AdsService.isOnline()) {
      _startedLoad = false;
      return;
    }
    if (!mounted) {
      _startedLoad = false;
      return;
    }

    try {
      await AdsService.ensureInitialized();
    } catch (_) {
      _startedLoad = false;
      return;
    }
    if (!mounted) {
      _startedLoad = false;
      return;
    }

    final ad = NativeAd(
      adUnitId: AdUnitIds.native,
      factoryId: 'nativeAdSmall',
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
            // Allow a later retry when the widget is visible again.
            _startedLoad = false;
          });
        },
      ),
      request: const AdRequest(),
    );
    _ad = ad;
    try {
      await ad.load();
    } catch (_) {
      ad.dispose();
      _ad = null;
      _startedLoad = false;
      if (mounted) setState(() => _loaded = false);
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      height: SettingsNativeAd.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // black ~8%
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: AdWidget(ad: _ad!),
    );
  }
}

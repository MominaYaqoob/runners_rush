import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:runners_rush/ads/ad_unit_ids.dart';
import 'package:runners_rush/ads/ads_service.dart';

/// Small native template card for Settings only. Loads once while visible.
class SettingsNativeAd extends StatefulWidget {
  const SettingsNativeAd({super.key});

  static const height = 72.0;

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
    if (!await AdsService.isOnline()) return;
    if (!mounted) return;
    _startedLoad = true;

    final ad = NativeAd(
      adUnitId: AdUnitIds.native,
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
          });
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );
    _ad = ad;
    await ad.load();
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
    return SizedBox(
      height: SettingsNativeAd.height,
      width: double.infinity,
      child: AdWidget(ad: _ad!),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:runners_rush/services/shop_service.dart';

/// Full-bleed shop theme image with a configurable dark [child] overlay.
///
/// Loads [ShopService.getSelectedBackgroundAssetPath] once (and again when
/// [reloadToken] changes). Shows evening while loading / as fallback.
class ThemedBackground extends StatefulWidget {
  const ThemedBackground({
    super.key,
    required this.child,
    this.reloadToken,
  });

  /// Dark overlay drawn above the theme image (e.g. [ColoredBox], gradient).
  final Widget child;

  /// When this value changes, the selected theme is loaded again.
  final Object? reloadToken;

  static const fallbackAsset = 'assets/images/background_evening.png';

  @override
  State<ThemedBackground> createState() => _ThemedBackgroundState();
}

class _ThemedBackgroundState extends State<ThemedBackground> {
  String _asset = ThemedBackground.fallbackAsset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ThemedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final path = await ShopService.getSelectedBackgroundAssetPath();
    if (!mounted) return;
    final asset = 'assets/images/$path';
    if (asset == _asset) return;
    setState(() => _asset = asset);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _asset,
          fit: BoxFit.cover,
        ),
        widget.child,
      ],
    );
  }
}

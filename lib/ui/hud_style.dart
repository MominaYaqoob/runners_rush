import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/settings_service.dart';

/// Shared glass HUD tokens for Home, Game Over, Pause, Shop and Settings.
class HudStyle {
  HudStyle._();

  static const radius = 16.0;
  static const fill = Color(0x66000000); // black ~40%
  static const borderColor = Color(0x26FFFFFF); // white ~15%
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const minTap = 48.0;
  static const sideButton = 64.0;

  static const accentOrange = Color(0xFFFF8A3D);
  static const accentPurple = Color(0xFF6B3FA0);
  static const accentGold = Color(0xFFFFC857);

  static Border get border => Border.all(color: borderColor, width: 1);

  static List<BoxShadow> get shadow => const [
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  static BoxDecoration panel({double radius = HudStyle.radius}) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: border,
      boxShadow: shadow,
    );
  }

  static LinearGradient get playGradient => const LinearGradient(
        colors: [accentOrange, accentPurple],
      );

  static TextStyle title({double size = 22}) => GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.1,
      );

  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: weight,
        color: Colors.white,
        height: 1.1,
      );

  static TextStyle caption({double size = 11}) => GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.85),
        height: 1.1,
      );

  /// Light haptic when vibration is enabled in settings.
  static void haptic() {
    if (!SettingsService.vibrationEnabled) return;
    HapticFeedback.lightImpact();
  }

  static void tapFeedback() {
    AudioService.playButtonTap();
    haptic();
  }
}

/// Scales to 0.96 and brightens slightly while pressed.
class HudPressable extends StatefulWidget {
  const HudPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool enabled;

  @override
  State<HudPressable> createState() => _HudPressableState();
}

class _HudPressableState extends State<HudPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.enabled
          ? () {
              HudStyle.tapFeedback();
              widget.onPressed();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.88 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

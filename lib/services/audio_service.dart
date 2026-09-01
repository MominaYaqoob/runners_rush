import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:runners_rush/services/settings_service.dart';

class AudioService {
  static const jumpSfx = 'jump.mp3';
  static const collisionSfx = 'collision.mp3';
  static const buttonTapSfx = 'button_tap.mp3';

  static bool _prefixReady = false;

  static bool get shouldPlay =>
      SettingsService.soundEffectsEnabled && !_inWidgetTest;

  static bool get _inWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  static Future<void> init() async {
    _ensurePrefix();
    await SettingsService.init();
  }

  static void play(String file) {
    if (!shouldPlay) return;
    _ensurePrefix();
    try {
      FlameAudio.play(file).ignore();
    } catch (_) {}
  }

  static void playButtonTap() => play(buttonTapSfx);

  static void ensureReady() => _ensurePrefix();

  static void _ensurePrefix() {
    if (_prefixReady) return;
    FlameAudio.updatePrefix('assets/sounds/');
    _prefixReady = true;
  }
}

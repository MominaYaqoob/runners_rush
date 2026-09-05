import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:runners_rush/services/settings_service.dart';

class AudioService {
  static const jumpSfx = 'jump.mp3';
  static const collisionSfx = 'collision.mp3';
  static const buttonTapSfx = 'button_tap.mp3';
  static const bgmTrack = 'bgm.mp3';

  static bool _prefixReady = false;
  static bool _bgmReady = false;
  static bool _bgmStarted = false;

  static bool get shouldPlay =>
      SettingsService.soundEffectsEnabled && !_inWidgetTest;

  static bool get shouldPlayMusic =>
      SettingsService.musicEnabled && !_inWidgetTest;

  static bool get _inWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  static Future<void> init() async {
    _ensurePrefix();
    await SettingsService.init();
    if (_inWidgetTest) return;
    // Web autoplay policies can hang forever if we await BGM here —
    // never block app startup on audio.
    unawaited(_startBgmInBackground());
  }

  static Future<void> _startBgmInBackground() async {
    try {
      await _ensureBgm();
      if (shouldPlayMusic) {
        await playBgm();
      } else {
        await stopBgm();
      }
    } catch (_) {}
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

  static Future<void> setMusicEnabled(bool enabled) async {
    await SettingsService.setMusicEnabled(enabled);
    if (_inWidgetTest) return;
    if (enabled) {
      await playBgm();
    } else {
      await stopBgm();
    }
  }

  static Future<void> playBgm() async {
    if (!shouldPlayMusic) return;
    _ensurePrefix();
    await _ensureBgm();
    try {
      if (_bgmStarted && FlameAudio.bgm.isPlaying) return;
      if (_bgmStarted) {
        FlameAudio.bgm.resume();
        return;
      }
      await FlameAudio.bgm.play(bgmTrack, volume: 0.42);
      _bgmStarted = true;
    } catch (_) {}
  }

  static Future<void> pauseBgm() async {
    if (_inWidgetTest || !_bgmStarted) return;
    try {
      FlameAudio.bgm.pause();
    } catch (_) {}
  }

  static Future<void> stopBgm() async {
    if (_inWidgetTest) return;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
    _bgmStarted = false;
  }

  static Future<void> _ensureBgm() async {
    if (_bgmReady || _inWidgetTest) return;
    try {
      await FlameAudio.bgm.initialize();
      _bgmReady = true;
    } catch (_) {}
  }

  static void _ensurePrefix() {
    if (_prefixReady) return;
    FlameAudio.updatePrefix('assets/sounds/');
    _prefixReady = true;
  }
}

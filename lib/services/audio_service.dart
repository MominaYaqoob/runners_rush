import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:runners_rush/services/settings_service.dart';

enum MusicMode { menu, gameplay }

/// Central audio: pooled SFX, menu/game BGM with fade, settings + lifecycle.
class AudioService {
  /// Preferred asset names (see [assets/sounds/README.md]).
  static const bgmMenuPreferred = 'bgm_menu.mp3';
  static const bgmGamePreferred = 'bgm_game.mp3';
  static const jumpSfx = 'jump.mp3';
  static const coinSfxPreferred = 'coin.mp3';
  static const collisionSfx = 'collision.mp3';
  static const buttonTapSfx = 'button_tap.mp3';
  static const shieldPickupPreferred = 'shield_pickup.mp3';
  static const shieldBreakPreferred = 'shield_break.mp3';

  /// Legacy names used when a preferred file is missing.
  static const bgmFallback = 'bgm.mp3';
  static const coinSfxFallback = 'coin.wav';
  static const shieldPickupFallback = 'button_tap.mp3';
  static const shieldBreakFallback = 'collision.mp3';

  /// Kept for older call sites / tests — resolves to preferred or fallback.
  static String get coinSfx =>
      _resolvedFiles[coinSfxPreferred] ?? coinSfxFallback;

  static const menuMusicVolume = 0.45;
  static const gameplayMusicVolume = 0.30;
  static const effectsVolume = 0.8;
  static const musicFadeSeconds = 0.4;

  static bool _prefixReady = false;
  static bool _bgmReady = false;
  static bool _bgmStarted = false;
  static bool _poolsReady = false;
  static bool _lifecyclePaused = false;
  static MusicMode? _mode;
  static int _fadeGeneration = 0;

  static AudioPool? _jumpPool;
  static AudioPool? _coinPool;

  /// preferred → resolved filename (after existence check).
  static final Map<String, String> _resolvedFiles = {};

  /// preferred → whether the preferred file exists (for tests / caching).
  static final Map<String, bool> _preferredExists = {};

  /// Optional override for tests (null = use [rootBundle]).
  @visibleForTesting
  static Future<bool> Function(String assetPath)? assetExistsOverride;

  static bool get shouldPlay =>
      SettingsService.soundEffectsEnabled && !_inWidgetTest;

  static bool get shouldPlayMusic =>
      SettingsService.musicEnabled && !_inWidgetTest;

  static MusicMode? get currentMusicMode => _mode;

  static bool get _inWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  /// Pure fallback picker (unit-tested).
  static String pickAsset({
    required String preferred,
    required String fallback,
    required bool preferredExists,
  }) {
    return preferredExists ? preferred : fallback;
  }

  static Future<void> init() async {
    _ensurePrefix();
    await SettingsService.init();
    if (_inWidgetTest) return;
    unawaited(_bootstrap());
  }

  static Future<void> _bootstrap() async {
    try {
      await _ensureBgm();
      await _ensurePools();
      if (shouldPlayMusic) {
        await playMenuMusic();
      } else {
        await stopBgm();
      }
    } catch (_) {}
  }

  /// App-root lifecycle: pause BGM in background; resume only if music is on.
  static Future<void> handleAppLifecycle(AppLifecycleState state) async {
    if (_inWidgetTest) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_lifecyclePaused && shouldPlayMusic && _bgmStarted) {
          _lifecyclePaused = false;
          try {
            await FlameAudio.bgm.resume();
            final target = _mode == MusicMode.gameplay
                ? gameplayMusicVolume
                : menuMusicVolume;
            await _fadeTo(target);
          } catch (_) {}
        } else {
          _lifecyclePaused = false;
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Pause for background, system dialogs, and phone calls.
        if (_bgmStarted && !_lifecyclePaused) {
          _lifecyclePaused = true;
          try {
            await FlameAudio.bgm.pause();
          } catch (_) {}
        }
    }
  }

  static Future<void> setSoundEffectsEnabled(bool enabled) async {
    await SettingsService.setSoundEnabled(enabled);
  }

  static Future<void> setMusicEnabled(bool enabled) async {
    await SettingsService.setMusicEnabled(enabled);
    if (_inWidgetTest) return;
    if (enabled) {
      if (_mode == MusicMode.gameplay) {
        await playGameplayMusic();
      } else {
        await playMenuMusic();
      }
    } else {
      await stopBgm();
    }
  }

  static void play(String file) {
    if (!shouldPlay) return;
    _ensurePrefix();
    try {
      FlameAudio.play(file, volume: effectsVolume).ignore();
    } catch (_) {}
  }

  static void playButtonTap() => play(buttonTapSfx);

  static void playJump() {
    if (!shouldPlay) return;
    unawaited(_playPooledJump());
  }

  static void playCoin() {
    if (!shouldPlay) return;
    unawaited(_playPooledCoin());
  }

  static void playCollision() => play(collisionSfx);

  static void playShieldPickup() {
    if (!shouldPlay) return;
    unawaited(_playResolved(shieldPickupPreferred, shieldPickupFallback));
  }

  static void playShieldBreak() {
    if (!shouldPlay) return;
    unawaited(_playResolved(shieldBreakPreferred, shieldBreakFallback));
  }

  /// Fatal hit: stop gameplay music, then play collision.
  static Future<void> onPlayerHit() async {
    await stopBgm(fade: false);
    playCollision();
  }

  static void ensureReady() {
    _ensurePrefix();
    if (!_inWidgetTest) {
      unawaited(_ensurePools());
    }
  }

  static Future<void> playMenuMusic() =>
      _switchMusic(MusicMode.menu, bgmMenuPreferred, bgmFallback, menuMusicVolume);

  static Future<void> playGameplayMusic() => _switchMusic(
        MusicMode.gameplay,
        bgmGamePreferred,
        bgmFallback,
        gameplayMusicVolume,
      );

  static Future<void> playBgm() => playMenuMusic();

  static Future<void> pauseBgm() async {
    if (_inWidgetTest || !_bgmStarted) return;
    try {
      await FlameAudio.bgm.pause();
    } catch (_) {}
  }

  static Future<void> stopBgm({bool fade = true}) async {
    if (_inWidgetTest) return;
    _mode = null;
    if (!_bgmStarted) return;
    try {
      if (fade) {
        await _fadeTo(0);
      }
      await FlameAudio.bgm.stop();
    } catch (_) {}
    _bgmStarted = false;
    _lifecyclePaused = false;
  }

  static Future<void> _switchMusic(
    MusicMode mode,
    String preferred,
    String fallback,
    double volume,
  ) async {
    if (!shouldPlayMusic) return;
    _ensurePrefix();
    await _ensureBgm();
    final file = await resolveSoundFile(preferred, fallback);
    if (_bgmStarted && _mode == mode && FlameAudio.bgm.isPlaying) {
      try {
        await FlameAudio.bgm.audioPlayer.setVolume(volume);
      } catch (_) {}
      return;
    }
    try {
      if (_bgmStarted) {
        await _fadeTo(0);
        await FlameAudio.bgm.stop();
      }
      await FlameAudio.bgm.play(file, volume: 0);
      _bgmStarted = true;
      _mode = mode;
      _lifecyclePaused = false;
      await _fadeTo(volume);
    } catch (_) {}
  }

  static Future<void> _fadeTo(double target) async {
    if (_inWidgetTest) return;
    final gen = ++_fadeGeneration;
    double from = target;
    try {
      from = FlameAudio.bgm.audioPlayer.volume;
    } catch (_) {
      from = 0;
    }
    const steps = 8;
    final ms = ((musicFadeSeconds / steps) * 1000).round().clamp(16, 100);
    for (var i = 1; i <= steps; i++) {
      if (gen != _fadeGeneration) return;
      final t = i / steps;
      final v = from + (target - from) * t;
      try {
        await FlameAudio.bgm.audioPlayer.setVolume(v);
      } catch (_) {
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: ms));
    }
  }

  static Future<void> _playPooledJump() async {
    await _ensurePools();
    final pool = _jumpPool;
    if (pool != null) {
      try {
        await pool.start(volume: effectsVolume);
        return;
      } catch (_) {}
    }
    play(jumpSfx);
  }

  static Future<void> _playPooledCoin() async {
    await _ensurePools();
    final pool = _coinPool;
    if (pool != null) {
      try {
        await pool.start(volume: effectsVolume);
        return;
      } catch (_) {}
    }
    final file = await resolveSoundFile(coinSfxPreferred, coinSfxFallback);
    play(file);
  }

  static Future<void> _playResolved(String preferred, String fallback) async {
    final file = await resolveSoundFile(preferred, fallback);
    play(file);
  }

  /// Resolves [preferred] to itself or [fallback]; caches the result.
  static Future<String> resolveSoundFile(
    String preferred,
    String fallback,
  ) async {
    final cached = _resolvedFiles[preferred];
    if (cached != null) return cached;
    final exists = await preferredAssetExists(preferred);
    final resolved = pickAsset(
      preferred: preferred,
      fallback: fallback,
      preferredExists: exists,
    );
    _resolvedFiles[preferred] = resolved;
    return resolved;
  }

  @visibleForTesting
  static Future<bool> preferredAssetExists(String preferred) async {
    final cached = _preferredExists[preferred];
    if (cached != null) return cached;
    final path = 'assets/sounds/$preferred';
    final override = assetExistsOverride;
    final exists = override != null
        ? await override(path)
        : await _bundleContains(path);
    _preferredExists[preferred] = exists;
    return exists;
  }

  static Future<bool> _bundleContains(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _ensurePools() async {
    if (_poolsReady || _inWidgetTest) return;
    _ensurePrefix();
    try {
      final jumpFile = await resolveSoundFile(jumpSfx, jumpSfx);
      _jumpPool = await FlameAudio.createPool(
        jumpFile,
        minPlayers: 1,
        maxPlayers: 4,
      );
      final coinFile = await resolveSoundFile(coinSfxPreferred, coinSfxFallback);
      _coinPool = await FlameAudio.createPool(
        coinFile,
        minPlayers: 1,
        maxPlayers: 4,
      );
      _poolsReady = true;
    } catch (_) {}
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

  /// Clears cached resolution (tests only).
  @visibleForTesting
  static void resetResolutionCacheForTest() {
    _resolvedFiles.clear();
    _preferredExists.clear();
    assetExistsOverride = null;
    _mode = null;
    _bgmStarted = false;
    _poolsReady = false;
    _jumpPool = null;
    _coinPool = null;
    _lifecyclePaused = false;
  }
}

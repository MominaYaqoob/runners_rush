import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SettingsService.resetForTests();
    await SettingsService.init();
    AudioService.resetResolutionCacheForTest();
  });

  tearDown(() {
    AudioService.resetResolutionCacheForTest();
    AudioService.assetExistsOverride = null;
  });

  test('coin preferred falls back to coin.wav when coin.mp3 is missing', () {
    expect(
      AudioService.pickAsset(
        preferred: AudioService.coinSfxPreferred,
        fallback: AudioService.coinSfxFallback,
        preferredExists: false,
      ),
      AudioService.coinSfxFallback,
    );
    expect(AudioService.coinSfxFallback, 'coin.wav');
    expect(AudioService.coinSfxPreferred, 'coin.mp3');
  });

  test('coin preferred is used when the new file exists', () {
    expect(
      AudioService.pickAsset(
        preferred: AudioService.coinSfxPreferred,
        fallback: AudioService.coinSfxFallback,
        preferredExists: true,
      ),
      'coin.mp3',
    );
  });

  test('bgm and shield assets fall back to legacy names', () {
    expect(
      AudioService.pickAsset(
        preferred: AudioService.bgmMenuPreferred,
        fallback: AudioService.bgmFallback,
        preferredExists: false,
      ),
      'bgm.mp3',
    );
    expect(
      AudioService.pickAsset(
        preferred: AudioService.bgmGamePreferred,
        fallback: AudioService.bgmFallback,
        preferredExists: false,
      ),
      'bgm.mp3',
    );
    expect(
      AudioService.pickAsset(
        preferred: AudioService.shieldPickupPreferred,
        fallback: AudioService.shieldPickupFallback,
        preferredExists: false,
      ),
      'button_tap.mp3',
    );
    expect(
      AudioService.pickAsset(
        preferred: AudioService.shieldBreakPreferred,
        fallback: AudioService.shieldBreakFallback,
        preferredExists: false,
      ),
      'collision.mp3',
    );
  });

  test('resolveSoundFile uses override and caches fallback', () async {
    AudioService.assetExistsOverride = (path) async {
      return path.endsWith('jump.mp3');
    };
    final coin = await AudioService.resolveSoundFile(
      AudioService.coinSfxPreferred,
      AudioService.coinSfxFallback,
    );
    expect(coin, 'coin.wav');
    final jump = await AudioService.resolveSoundFile(
      AudioService.jumpSfx,
      AudioService.jumpSfx,
    );
    expect(jump, 'jump.mp3');
    // Cached — override flipping should not change prior resolution.
    AudioService.assetExistsOverride = (_) async => true;
    final coinAgain = await AudioService.resolveSoundFile(
      AudioService.coinSfxPreferred,
      AudioService.coinSfxFallback,
    );
    expect(coinAgain, 'coin.wav');
  });

  test('volume constants match design targets', () {
    expect(AudioService.menuMusicVolume, 0.45);
    expect(AudioService.gameplayMusicVolume, 0.30);
    expect(AudioService.effectsVolume, 0.8);
    expect(AudioService.musicFadeSeconds, 0.4);
  });

  test('widget-test guard skips real audio playback', () {
    // TestWidgetsFlutterBinding is active → shouldPlay / music are false
    // regardless of settings, so Flame is never touched in tests.
    expect(SettingsService.soundEffectsEnabled, isTrue);
    expect(SettingsService.musicEnabled, isTrue);
    expect(AudioService.shouldPlay, isFalse);
    expect(AudioService.shouldPlayMusic, isFalse);
  });

  test('sound effects toggle updates SettingsService immediately', () async {
    await AudioService.setSoundEffectsEnabled(false);
    expect(SettingsService.soundEffectsEnabled, isFalse);
    expect(await SettingsService.getSoundEnabled(), isFalse);

    await AudioService.setSoundEffectsEnabled(true);
    expect(SettingsService.soundEffectsEnabled, isTrue);
    expect(await SettingsService.getSoundEnabled(), isTrue);
  });

  test('music toggle updates SettingsService immediately', () async {
    await AudioService.setMusicEnabled(false);
    expect(SettingsService.musicEnabled, isFalse);
    expect(await SettingsService.getMusicEnabled(), isFalse);

    await AudioService.setMusicEnabled(true);
    expect(SettingsService.musicEnabled, isTrue);
    expect(await SettingsService.getMusicEnabled(), isTrue);
  });

  test('shouldPlay respects sound toggle under the widget-test guard', () async {
    await AudioService.setSoundEffectsEnabled(false);
    expect(AudioService.shouldPlay, isFalse);
    await AudioService.setSoundEffectsEnabled(true);
    // Still false in tests because of TestWidgetsFlutterBinding.
    expect(AudioService.shouldPlay, isFalse);
  });
}

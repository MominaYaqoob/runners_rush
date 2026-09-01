import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _soundKey = 'sound_effects_enabled';
  static const _musicKey = 'music_enabled';
  static const _vibrationKey = 'vibration_enabled';
  static const _legacySoundKey = 'sfx_enabled';

  static bool soundEffectsEnabled = true;
  static bool musicEnabled = true;
  static bool vibrationEnabled = true;
  static bool _loaded = false;

  static Future<void> init() async {
    await _ensureLoaded();
  }

  static Future<bool> getSoundEnabled() async {
    await _ensureLoaded();
    return soundEffectsEnabled;
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    soundEffectsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  static Future<bool> getMusicEnabled() async {
    await _ensureLoaded();
    return musicEnabled;
  }

  static Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicKey, enabled);
  }

  static Future<bool> getVibrationEnabled() async {
    await _ensureLoaded();
    return vibrationEnabled;
  }

  static Future<void> setVibrationEnabled(bool enabled) async {
    vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, enabled);
  }

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    soundEffectsEnabled =
        prefs.getBool(_soundKey) ?? prefs.getBool(_legacySoundKey) ?? true;
    musicEnabled = prefs.getBool(_musicKey) ?? true;
    vibrationEnabled = prefs.getBool(_vibrationKey) ?? true;
    _loaded = true;
  }

  static void resetForTests() {
    _loaded = false;
    soundEffectsEnabled = true;
    musicEnabled = true;
    vibrationEnabled = true;
  }
}

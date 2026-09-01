import 'package:shared_preferences/shared_preferences.dart';
import 'package:runners_rush/services/character_service.dart';

class ShopService {
  static const _coinsKey = 'coins';
  static const _unlockedKey = 'unlocked_characters';

  static const defaultUnlocked = [
    CharacterService.male,
    CharacterService.female,
  ];

  static Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_coinsKey) ?? 0;
  }

  static Future<void> addCoins(int amount) async {
    if (amount == 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_coinsKey) ?? 0;
    await prefs.setInt(_coinsKey, current + amount);
  }

  static Future<List<String>> getUnlockedCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_unlockedKey);
    if (stored == null || stored.isEmpty) {
      await prefs.setStringList(_unlockedKey, defaultUnlocked);
      return List<String>.from(defaultUnlocked);
    }
    return stored;
  }

  static Future<bool> isUnlocked(String characterId) async {
    final unlocked = await getUnlockedCharacters();
    return unlocked.contains(characterId);
  }

  static Future<void> unlockCharacter(String characterId) async {
    final unlocked = await getUnlockedCharacters();
    if (unlocked.contains(characterId)) return;
    unlocked.add(characterId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, unlocked);
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import 'package:runners_rush/services/character_service.dart';

class ShopCharacter {
  const ShopCharacter({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.price,
  });

  final String id;
  final String name;
  /// Flutter asset path, e.g. `assets/images/male_run.png`.
  final String assetPath;
  final int price;
}

class ShopBackground {
  const ShopBackground({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.groundAssetPath,
    required this.price,
  });

  final String id;
  final String name;
  /// Path relative to Flame images root, e.g. `background_evening.png`.
  final String assetPath;
  /// Matching scrolling ground strip, e.g. `ground_texture.png`.
  final String groundAssetPath;
  final int price;

  String get flutterAsset => 'assets/images/$assetPath';
}

class ShopService {
  static const _coinsKey = 'coins';
  static const _unlockedKey = 'unlocked_characters';
  static const _unlockedBackgroundsKey = 'unlocked_backgrounds';
  static const _selectedBackgroundKey = 'selected_background';

  static const eveningId = 'evening';
  static const defaultGroundAssetPath = 'ground_texture.png';

  static const defaultUnlocked = [CharacterService.male];

  static const defaultUnlockedBackgrounds = [eveningId];

  static const characters = <ShopCharacter>[
    ShopCharacter(
      id: CharacterService.male,
      name: 'Explorer Male',
      assetPath: 'assets/images/male_run.png',
      price: 0,
    ),
    ShopCharacter(
      id: CharacterService.female,
      name: 'Explorer Female',
      assetPath: 'assets/images/female_run.png',
      price: 275,
    ),
  ];

  static ShopCharacter characterById(String id) {
    return characters.firstWhere(
      (c) => c.id == id,
      orElse: () => characters.first,
    );
  }

  static const backgrounds = <ShopBackground>[
    ShopBackground(
      id: eveningId,
      name: 'Evening',
      assetPath: 'background_evening.png',
      groundAssetPath: defaultGroundAssetPath,
      price: 0,
    ),
    ShopBackground(
      id: 'morning',
      name: 'Morning',
      assetPath: 'background_morning.png',
      groundAssetPath: defaultGroundAssetPath,
      price: 100,
    ),
    ShopBackground(
      id: 'day',
      name: 'Day',
      assetPath: 'background_day.png',
      groundAssetPath: defaultGroundAssetPath,
      price: 150,
    ),
    ShopBackground(
      id: 'night',
      name: 'Night',
      assetPath: 'background_night.png',
      groundAssetPath: 'ground_night.png',
      price: 200,
    ),
    ShopBackground(
      id: 'autumn',
      name: 'Autumn',
      assetPath: 'background_autumn.png',
      groundAssetPath: 'ground_autumn.png',
      price: 220,
    ),
    ShopBackground(
      id: 'rain',
      name: 'Rain',
      assetPath: 'background_rain.png',
      groundAssetPath: 'ground_rain.png',
      price: 250,
    ),
    ShopBackground(
      id: 'snow',
      name: 'Snow',
      assetPath: 'background_snow.png',
      groundAssetPath: 'ground_snow.png',
      price: 300,
    ),
  ];

  static ShopBackground backgroundById(String id) {
    return backgrounds.firstWhere(
      (b) => b.id == id,
      orElse: () => backgrounds.first,
    );
  }

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

  static Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return true;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_coinsKey) ?? 0;
    if (current < amount) return false;
    await prefs.setInt(_coinsKey, current - amount);
    return true;
  }

  static Future<List<String>> getUnlockedCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_unlockedKey);
    if (stored == null || stored.isEmpty) {
      await prefs.setStringList(_unlockedKey, defaultUnlocked);
      return List<String>.from(defaultUnlocked);
    }
    final unlocked = List<String>.from(stored);
    if (!unlocked.contains(CharacterService.male)) {
      unlocked.insert(0, CharacterService.male);
      await prefs.setStringList(_unlockedKey, unlocked);
    }
    return unlocked;
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

  static Future<bool> purchaseCharacter(String id, int price) async {
    final unlocked = await getUnlockedCharacters();
    if (unlocked.contains(id)) return true;
    if (price > 0) {
      final spent = await spendCoins(price);
      if (!spent) return false;
    }
    unlocked.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, unlocked);
    return true;
  }

  static Future<Set<String>> getUnlockedBackgrounds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_unlockedBackgroundsKey);
    if (stored == null || stored.isEmpty) {
      await prefs.setStringList(
        _unlockedBackgroundsKey,
        defaultUnlockedBackgrounds,
      );
      return Set<String>.from(defaultUnlockedBackgrounds);
    }
    final unlocked = stored.toSet();
    if (!unlocked.contains(eveningId)) {
      unlocked.add(eveningId);
      await prefs.setStringList(_unlockedBackgroundsKey, unlocked.toList());
    }
    return unlocked;
  }

  static Future<bool> purchaseBackground(String id, int price) async {
    final unlocked = await getUnlockedBackgrounds();
    if (unlocked.contains(id)) return true;
    if (price > 0) {
      final spent = await spendCoins(price);
      if (!spent) return false;
    }
    unlocked.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedBackgroundsKey, unlocked.toList());
    return true;
  }

  static Future<void> setSelectedBackground(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedBackgroundKey, id);
  }

  static Future<String> getSelectedBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_selectedBackgroundKey);
    if (id == null || id.isEmpty) return eveningId;
    final unlocked = await getUnlockedBackgrounds();
    if (!unlocked.contains(id)) return eveningId;
    return id;
  }

  /// Flame image path for the currently selected background.
  static Future<String> getSelectedBackgroundAssetPath() async {
    final id = await getSelectedBackground();
    return backgroundById(id).assetPath;
  }

  /// Flame image path for the ground strip matching the selected background.
  static Future<String> getSelectedGroundAssetPath() async {
    final id = await getSelectedBackground();
    return backgroundById(id).groundAssetPath;
  }
}

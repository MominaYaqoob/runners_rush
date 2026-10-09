import 'package:flutter/foundation.dart';
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
    this.bakedGroundFraction = 0,
  });

  final String id;
  final String name;
  /// Path relative to Flame images root, e.g. `background_evening.png`.
  final String assetPath;
  /// Matching scrolling ground strip, e.g. `ground_texture.png`.
  final String groundAssetPath;
  final int price;

  /// Bottom fraction of the sky PNG that already paints a stone path.
  /// Cropped out in [CoverBackgroundComponent] so it does not double up with
  /// [GroundStripComponent]. Evening has none (0). Tweak per theme if needed.
  final double bakedGroundFraction;

  String get flutterAsset => 'assets/images/$assetPath';
}

class ShopService {
  static const _coinsKey = 'coins';
  static const _unlockedKey = 'unlocked_characters';
  static const _unlockedBackgroundsKey = 'unlocked_backgrounds';
  static const _selectedBackgroundKey = 'selected_background';

  static const eveningId = 'evening';
  static const defaultGroundAssetPath = 'ground_texture.png';

  // --- Economy (tune rates/prices here) ---
  /// Score points needed per coin from a finished run (~2s at 10 pts/s).
  /// Raise to grant more score-based coins when in-run pickups are rarer.
  static const scorePerRunCoin = 20;
  /// Credits per coin collected during a run (prices unchanged).
  /// Raise later if single ground coins need a bigger payout.
  static const inRunCoinCredit = 1;
  /// Coins granted by the Shop "Watch ad" rewarded button.
  static const rewardedAdCoins = 5;
  static const malePrice = 0;
  static const femalePrice = 10;
  static const eveningPrice = 0;
  static const morningPrice = 5;
  static const dayPrice = 6;
  static const nightPrice = 7;
  static const autumnPrice = 8;
  static const rainPrice = 9;
  static const snowPrice = 10;

  /// Default crop for themes that bake a stone path into the sky PNG.
  static const defaultBakedGroundFraction = 0.28;

  static const defaultUnlocked = [CharacterService.male];

  static const defaultUnlockedBackgrounds = [eveningId];

  static int coinsForRun({required int score, int collected = 0}) =>
      score ~/ scorePerRunCoin + collected * inRunCoinCredit;

  static const characters = <ShopCharacter>[
    ShopCharacter(
      id: CharacterService.male,
      name: 'Explorer Male',
      assetPath: 'assets/images/shop_male_portrait.png',
      price: malePrice,
    ),
    ShopCharacter(
      id: CharacterService.female,
      name: 'Explorer Female',
      assetPath: 'assets/images/shop_female_portrait.png',
      price: femalePrice,
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
      price: eveningPrice,
      bakedGroundFraction: 0,
    ),
    ShopBackground(
      id: 'morning',
      name: 'Morning',
      assetPath: 'background_morning.png',
      groundAssetPath: defaultGroundAssetPath,
      price: morningPrice,
      bakedGroundFraction: defaultBakedGroundFraction,
    ),
    ShopBackground(
      id: 'day',
      name: 'Day',
      assetPath: 'background_day.png',
      groundAssetPath: defaultGroundAssetPath,
      price: dayPrice,
      bakedGroundFraction: defaultBakedGroundFraction,
    ),
    ShopBackground(
      id: 'night',
      name: 'Night',
      assetPath: 'background_night.png',
      groundAssetPath: 'ground_night.png',
      price: nightPrice,
      bakedGroundFraction: defaultBakedGroundFraction,
    ),
    ShopBackground(
      id: 'autumn',
      name: 'Autumn',
      assetPath: 'background_autumn.png',
      groundAssetPath: 'ground_autumn.png',
      price: autumnPrice,
      bakedGroundFraction: defaultBakedGroundFraction,
    ),
    ShopBackground(
      id: 'rain',
      name: 'Rain',
      assetPath: 'background_rain.png',
      groundAssetPath: 'ground_rain.png',
      price: rainPrice,
      bakedGroundFraction: defaultBakedGroundFraction,
    ),
    ShopBackground(
      id: 'snow',
      name: 'Snow',
      assetPath: 'background_snow.png',
      groundAssetPath: 'ground_snow.png',
      price: snowPrice,
      bakedGroundFraction: defaultBakedGroundFraction,
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
    debugPrint(
      '[SHOP_SERVICE] getSelectedBackground called, stored id will be checked',
    );
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_selectedBackgroundKey);
    final String result;
    if (id == null || id.isEmpty) {
      result = eveningId;
    } else {
      final unlocked = await getUnlockedBackgrounds();
      result = unlocked.contains(id) ? id : eveningId;
    }
    debugPrint('[SHOP_SERVICE] getSelectedBackground final id=$result');
    return result;
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

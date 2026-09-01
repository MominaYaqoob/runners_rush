import 'package:shared_preferences/shared_preferences.dart';

class CharacterService {
  static const male = 'male';
  static const female = 'female';
  static const _selectedCharacterKey = 'selected_character';

  static Future<String> getSelectedCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_selectedCharacterKey);
    if (value == female) return female;
    return male;
  }

  static Future<void> setSelectedCharacter(String character) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _selectedCharacterKey,
      character == female ? female : male,
    );
  }
}

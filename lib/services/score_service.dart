import 'package:shared_preferences/shared_preferences.dart';

class ScoreService {
  static const _highScoreKey = 'high_score';

  static Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey) ?? 0;
  }

  static Future<void> saveHighScoreIfBetter(int newScore) async {
    final current = await getHighScore();
    if (newScore <= current) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, newScore);
  }
}

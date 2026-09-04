import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ScoreService {
  static const _highScoreKey = 'high_score';
  static const _recentRunsKey = 'recent_runs';
  static const _maxRecentRuns = 20;

  static Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey) ?? 0;
  }

  static Future<List<int>> getRecentRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentRunsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<num>()
          .map((n) => n.toInt())
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveHighScoreIfBetter(int newScore) async {
    await _prependRecentRun(newScore);
    final current = await getHighScore();
    if (newScore <= current) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, newScore);
  }

  static Future<void> _prependRecentRun(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final runs = List<int>.from(await getRecentRuns());
    runs.insert(0, score);
    if (runs.length > _maxRecentRuns) {
      runs.removeRange(_maxRecentRuns, runs.length);
    }
    await prefs.setString(_recentRunsKey, jsonEncode(runs));
  }
}

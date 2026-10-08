import 'package:shared_preferences/shared_preferences.dart';
import 'package:runners_rush/services/shop_service.dart';

/// Result of a successful [DailyRewardService.claim].
class DailyRewardClaim {
  const DailyRewardClaim({
    required this.coins,
    required this.streakDay,
  });

  final int coins;
  final int streakDay;
}

/// Calendar-day daily reward with streak coins (device local date).
///
/// Clock rollback: the trusted "today" never moves earlier than the last
/// observed date stored in prefs, so rolling the device clock back cannot
/// unlock another claim or shrink stored claim dates.
class DailyRewardService {
  static const _lastClaimKey = 'daily_reward_last_claim';
  static const _streakKey = 'daily_reward_streak';
  static const _lastSeenKey = 'daily_reward_last_seen';

  /// Day-1 reward; grows by 1 each consecutive day.
  static const minReward = 3;

  /// Cap for long streaks.
  static const maxReward = 10;

  /// Injectable clock for tests. Returns device-local [DateTime.now] by default.
  static DateTime Function() clock = DateTime.now;

  static void resetForTests() {
    clock = DateTime.now;
  }

  /// Coins granted for streak day [day] (1-based). Day 1 → 3 … capped at 10.
  static int coinsForStreakDay(int day) {
    if (day < 1) return minReward;
    return (minReward + day - 1).clamp(minReward, maxReward);
  }

  static Future<bool> canClaim() async {
    final today = await _trustedToday();
    final last = await _lastClaimDate();
    if (last == null) return true;
    return today.isAfter(last);
  }

  /// Coins the next successful claim would grant (does not mutate state).
  static Future<int> peekRewardCoins() async {
    final streak = await _nextStreakDay();
    return coinsForStreakDay(streak);
  }

  static Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  /// Claims today's reward if available. Returns null when already claimed.
  static Future<DailyRewardClaim?> claim() async {
    final today = await _trustedToday();
    final last = await _lastClaimDate();
    if (last != null && !today.isAfter(last)) {
      return null;
    }

    final streakDay = await _nextStreakDay();
    final coins = coinsForStreakDay(streakDay);

    await ShopService.addCoins(coins);

    final prefs = await SharedPreferences.getInstance();
    final stored = await _lastClaimDate();
    // Never move the stored claim date backwards.
    if (stored == null || !today.isBefore(stored)) {
      await prefs.setString(_lastClaimKey, _formatDate(today));
      await prefs.setInt(_streakKey, streakDay);
    }

    return DailyRewardClaim(coins: coins, streakDay: streakDay);
  }

  static Future<int> _nextStreakDay() async {
    final today = await _trustedToday();
    final last = await _lastClaimDate();
    final prefs = await SharedPreferences.getInstance();
    final prevStreak = prefs.getInt(_streakKey) ?? 0;

    if (last == null) return 1;

    final yesterday = today.subtract(const Duration(days: 1));
    if (_sameDay(last, yesterday)) {
      return prevStreak + 1;
    }
    // Missed a day (or first claim after a gap) → restart.
    if (today.isAfter(last)) return 1;
    return prevStreak;
  }

  /// Calendar day that never goes earlier than the last observed day.
  static Future<DateTime> _trustedToday() async {
    final raw = clock();
    final today = DateTime(raw.year, raw.month, raw.day);
    final prefs = await SharedPreferences.getInstance();
    final seenStr = prefs.getString(_lastSeenKey);
    if (seenStr != null) {
      final seen = _parseDate(seenStr);
      if (seen != null && today.isBefore(seen)) {
        return seen;
      }
    }
    await prefs.setString(_lastSeenKey, _formatDate(today));
    return today;
  }

  static Future<DateTime?> _lastClaimDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastClaimKey);
    if (raw == null || raw.isEmpty) return null;
    return _parseDate(raw);
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

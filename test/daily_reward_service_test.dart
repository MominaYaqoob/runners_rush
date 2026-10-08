import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runners_rush/services/daily_reward_service.dart';
import 'package:runners_rush/services/shop_service.dart';

void main() {
  late DateTime fakeNow;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyRewardService.resetForTests();
    fakeNow = DateTime(2026, 3, 10, 12);
    DailyRewardService.clock = () => fakeNow;
  });

  tearDown(() {
    DailyRewardService.resetForTests();
  });

  test('coinsForStreakDay grows from 3 and caps at 10', () {
    expect(DailyRewardService.coinsForStreakDay(1), 3);
    expect(DailyRewardService.coinsForStreakDay(2), 4);
    expect(DailyRewardService.coinsForStreakDay(7), 9);
    expect(DailyRewardService.coinsForStreakDay(8), 10);
    expect(DailyRewardService.coinsForStreakDay(20), 10);
  });

  test('first claim grants day-1 coins and marks unavailable', () async {
    expect(await DailyRewardService.canClaim(), isTrue);
    expect(await DailyRewardService.peekRewardCoins(), 3);

    final result = await DailyRewardService.claim();
    expect(result, isNotNull);
    expect(result!.coins, 3);
    expect(result.streakDay, 1);
    expect(await ShopService.getCoins(), 3);
    expect(await DailyRewardService.canClaim(), isFalse);
    expect(await DailyRewardService.claim(), isNull);
  });

  test('consecutive day continues streak and increases coins', () async {
    await DailyRewardService.claim();
    fakeNow = DateTime(2026, 3, 11, 9);
    expect(await DailyRewardService.canClaim(), isTrue);
    expect(await DailyRewardService.peekRewardCoins(), 4);

    final result = await DailyRewardService.claim();
    expect(result!.coins, 4);
    expect(result.streakDay, 2);
    expect(await ShopService.getCoins(), 7);
  });

  test('missed day resets streak to 1', () async {
    await DailyRewardService.claim();
    fakeNow = DateTime(2026, 3, 11, 9);
    await DailyRewardService.claim();
    fakeNow = DateTime(2026, 3, 13, 9); // skipped the 12th

    expect(await DailyRewardService.peekRewardCoins(), 3);
    final result = await DailyRewardService.claim();
    expect(result!.streakDay, 1);
    expect(result.coins, 3);
  });

  test('streak reward caps at 10 after long run', () async {
    for (var i = 0; i < 10; i++) {
      fakeNow = DateTime(2026, 3, 10 + i, 12);
      await DailyRewardService.claim();
    }
    fakeNow = DateTime(2026, 3, 20, 12);
    final result = await DailyRewardService.claim();
    expect(result!.streakDay, 11);
    expect(result.coins, 10);
  });

  test('clock rollback does not allow a second claim', () async {
    await DailyRewardService.claim();
    expect(await DailyRewardService.canClaim(), isFalse);

    fakeNow = DateTime(2026, 3, 9, 12); // rolled back one day
    expect(await DailyRewardService.canClaim(), isFalse);
    expect(await DailyRewardService.claim(), isNull);
    expect(await ShopService.getCoins(), 3);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_reward_last_claim'), '2026-03-10');
    expect(prefs.getString('daily_reward_last_seen'), '2026-03-10');
  });

  test('after rollback, advancing past trusted day unlocks again', () async {
    await DailyRewardService.claim();
    fakeNow = DateTime(2026, 3, 8, 12);
    expect(await DailyRewardService.canClaim(), isFalse);

    fakeNow = DateTime(2026, 3, 11, 12);
    expect(await DailyRewardService.canClaim(), isTrue);
    final result = await DailyRewardService.claim();
    expect(result!.streakDay, 2);
    expect(result.coins, 4);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/services/score_service.dart';
import 'package:runners_rush/services/shop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('handlePlayerHit persists score/coins once without BuildContext', () async {
    final game = RunnersRushGame();
    game.score.value = 42;

    expect(game.isGameOver, isFalse);
    game.handlePlayerHit();
    expect(game.isGameOver, isTrue);

    // Second hit must be a no-op (single save).
    game.handlePlayerHit();
    await pumpEventQueue();

    expect(await ScoreService.getHighScore(), 42);
    expect(await ScoreService.getRecentRuns(), [42]);
    expect(await ShopService.getCoins(), 2); // 42 ~/ 20
  });
}

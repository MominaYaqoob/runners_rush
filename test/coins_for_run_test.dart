import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/services/shop_service.dart';

void main() {
  test('coinsForRun uses integer scorePerRunCoin math', () {
    expect(ShopService.scorePerRunCoin, 20);
    expect(ShopService.coinsForRun(score: 0), 0);
    expect(ShopService.coinsForRun(score: 19), 0);
    expect(ShopService.coinsForRun(score: 20), 1);
    expect(ShopService.coinsForRun(score: 199), 9);
    expect(ShopService.coinsForRun(score: 200, collected: 3), 13);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/services/shop_service.dart';

void main() {
  test('evening has no baked path; other themes share default fraction', () {
    expect(
      ShopService.backgroundById(ShopService.eveningId).bakedGroundFraction,
      0,
    );
    for (final id in ['morning', 'day', 'night', 'autumn', 'rain', 'snow']) {
      expect(
        ShopService.backgroundById(id).bakedGroundFraction,
        ShopService.defaultBakedGroundFraction,
      );
    }
  });

  test('crop leaves sky above the ground strip for phone sizes', () {
    const fraction = ShopService.defaultBakedGroundFraction;
    expect(fraction, 0.28);
    for (final size in const [
      (800.0, 360.0),
      (844.0, 390.0),
      (915.0, 412.0),
    ]) {
      final groundTop = size.$2 * (1 - PlayerComponent.groundHeightRatio);
      // Cropped src height as a fraction of original must exceed groundTop /
      // view when cover-scaled by width alone — otherwise layout bottoms out.
      expect(groundTop, lessThan(size.$2));
      expect(1 - fraction, greaterThan(PlayerComponent.groundHeightRatio));
    }
  });
}

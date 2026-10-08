import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/services/audio_service.dart';

void main() {
  test('coin SFX asset name matches assets/sounds/coin.wav', () {
    expect(AudioService.coinSfx, 'coin.wav');
  });
}

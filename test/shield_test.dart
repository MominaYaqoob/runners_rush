import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

void main() {
  test('shield absorbs exactly one hit then grants invulnerability', () {
    final player = PlayerComponent();
    player.activateShield();
    expect(player.hasShield, isTrue);

    expect(
      player.resolveObstacleHit(),
      ObstacleHitOutcome.absorbedByShield,
    );
    expect(player.hasShield, isFalse);
    expect(player.isInvulnerable, isTrue);

    // Still invulnerable — second contact ignored, does not end the run.
    expect(
      player.resolveObstacleHit(),
      ObstacleHitOutcome.ignoredInvulnerable,
    );
    expect(player.hasShield, isFalse);
  });

  test('second hit after invulnerability ends is fatal', () {
    final player = PlayerComponent();
    player.activateShield();
    expect(player.resolveObstacleHit(), ObstacleHitOutcome.absorbedByShield);

    player.tickInvulnerability(PlayerComponent.shieldInvulnerabilitySeconds);
    expect(player.isInvulnerable, isFalse);

    expect(player.resolveObstacleHit(), ObstacleHitOutcome.fatal);
  });

  test('shield not carried across restart', () {
    final player = PlayerComponent();
    player.activateShield();
    player.resolveObstacleHit(); // consume → invulnerable
    expect(player.isInvulnerable, isTrue);

    player.resetPowerUps();
    expect(player.hasShield, isFalse);
    expect(player.isInvulnerable, isFalse);

    final game = RunnersRushGame();
    // Fresh game notifier starts inactive (restart creates a new game).
    expect(game.shieldActive.value, isFalse);
    game.resetShieldState();
    expect(game.shieldActive.value, isFalse);
  });

  test('shield spawn interval is 25–40 seconds', () {
    expect(RunnersRushGame.shieldSpawnIntervalMin, 25);
    expect(RunnersRushGame.shieldSpawnIntervalMax, 40);
  });
}

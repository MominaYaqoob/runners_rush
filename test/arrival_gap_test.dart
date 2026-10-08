import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

void main() {
  test('equal speeds with close ETAs are rejected', () {
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: 4.0,
        existingEtas: const [4.5],
      ),
      isFalse,
    );
  });

  test('equal speeds far apart are accepted', () {
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: 5.0,
        existingEtas: const [2.0],
      ),
      isTrue,
    );
  });

  test('arrow vs ground: catch-up pair is rejected', () {
    const playerX = 120.0;
    const screenW = 800.0;
    const groundSpeed = RunnersRushGame.initialSpeed;
    const arrowSpeed =
        RunnersRushGame.initialSpeed * ObstacleComponent.flyingSpeedMultiplier;

    // Ground obstacle already mid-screen.
    final groundEta = (400.0 - playerX) / groundSpeed;
    // New arrow at the right edge would arrive too close behind/before it.
    final arrowEta = (screenW - playerX) / arrowSpeed;

    expect((arrowEta - groundEta).abs(), lessThan(RunnersRushGame.minArrivalGap));
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: arrowEta,
        existingEtas: [groundEta],
      ),
      isFalse,
    );
  });

  test('arrow vs ground: far ETAs are accepted', () {
    const playerX = 120.0;
    const screenW = 800.0;
    const groundSpeed = RunnersRushGame.initialSpeed;
    const arrowSpeed =
        RunnersRushGame.initialSpeed * ObstacleComponent.flyingSpeedMultiplier;

    final groundEta = (200.0 - playerX) / groundSpeed;
    final arrowEta = (screenW - playerX) / arrowSpeed;

    expect((arrowEta - groundEta).abs(), greaterThan(RunnersRushGame.minArrivalGap));
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: arrowEta,
        existingEtas: [groundEta],
      ),
      isTrue,
    );
  });

  test('empty existing list always accepts', () {
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: 3.0,
        existingEtas: const [],
      ),
      isTrue,
    );
  });
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

void main() {
  test('spawns a single coin on a long interval (no groups/arcs)', () {
    expect(RunnersRushGame.coinFirstSpawnMin, 6);
    expect(RunnersRushGame.coinSpawnIntervalMin, 9);
    expect(RunnersRushGame.coinSpawnIntervalMax, 15);
    expect(RunnersRushGame.coinHazardArrivalGap, 1.1);
  });

  test('coin arrival must stay 1.1s from every hazard ETA', () {
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: 3.0,
        existingEtas: const [2.0, 4.5],
        minGap: RunnersRushGame.coinHazardArrivalGap,
      ),
      isFalse, // 3.0 vs 2.0 = 1.0 < 1.1
    );
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: 3.0,
        existingEtas: const [1.5, 4.5],
        minGap: RunnersRushGame.coinHazardArrivalGap,
      ),
      isTrue,
    );
    // Flying (faster) and ground hazards share the same ETA rule.
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: 2.0,
        existingEtas: const [2.05],
        minGap: RunnersRushGame.coinHazardArrivalGap,
      ),
      isFalse,
    );
  });

  test('swept collection catches coin at speed 500 with dt 0.05 and 0.1', () {
    // Player body centered near x=100.
    final player = Rect.fromCenter(
      center: const Offset(100, 200),
      width: 40 * RunnersRushGame.coinCollectInflate,
      height: 50 * RunnersRushGame.coinCollectInflate,
    );

    for (final dt in const [0.05, 0.1]) {
      const speed = 500.0;
      final travel = speed * dt;
      // Coin crosses the player during this frame.
      final prevX = 100 + travel * 0.6;
      final currX = prevX - travel;
      final coinPrev = Rect.fromCenter(
        center: Offset(prevX, 200),
        width: 30,
        height: 30,
      );
      final coinCurr = Rect.fromCenter(
        center: Offset(currX, 200),
        width: 30,
        height: 30,
      );
      final sweep = coinPrev.expandToInclude(coinCurr);

      expect(
        RunnersRushGame.sweptCoinOverlapsPlayer(
          coinSweep: sweep,
          playerBody: player,
        ),
        isTrue,
        reason: 'dt=$dt travel=$travel should overlap player',
      );
    }
  });

  test('coin not collected when player is high in the air', () {
    expect(
      PlayerComponent.eligibleForGroundCoin(
        isOnGround: false,
        feetY: 100,
        groundY: 300,
        velocityY: -400, // rising
      ),
      isFalse,
    );
    expect(
      PlayerComponent.eligibleForGroundCoin(
        isOnGround: false,
        feetY: 100,
        groundY: 300,
        velocityY: 50, // falling but >0.12s from ground
      ),
      isFalse,
    );
    expect(
      PlayerComponent.eligibleForGroundCoin(
        isOnGround: false,
        feetY: 295,
        groundY: 300,
        velocityY: 80, // ~0.06s from landing
      ),
      isTrue,
    );
    expect(
      PlayerComponent.eligibleForGroundCoin(
        isOnGround: true,
        feetY: 300,
        groundY: 300,
        velocityY: 0,
      ),
      isTrue,
    );
  });
}

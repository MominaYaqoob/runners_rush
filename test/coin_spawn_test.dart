import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

void main() {
  test('spawns a single coin on a long interval (no groups/arcs)', () {
    expect(RunnersRushGame.coinFirstSpawnMin, 6);
    expect(RunnersRushGame.coinSpawnIntervalMin, 9);
    expect(RunnersRushGame.coinSpawnIntervalMax, 15);
    expect(RunnersRushGame.coinHazardArrivalGap, 1.1);
    expect(RunnersRushGame.coinSpawnRetryInterval, 0.4);
    expect(RunnersRushGame.coinSpawnRetryWindow, 6.0);
  });

  test('coin arrival must stay 1.1s from ground/low hazards and shields', () {
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
    expect(
      RunnersRushGame.arrivalGapOk(
        candidateEta: 2.0,
        existingEtas: const [2.05],
        minGap: RunnersRushGame.coinHazardArrivalGap,
      ),
      isFalse,
    );
  });

  test('high flyers do not block coin spawn; ground and low flyers do', () {
    expect(
      RunnersRushGame.obstacleBlocksCoinSpawn(flying: false),
      isTrue,
    );
    expect(
      RunnersRushGame.obstacleBlocksCoinSpawn(
        flying: true,
        flyingLane: FlyingLane.low,
      ),
      isTrue,
    );
    expect(
      RunnersRushGame.obstacleBlocksCoinSpawn(
        flying: true,
        flyingLane: FlyingLane.high,
      ),
      isFalse,
    );
  });

  test('unsafe coin schedules 0.4s retries then gives up after 6s', () {
    const normal = 12.0;
    // First failure starts retries.
    expect(
      RunnersRushGame.coinTimerLimitAfterAttempt(
        spawned: false,
        alreadyRetrying: false,
        retryElapsedBeforeAttempt: 0,
        normalInterval: normal,
      ),
      RunnersRushGame.coinSpawnRetryInterval,
    );
    // Still inside the window.
    expect(
      RunnersRushGame.coinTimerLimitAfterAttempt(
        spawned: false,
        alreadyRetrying: true,
        retryElapsedBeforeAttempt: 5.2,
        normalInterval: normal,
      ),
      RunnersRushGame.coinSpawnRetryInterval,
    );
    // One more step would reach the window → give up to normal interval.
    expect(
      RunnersRushGame.coinTimerLimitAfterAttempt(
        spawned: false,
        alreadyRetrying: true,
        retryElapsedBeforeAttempt: 5.6,
        normalInterval: normal,
      ),
      normal,
    );
  });

  test('successful spawn resets to the normal 9–15s interval', () {
    const normal = 11.0;
    expect(
      RunnersRushGame.coinTimerLimitAfterAttempt(
        spawned: true,
        alreadyRetrying: true,
        retryElapsedBeforeAttempt: 2.4,
        normalInterval: normal,
      ),
      normal,
    );
    expect(normal, greaterThanOrEqualTo(RunnersRushGame.coinSpawnIntervalMin));
    expect(normal, lessThanOrEqualTo(RunnersRushGame.coinSpawnIntervalMax));
  });

  test('with an obstacle every 1.6s the coin still spawns within 6s', () {
    // High-speed case: travel time ≈1.36s so only one ground obstacle is on
    // screen. Arrivals every 1.6s initially block the coin ETA; retries slide
    // the hazard past until a 1.1s gap opens (within the 6s window).
    const coinEta = 1.36;
    const obstaclePeriod = 1.6;
    const firstArrival = 1.2;

    final delay = RunnersRushGame.coinRetryDelayUntilSafe(
      coinEta: coinEta,
      hazardEtasAt: (t) {
        final etas = <double>[];
        for (var arrival = firstArrival; arrival < 40; arrival += obstaclePeriod) {
          final eta = arrival - t;
          // On-screen while still approaching within the short travel window.
          if (eta > 0 && eta <= 1.5) etas.add(eta);
        }
        return etas;
      },
    );

    expect(delay, isNotNull);
    expect(delay!, lessThanOrEqualTo(RunnersRushGame.coinSpawnRetryWindow));
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

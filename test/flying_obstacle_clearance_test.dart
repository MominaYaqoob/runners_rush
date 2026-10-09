import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Matches [obstacle_flying.png] (895x251).
const _flyingAspect = 895 / 251;

/// Matches [obstacle_stone.png] (~819x364).
const _groundAspect = 819 / 364;

void main() {
  test('jump peak matches PlayerComponent gravity and jumpVelocity', () {
    final expected = PlayerComponent.jumpVelocity *
        PlayerComponent.jumpVelocity /
        (2 * PlayerComponent.gravity);
    expect(PlayerComponent.jumpPeakHeight, closeTo(expected, 0.01));
    expect(PlayerComponent.jumpPeakHeight, closeTo(150.94, 0.5));
  });

  test('high flyer sits above standing run; jump path crosses the shaft at 800x360', () {
    const h = 360.0;
    final groundY = h * (1 - PlayerComponent.groundHeightRatio);
    final playerH = h * PlayerComponent.heightRatio;
    final playerSize = Vector2(playerH, playerH);
    final obsH = h * ObstacleComponent.flyingHeightRatio;
    final obsW = obsH * _flyingAspect;
    final standing = _playerAabb(
      cx: 0,
      bottom: groundY,
      spriteSize: playerSize,
    );
    final flying = _obstacleAabb(
      cx: 0,
      bottom: ObstacleComponent.flyingBottomY(h, obsH, lane: FlyingLane.high),
      spriteSize: Vector2(obsW, obsH),
      flying: true,
    );
    final peakBottom = PlayerComponent.jumpPeakHitboxBottom(h);
    final flyingBottom =
        ObstacleComponent.flyingHitboxBottom(h, obsH, lane: FlyingLane.high);
    final flyingTop =
        ObstacleComponent.flyingHitboxTop(h, obsH, lane: FlyingLane.high);

    expect(standing.overlaps(flying), isFalse);
    expect(flyingBottom, lessThan(standing.top));
    // Peak goes above the shaft; ascent/descent still crosses its band.
    expect(peakBottom, lessThan(flyingTop));
  });

  test('low flyer hitbox center is about 0.35–0.45 of player height', () {
    const h = 360.0;
    final groundY = h * (1 - PlayerComponent.groundHeightRatio);
    final playerH = h * PlayerComponent.heightRatio;
    final obsH = h * ObstacleComponent.flyingHeightRatio;
    final bottom =
        ObstacleComponent.flyingBottomY(h, obsH, lane: FlyingLane.low);
    final offset = ObstacleComponent.hitboxCenterOffset(
      Vector2(obsH, obsH),
      flying: true,
    );
    final centerFromFeet = groundY - (bottom + offset.y);
    final ratio = centerFromFeet / playerH;
    expect(ratio, inInclusiveRange(0.35, 0.45));
    expect(
      ObstacleComponent.flyingLowCenterFromPlayerFeet,
      inInclusiveRange(0.35, 0.45),
    );
  });

  test('speed rises 20 every 10 seconds and caps at 500', () {
    expect(RunnersRushGame.speedAt(0), 200);
    expect(RunnersRushGame.speedAt(10), 220);
    expect(RunnersRushGame.speedAt(30), 260);
    expect(RunnersRushGame.speedAt(150), 500);
    expect(RunnersRushGame.speedAt(200), 500);
  });

  test('spawn interval scale shrinks as speed rises', () {
    expect(RunnersRushGame.spawnScaleAt(200), 1);
    expect(RunnersRushGame.spawnScaleAt(400), 0.5);
    expect(RunnersRushGame.spawnScaleAt(500), closeTo(0.4, 0.001));
  });

  test('spawn mix weights are ground 55 / low 20 / high 25', () {
    expect(RunnersRushGame.groundSpawnWeight, 0.55);
    expect(RunnersRushGame.lowFlyerSpawnWeight, 0.20);
    expect(RunnersRushGame.highFlyerSpawnWeight, 0.25);
    expect(
      RunnersRushGame.groundSpawnWeight +
          RunnersRushGame.lowFlyerSpawnWeight +
          RunnersRushGame.highFlyerSpawnWeight,
      closeTo(1.0, 0.001),
    );
  });

  for (final size in const [
    _Size(800, 360),
    _Size(844, 390),
    _Size(915, 412),
  ]) {
    test('running clears high flyer at ${size.w.toInt()}x${size.h.toInt()}', () {
      final result = _simulate(
        size: size,
        jumpLeadSeconds: null,
        flying: true,
        lane: FlyingLane.high,
      );
      expect(
        result.hit,
        isFalse,
        reason:
            'running should duck under high flyer at ${size.w}x${size.h}: ${result.debug}',
      );
    });

    test('timed jump hits high flyer at ${size.w.toInt()}x${size.h.toInt()}', () {
      var hit = false;
      String debug = '';
      for (final lead in const [0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22]) {
        final result = _simulate(
          size: size,
          jumpLeadSeconds: lead,
          flying: true,
          lane: FlyingLane.high,
        );
        debug = result.debug;
        if (result.hit) {
          hit = true;
          break;
        }
      }
      expect(
        hit,
        isTrue,
        reason:
            'jump should hit high flyer at ${size.w}x${size.h}: $debug',
      );
    });

    test('running hits low flyer at ${size.w.toInt()}x${size.h.toInt()}', () {
      final result = _simulate(
        size: size,
        jumpLeadSeconds: null,
        flying: true,
        lane: FlyingLane.low,
      );
      expect(
        result.hit,
        isTrue,
        reason:
            'running should hit low flyer at ${size.w}x${size.h}: ${result.debug}',
      );
    });

    test('timed jump clears low flyer at ${size.w.toInt()}x${size.h.toInt()}', () {
      var cleared = false;
      String debug = '';
      for (final lead in const [
        0.10,
        0.14,
        0.18,
        0.22,
        0.26,
        0.30,
        0.34,
        0.38,
      ]) {
        final result = _simulate(
          size: size,
          jumpLeadSeconds: lead,
          flying: true,
          lane: FlyingLane.low,
        );
        debug = result.debug;
        if (!result.hit) {
          cleared = true;
          break;
        }
      }
      expect(
        cleared,
        isTrue,
        reason:
            'jump should clear low flyer at ${size.w}x${size.h}: $debug',
      );
    });

    test('jump peak clears high flyer band check at ${size.w.toInt()}x${size.h.toInt()}', () {
      final obsH = size.h * ObstacleComponent.flyingHeightRatio;
      final flyingTop = ObstacleComponent.flyingHitboxTop(
        size.h,
        obsH,
        lane: FlyingLane.high,
      );
      final flyingBottom = ObstacleComponent.flyingHitboxBottom(
        size.h,
        obsH,
        lane: FlyingLane.high,
      );
      final peakBottom = PlayerComponent.jumpPeakHitboxBottom(size.h);
      final groundY = size.h * (1 - PlayerComponent.groundHeightRatio);
      final playerH = size.h * PlayerComponent.heightRatio;
      final standing = _playerAabb(
        cx: 0,
        bottom: groundY,
        spriteSize: Vector2(playerH, playerH),
      );

      expect(flyingBottom, lessThan(standing.top));
      expect(peakBottom, lessThan(flyingTop));
    });

    test('timed jump clears ground obstacle at ${size.w.toInt()}x${size.h.toInt()}', () {
      var cleared = false;
      String debug = '';
      // Snappier jump (~0.7s air): jump later so peak lines up with the hazard.
      for (final lead in const [
        0.12,
        0.16,
        0.18,
        0.20,
        0.22,
        0.24,
        0.26,
        0.28,
      ]) {
        final result = _simulate(
          size: size,
          jumpLeadSeconds: lead,
          flying: false,
        );
        debug = result.debug;
        if (!result.hit) {
          cleared = true;
          break;
        }
      }
      expect(
        cleared,
        isTrue,
        reason:
            'jump should clear ground obstacle at ${size.w}x${size.h}: $debug',
      );
    });

    test('running hits ground obstacle at ${size.w.toInt()}x${size.h.toInt()}', () {
      final result = _simulate(
        size: size,
        jumpLeadSeconds: null,
        flying: false,
      );
      expect(
        result.hit,
        isTrue,
        reason:
            'running should collide with ground obstacle at ${size.w}x${size.h}: ${result.debug}',
      );
    });
  }
}

class _Size {
  const _Size(this.w, this.h);
  final double w;
  final double h;
}

class _Aabb {
  const _Aabb(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;

  bool overlaps(_Aabb other) {
    return left < other.right &&
        right > other.left &&
        top < other.bottom &&
        bottom > other.top;
  }
}

_Aabb _playerAabb({
  required double cx,
  required double bottom,
  required Vector2 spriteSize,
  bool jumping = false,
}) {
  final box = PlayerComponent.hitboxSizeFor(spriteSize, jumping: jumping);
  final offset = PlayerComponent.hitboxCenterOffset(
    spriteSize,
    jumping: jumping,
  );
  final centerX = cx + offset.x;
  final centerY = bottom + offset.y;
  return _Aabb(
    centerX - box.x / 2,
    centerY - box.y / 2,
    centerX + box.x / 2,
    centerY + box.y / 2,
  );
}

_Aabb _obstacleAabb({
  required double cx,
  required double bottom,
  required Vector2 spriteSize,
  required bool flying,
}) {
  final box = ObstacleComponent.hitboxSizeFor(spriteSize, flying: flying);
  final offset = ObstacleComponent.hitboxCenterOffset(
    spriteSize,
    flying: flying,
  );
  final centerX = cx + offset.x;
  final centerY = bottom + offset.y;
  return _Aabb(
    centerX - box.x / 2,
    centerY - box.y / 2,
    centerX + box.x / 2,
    centerY + box.y / 2,
  );
}

class _SimResult {
  const _SimResult({required this.hit, required this.debug});
  final bool hit;
  final String debug;
}

_SimResult _simulate({
  required _Size size,
  required double? jumpLeadSeconds,
  required bool flying,
  FlyingLane lane = FlyingLane.high,
}) {
  final groundY = size.h * (1 - PlayerComponent.groundHeightRatio);
  final playerH = size.h * PlayerComponent.heightRatio;
  final playerW = playerH;
  final playerSize = Vector2(playerW, playerH);
  final playerX = size.w * PlayerComponent.xRatio;

  final obsH = size.h *
      (flying
          ? ObstacleComponent.flyingHeightRatio
          : ObstacleComponent.groundHeightRatio);
  final obsW = obsH * (flying ? _flyingAspect : _groundAspect);
  final obsSize = Vector2(obsW, obsH);
  final obsBottom = flying
      ? ObstacleComponent.flyingBottomY(size.h, obsH, lane: lane)
      : groundY;
  var obsX = size.w + obsW / 2;

  var playerBottom = groundY;
  var velocityY = 0.0;
  var jumped = false;
  var hit = false;

  const dt = 1 / 60;
  final playerBoxSize = PlayerComponent.hitboxSizeFor(playerSize);
  final obsBoxSize = ObstacleComponent.hitboxSizeFor(obsSize, flying: flying);
  final obsOffset = ObstacleComponent.hitboxCenterOffset(
    obsSize,
    flying: flying,
  );
  final obsSpeed = flying
      ? RunnersRushGame.initialSpeed * ObstacleComponent.flyingSpeedMultiplier
      : RunnersRushGame.initialSpeed;
  final contactDx = (playerBoxSize.x + obsBoxSize.x) / 2 + obsOffset.x.abs();

  String snapshot() {
    return 'playerBottom=${playerBottom.toStringAsFixed(1)} '
        'obsBottom=${obsBottom.toStringAsFixed(1)} '
        'obsH=${obsH.toStringAsFixed(1)} obsW=${obsW.toStringAsFixed(1)} '
        'dx=${(obsX - playerX).toStringAsFixed(1)} '
        'lane=$lane '
        'jumpPeak=${PlayerComponent.jumpPeakHeight.toStringAsFixed(1)}';
  }

  for (var step = 0; step < 800; step++) {
    final dx = obsX + obsOffset.x - playerX;
    if (!jumped &&
        jumpLeadSeconds != null &&
        dx <= contactDx + obsSpeed * jumpLeadSeconds) {
      velocityY = PlayerComponent.jumpVelocity;
      jumped = true;
    }

    velocityY += PlayerComponent.gravity * dt;
    playerBottom += velocityY * dt;
    if (playerBottom >= groundY) {
      playerBottom = groundY;
      velocityY = 0;
    }
    obsX -= obsSpeed * dt;

    final jumping = (groundY - playerBottom) > 0.5;
    final playerBox = _playerAabb(
      cx: playerX,
      bottom: playerBottom,
      spriteSize: playerSize,
      jumping: jumping,
    );
    final obsBox = _obstacleAabb(
      cx: obsX,
      bottom: obsBottom,
      spriteSize: obsSize,
      flying: flying,
    );
    if (playerBox.overlaps(obsBox)) {
      hit = true;
      return _SimResult(hit: true, debug: snapshot());
    }
    if (obsX < playerX - playerW) {
      return _SimResult(hit: hit, debug: snapshot());
    }
  }
  return _SimResult(hit: hit, debug: 'timeout ${snapshot()}');
}

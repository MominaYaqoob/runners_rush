import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/player_component.dart';

void main() {
  test('jumpBufferSeconds is 0.15', () {
    expect(PlayerComponent.jumpBufferSeconds, 0.15);
  });

  test('tap 0.1s before landing triggers jump once grounded in jumpLand', () {
    var current = PlayerState.jumpLand;
    var isOnGround = false;
    const hit = false;
    var jumpBuffer = 0.0;
    var velocityY = 120.0;
    var startedJump = false;

    void startJump() {
      startedJump = true;
      jumpBuffer = 0;
      velocityY = PlayerComponent.jumpVelocity;
      current = PlayerState.jumpStart;
    }

    void requestJump() {
      if (PlayerComponent.canJumpNow(
        current: current,
        isOnGround: isOnGround,
        hit: hit,
      )) {
        startJump();
        return;
      }
      jumpBuffer = PlayerComponent.jumpBufferSeconds;
    }

    void tickBuffer(double dt) {
      final next = PlayerComponent.tickJumpBuffer(
        jumpBuffer,
        dt,
        canJump: PlayerComponent.canJumpNow(
          current: current,
          isOnGround: isOnGround,
          hit: hit,
        ),
      );
      if (next < 0) {
        startJump();
        return;
      }
      jumpBuffer = next;
    }

    // Land pose / proximity window — not yet snapped to ground.
    requestJump();
    expect(jumpBuffer, PlayerComponent.jumpBufferSeconds);
    expect(startedJump, isFalse);

    // 0.1 s later, still not on ground.
    tickBuffer(0.1);
    expect(startedJump, isFalse);
    expect(jumpBuffer, closeTo(0.05, 1e-9));

    // Feet plant — buffered tap fires.
    isOnGround = true;
    tickBuffer(1 / 60);
    expect(startedJump, isTrue);
    expect(current, PlayerState.jumpStart);
    expect(velocityY, PlayerComponent.jumpVelocity);
    expect(jumpBuffer, 0);
  });

  test('buffer expires if landing takes longer than jumpBufferSeconds', () {
    var jumpBuffer = PlayerComponent.jumpBufferSeconds;
    var fired = false;

    void tick(double dt, {required bool canJump}) {
      final next = PlayerComponent.tickJumpBuffer(
        jumpBuffer,
        dt,
        canJump: canJump,
      );
      if (next < 0) {
        fired = true;
        jumpBuffer = 0;
        return;
      }
      jumpBuffer = next;
    }

    tick(0.16, canJump: false);
    expect(jumpBuffer, 0);
    tick(1 / 60, canJump: true);
    expect(fired, isFalse);
  });
}

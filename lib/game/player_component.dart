import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

enum PlayerState { running, jumpStart, jumpAir, jumpLand }

/// Runner with a looping run cycle and a one-shot jump sequence.
class PlayerComponent extends SpriteAnimationGroupComponent<PlayerState>
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  static const gravity = 1060.0;
  static const jumpVelocity = -800.0;
  static const groundHeightRatio = 0.165;
  static const heightRatio = 0.46;
  static const xRatio = 0.15;
  static const hitboxScale = 0.75;
  static const runStepTime = 0.075;
  static const jumpStartDuration = 0.08;
  static const jumpLandDuration = 0.08;

  static const _runFrames = [
    'male_run_1.png',
    'male_run_2.png',
    'male_run_3.png',
    'male_run_4.png',
  ];

  PlayerComponent() : super(anchor: Anchor.bottomCenter);

  double velocityY = 0;
  double groundY = 0;
  double _fixedX = 0;
  double _stateTimer = 0;
  bool _hit = false;

  bool get isOnGround =>
      velocityY >= 0 && (position.y - groundY).abs() <= 0.5;

  double get _landProximity => height * 0.18;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final runSprites = [
      for (final path in _runFrames) await game.loadSprite(path),
    ];
    final jumpStart = await game.loadSprite('male_jump_start.png');
    final jumpAir = await game.loadSprite('male_jump.png');
    final jumpLand = await game.loadSprite('male_jump_land.png');

    animations = {
      PlayerState.running: SpriteAnimation.spriteList(
        runSprites,
        stepTime: runStepTime,
        loop: true,
      ),
      PlayerState.jumpStart: SpriteAnimation.spriteList(
        [jumpStart],
        stepTime: jumpStartDuration,
        loop: false,
      ),
      PlayerState.jumpAir: SpriteAnimation.spriteList(
        [jumpAir],
        stepTime: 1,
      ),
      PlayerState.jumpLand: SpriteAnimation.spriteList(
        [jumpLand],
        stepTime: jumpLandDuration,
        loop: false,
      ),
    };
    current = PlayerState.running;
    playing = true;
    paint.filterQuality = FilterQuality.medium;
    _layout();
    position = Vector2(_fixedX, groundY);
    await add(
      RectangleHitbox.relative(
        Vector2.all(hitboxScale),
        parentSize: size,
      ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    _layout();
    if (position.y > groundY) {
      position.y = groundY;
      velocityY = 0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    velocityY += gravity * dt;
    position.y += velocityY * dt;
    position.x = _fixedX;

    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;
    }
    _updateState(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_isObstacle(other)) {
      _hit = true;
      playing = false;
      game.handlePlayerHit();
    }
  }

  void jump() {
    if (_hit || current != PlayerState.running || !isOnGround) return;
    velocityY = jumpVelocity;
    _stateTimer = jumpStartDuration;
    current = PlayerState.jumpStart;
  }

  void _updateState(double dt) {
    if (_hit) return;
    switch (current) {
      case PlayerState.jumpStart:
        _stateTimer -= dt;
        if (_stateTimer <= 0) {
          current = PlayerState.jumpAir;
        }
      case PlayerState.jumpAir:
        final nearGround =
            velocityY >= 0 && position.y >= groundY - _landProximity;
        if (nearGround) {
          _stateTimer = jumpLandDuration;
          current = PlayerState.jumpLand;
        }
      case PlayerState.jumpLand:
        _stateTimer -= dt;
        if (_stateTimer <= 0 && isOnGround) {
          current = PlayerState.running;
          playing = true;
        }
      case PlayerState.running:
      case null:
        break;
    }
  }

  void _layout() {
    final gameSize = game.size;
    groundY = gameSize.y * (1 - groundHeightRatio);
    _fixedX = gameSize.x * xRatio;
    final src = animations?[PlayerState.running]?.frames.first.sprite.srcSize;
    height = gameSize.y * heightRatio;
    if (src != null && src.y > 0) {
      width = height * (src.x / src.y);
    }
    position.x = _fixedX;
  }

  bool _isObstacle(PositionComponent other) {
    return other is ObstacleComponent || other.parent is ObstacleComponent;
  }
}

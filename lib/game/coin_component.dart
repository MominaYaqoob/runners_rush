import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Single scrolling collectible on the run-line. Moves with run speed.
class CoinComponent extends SpriteComponent
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  CoinComponent({
    required this.speed,
    required Vector2 spawnPosition,
  }) : super(position: spawnPosition, anchor: Anchor.center);

  static const spritePath = 'coin.png';
  static const heightRatio = 0.085;
  static const hitboxScale = 0.80;

  final double speed;
  bool _collected = false;
  double _spinT = 0;
  double? _prevX;

  bool get isCollected => _collected;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(spritePath);
    paint.filterQuality = FilterQuality.medium;
    height = game.size.y * heightRatio;
    final src = sprite!.srcSize;
    if (src.y > 0) {
      width = height * (src.x / src.y);
    }
    _prevX = position.x;
    await add(
      RectangleHitbox(
        size: Vector2(width * hitboxScale, height * hitboxScale),
        position: Vector2(width / 2, height / 2),
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void update(double dt) {
    _prevX = position.x;
    super.update(dt);
    position.x -= speed * dt;
    _spinT += dt * 6;
    scale.x = 0.7 + 0.3 * sin(_spinT);
    if (position.x < -width) {
      removeFromParent();
    }
  }

  /// Axis-aligned collectible box at [x] (ignores spin scale).
  Rect collectionRectAt(double x) {
    final w = width * hitboxScale;
    final h = height * hitboxScale;
    return Rect.fromCenter(
      center: Offset(x, position.y),
      width: w,
      height: h,
    );
  }

  /// Swept AABB covering previous → current X for this frame.
  Rect sweepCollectionRect() {
    final prev = _prevX ?? position.x;
    return collectionRectAt(prev).expandToInclude(collectionRectAt(position.x));
  }

  void collect() {
    if (_collected) return;
    _collected = true;
    game.onCoinCollected();
    removeFromParent();
  }
}

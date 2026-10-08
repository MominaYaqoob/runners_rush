import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Scrolling collectible. Moves with the run speed and spins via [scale.x].
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
    super.update(dt);
    position.x -= speed * dt;
    _spinT += dt * 6;
    // Oscillate scale.x between 0.4 and 1.0 for a simple spin.
    scale.x = 0.7 + 0.3 * sin(_spinT);
    if (position.x < -width) {
      removeFromParent();
    }
  }

  void collect() {
    if (_collected) return;
    _collected = true;
    game.onCoinCollected();
    removeFromParent();
  }
}

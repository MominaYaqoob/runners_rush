import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Scrolling shield pickup. Placeholder art: tinted [coin.png].
class ShieldComponent extends SpriteComponent
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  ShieldComponent({
    required this.speed,
    required Vector2 spawnPosition,
  }) : super(position: spawnPosition, anchor: Anchor.center);

  /// No dedicated shield sprite yet — reuse coin with a light-blue tint.
  static const spritePath = 'coin.png';
  static const heightRatio = 0.09;
  static const hitboxScale = 0.85;
  static const placeholderTint = Color(0xFF7EC8FF);

  final double speed;
  bool _collected = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(spritePath);
    paint.filterQuality = FilterQuality.medium;
    paint.colorFilter =
        const ColorFilter.mode(placeholderTint, BlendMode.srcATop);
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
    if (position.x < -width) {
      removeFromParent();
    }
  }

  void collect() {
    if (_collected) return;
    _collected = true;
    game.onShieldCollected();
    removeFromParent();
  }
}

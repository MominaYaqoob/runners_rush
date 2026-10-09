import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/game/shield_painter.dart';

/// Scrolling shield pickup with a code-drawn blue shield icon.
class ShieldComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  ShieldComponent({
    required this.speed,
    required Vector2 spawnPosition,
  }) : super(
          position: spawnPosition,
          anchor: Anchor.center,
        );

  static const heightRatio = 0.09;
  static const hitboxScale = 0.85;

  final double speed;
  bool _collected = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    height = game.size.y * heightRatio;
    width = height; // square icon
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
  void render(Canvas canvas) {
    ShieldPainter.paint(canvas, Size(width, height));
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

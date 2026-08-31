import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Scrolling hazard. Ground sprites sit on [PlayerComponent] ground; flying
/// ones sit at jump height so a leap is needed to clear them.
class ObstacleComponent extends SpriteComponent
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  ObstacleComponent({
    required this.spritePath,
    this.flying = false,
  });

  static const speed = 200.0;
  static const sizeScale = 0.55;
  static const groundHeightRatio = 0.22 * sizeScale;
  static const bushHeightRatio = 0.24 * sizeScale;
  static const flyingHeightRatio = 0.10 * sizeScale;
  static const hitboxScale = 0.75;

  final String spritePath;
  final bool flying;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(spritePath);
    anchor = Anchor.bottomCenter;
    _layout();
    position = Vector2(game.size.x + width / 2, _spawnY);
    await add(
      RectangleHitbox.relative(
        Vector2.all(hitboxScale),
        parentSize: size,
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

  void _layout() {
    final gameSize = game.size;
    final src = sprite?.srcSize;
    height = gameSize.y * _heightRatio;
    if (src != null && src.y > 0) {
      width = height * (src.x / src.y);
    }
  }

  double get _heightRatio {
    if (flying) return flyingHeightRatio;
    if (spritePath.contains('obstacle_2')) return bushHeightRatio;
    return groundHeightRatio;
  }

  double get _spawnY {
    final groundY = game.size.y * (1 - PlayerComponent.groundHeightRatio);
    if (!flying) return groundY;
    final playerHeight = game.size.y * PlayerComponent.heightRatio;
    return groundY - playerHeight * 0.58;
  }
}

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:runners_rush/game/hitbox_debug.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Scrolling hazard. Ground sprites sit on [PlayerComponent] ground; flying
/// ones fly straight overhead, facing the runner.
class ObstacleComponent extends SpriteComponent
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  ObstacleComponent({
    required this.spritePath,
    this.flying = false,
    this.speed = RunnersRushGame.initialSpeed,
  });

  static const sizeScale = 0.42;
  static const groundHeightRatio = 0.22 * sizeScale;
  static const bushHeightRatio = 0.24 * sizeScale;
  /// Arrow height vs screen — large enough to read, short enough to jump over.
  static const flyingHeightRatio = 0.078;
  /// Gap between standing hitbox top and flying hitbox bottom (run-under).
  static const flyingRunUnderGapRatio = 0.04;
  static const flyingSpeedMultiplier = 1.4;
  static final hitboxScale = Vector2(0.50, 0.50);
  /// Hitbox center, as a fraction of sprite height above the feet.
  static const hitboxCenterYFromFeet = 0.40;
  /// Thin shaft only — feathers, trail particles, and padding stay out of the box.
  static final flyingHitboxScale = Vector2(0.40, 0.18);
  static const flyingHitboxCenterYFromFeet = 0.50;
  /// Centered on the shaft (sprite-local). Flip mirrors it toward the runner.
  static const flyingHitboxCenterX = 0.04;

  static Vector2 hitboxSizeFor(Vector2 spriteSize, {required bool flying}) {
    final scale = flying ? flyingHitboxScale : hitboxScale;
    return Vector2(spriteSize.x * scale.x, spriteSize.y * scale.y);
  }

  static Vector2 hitboxCenterOffset(Vector2 spriteSize, {required bool flying}) {
    if (flying) {
      return Vector2(
        spriteSize.x * flyingHitboxCenterX,
        -spriteSize.y * flyingHitboxCenterYFromFeet,
      );
    }
    return Vector2(0, -spriteSize.y * hitboxCenterYFromFeet);
  }

  /// Sprite bottom Y so a standing runner passes under and a full jump goes over.
  static double flyingBottomY(double screenHeight, double obstacleHeight) {
    final playerTop = PlayerComponent.standingHitboxTop(screenHeight);
    final gap = screenHeight * flyingRunUnderGapRatio;
    final desiredHitboxBottom = playerTop - gap;
    final spriteSize = Vector2(obstacleHeight, obstacleHeight);
    final box = hitboxSizeFor(spriteSize, flying: true);
    final offset = hitboxCenterOffset(spriteSize, flying: true);
    return desiredHitboxBottom - offset.y - box.y / 2;
  }

  static double flyingHitboxTop(double screenHeight, double obstacleHeight) {
    final bottom = flyingBottomY(screenHeight, obstacleHeight);
    final spriteSize = Vector2(obstacleHeight, obstacleHeight);
    final box = hitboxSizeFor(spriteSize, flying: true);
    final offset = hitboxCenterOffset(spriteSize, flying: true);
    return bottom + offset.y - box.y / 2;
  }

  static double flyingHitboxBottom(double screenHeight, double obstacleHeight) {
    final bottom = flyingBottomY(screenHeight, obstacleHeight);
    final spriteSize = Vector2(obstacleHeight, obstacleHeight);
    final box = hitboxSizeFor(spriteSize, flying: true);
    final offset = hitboxCenterOffset(spriteSize, flying: true);
    return bottom + offset.y + box.y / 2;
  }

  final String spritePath;
  final bool flying;
  final double speed;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(spritePath);
    anchor = Anchor.bottomCenter;
    _layout();
    position = Vector2(game.size.x + width / 2, _spawnY);
    if (flying) {
      flipHorizontally();
    }
    final box = RectangleHitbox(
      size: hitboxSizeFor(size, flying: flying),
      position: hitboxCenterOffset(size, flying: flying),
      anchor: Anchor.center,
      collisionType: CollisionType.passive,
    );
    HitboxDebug.apply(box, HitboxDebug.obstacleColor);
    await add(box);
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
    return flyingBottomY(game.size.y, height);
  }
}

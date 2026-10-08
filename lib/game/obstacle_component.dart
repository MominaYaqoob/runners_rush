import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:runners_rush/game/hitbox_debug.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Scrolling hazard. Ground sprites sit on [PlayerComponent] ground; flying
/// ones pass just above a standing runner (Chrome-dino style) — run ducks
/// under, jump clips the shaft.
class ObstacleComponent extends SpriteComponent
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  ObstacleComponent({
    required this.spritePath,
    this.flying = false,
    this.speed = RunnersRushGame.initialSpeed,
  });

  static const sizeScale = 0.55;
  static const groundHeightRatio = 0.24 * sizeScale;
  static const bushHeightRatio = 0.26 * sizeScale;
  /// Small flying arrow.
  static const flyingHeightRatio = 0.055;
  /// Above the head so a run clears; jump still clips the shaft.
  static const flyingCenterFromPlayerFeet = 1.08;
  static const flyingSpeedMultiplier = 1.4;
  static final hitboxScale = Vector2(0.50, 0.50);
  /// Hitbox center, as a fraction of sprite height above the feet.
  static const hitboxCenterYFromFeet = 0.40;
  /// Shaft-focused box — tall enough to catch a rising jump.
  static final flyingHitboxScale = Vector2(0.42, 0.38);
  static const flyingHitboxCenterYFromFeet = 0.50;
  /// Centered on the shaft (sprite-local). Flip mirrors it toward the runner.
  static const flyingHitboxCenterX = 0.04;

  static const _rimOuterScale = 1.06;
  static const _rimOuterBlur = 3.5;
  static const _rimOuterTint = Color(0xB3FFF8E7);
  static const _rimInnerScale = 1.03;
  static const _rimInnerBlur = 1.5;
  static const _rimInnerTint = Color(0xE6FFEFC2);

  /// Soft rim baked once per [spritePath] (blur is too costly per-frame).
  static final Map<String, ui.Image> _rimCache = {};
  static final Map<String, Future<ui.Image>> _rimPending = {};

  static Vector2 hitboxSizeFor(Vector2 spriteSize, {required bool flying}) {
    final scale = flying ? flyingHitboxScale : hitboxScale;
    return Vector2(spriteSize.x * scale.x, spriteSize.y * scale.y);
  }

  /// World-space center offset from the feet (bottom-center). Used by tests.
  static Vector2 hitboxCenterOffset(Vector2 spriteSize, {required bool flying}) {
    if (flying) {
      return Vector2(
        spriteSize.x * flyingHitboxCenterX,
        -spriteSize.y * flyingHitboxCenterYFromFeet,
      );
    }
    return Vector2(0, -spriteSize.y * hitboxCenterYFromFeet);
  }

  /// Flame local position (top-left parent space) for a centered hitbox.
  static Vector2 hitboxLocalCenter(Vector2 spriteSize, {required bool flying}) {
    if (flying) {
      return Vector2(
        spriteSize.x / 2 + spriteSize.x * flyingHitboxCenterX,
        spriteSize.y * (1 - flyingHitboxCenterYFromFeet),
      );
    }
    return Vector2(
      spriteSize.x / 2,
      spriteSize.y * (1 - hitboxCenterYFromFeet),
    );
  }

  /// Sprite bottom Y so the shaft sits just above a standing runner.
  static double flyingBottomY(double screenHeight, double obstacleHeight) {
    final groundY = screenHeight * (1 - PlayerComponent.groundHeightRatio);
    final playerH = screenHeight * PlayerComponent.heightRatio;
    final centerY = groundY - playerH * flyingCenterFromPlayerFeet;
    final offset = hitboxCenterOffset(
      Vector2(obstacleHeight, obstacleHeight),
      flying: true,
    );
    return centerY - offset.y;
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

  /// Padding around the sprite in the baked rim (max blur radius × 3 per side).
  static double rimPadPx() => _rimOuterBlur * 3;

  /// Build (or reuse) the soft rim for [spritePath] at the sprite's pixel size.
  static Future<ui.Image> rimImageFor(String spritePath, Sprite sprite) {
    final cached = _rimCache[spritePath];
    if (cached != null) return Future<ui.Image>.value(cached);
    return _rimPending.putIfAbsent(
      spritePath,
      () => _bakeRim(spritePath, sprite),
    );
  }

  static Future<ui.Image> _bakeRim(String spritePath, Sprite sprite) async {
    final srcW = sprite.srcSize.x;
    final srcH = sprite.srcSize.y;
    final pad = rimPadPx();
    final outW = (srcW + pad * 2).ceil();
    final outH = (srcH + pad * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final spriteSize = Vector2(srcW, srcH);
    final cx = pad + srcW / 2;
    final cy = pad + srcH;

    void paintRim({
      required double scale,
      required double blur,
      required Color tint,
    }) {
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.translate(-cx, -cy);
      canvas.translate(pad, pad);
      sprite.render(canvas, size: spriteSize, overridePaint: paint);
      canvas.restore();
    }

    paintRim(scale: _rimOuterScale, blur: _rimOuterBlur, tint: _rimOuterTint);
    paintRim(scale: _rimInnerScale, blur: _rimInnerBlur, tint: _rimInnerTint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    picture.dispose();
    _rimCache[spritePath] = image;
    _rimPending.remove(spritePath);
    return image;
  }

  /// Release all baked rims (call when the Flame game is removed).
  static void disposeRimCache() {
    for (final image in _rimCache.values) {
      image.dispose();
    }
    _rimCache.clear();
    _rimPending.clear();
  }

  final String spritePath;
  final bool flying;
  final double speed;
  ui.Image? _rim;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(spritePath);
    anchor = Anchor.bottomCenter;
    paint.filterQuality = FilterQuality.medium;
    _layout();
    position = Vector2(game.size.x + width / 2, _spawnY);
    if (flying) {
      flipHorizontally();
    }
    _rim = await rimImageFor(spritePath, sprite!);
    final box = RectangleHitbox(
      size: hitboxSizeFor(size, flying: flying),
      position: hitboxLocalCenter(size, flying: flying),
      anchor: Anchor.center,
      collisionType: CollisionType.passive,
    );
    HitboxDebug.apply(box, HitboxDebug.obstacleColor);
    await add(box);
  }

  /// Soft rim from cache + the normal sprite (no per-frame MaskFilter.blur).
  @override
  void render(Canvas canvas) {
    final rim = _rim;
    final s = sprite;
    if (rim != null && s != null && s.srcSize.x > 0 && s.srcSize.y > 0) {
      final pad = rimPadPx();
      final scaleX = size.x / s.srcSize.x;
      final scaleY = size.y / s.srcSize.y;
      final padX = pad * scaleX;
      final padY = pad * scaleY;
      final dest = Rect.fromLTWH(
        -padX,
        -padY,
        size.x + padX * 2,
        size.y + padY * 2,
      );
      canvas.drawImageRect(
        rim,
        Rect.fromLTWH(0, 0, rim.width.toDouble(), rim.height.toDouble()),
        dest,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    super.render(canvas);
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
    // Taller silhouettes (bush / stump / rock pile).
    if (spritePath.contains('obstacle_2') ||
        spritePath.contains('obstacle_stump') ||
        spritePath.contains('obstacle_rocks')) {
      return bushHeightRatio;
    }
    return groundHeightRatio;
  }

  double get _spawnY {
    final groundY = game.size.y * (1 - PlayerComponent.groundHeightRatio);
    if (!flying) return groundY;
    return flyingBottomY(game.size.y, height);
  }
}

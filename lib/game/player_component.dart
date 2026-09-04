import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:runners_rush/game/hitbox_debug.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/character_service.dart';
import 'package:runners_rush/services/settings_service.dart';

enum PlayerState { running, jumpStart, jumpAir, jumpLand }

/// Runner with a looping run cycle and a one-shot jump sequence.
class PlayerComponent extends SpriteAnimationGroupComponent<PlayerState>
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  static const gravity = 1060.0;
  static const jumpVelocity = -800.0;
  static const groundHeightRatio = 0.165;
  static const heightRatio = 0.36;
  static const xRatio = 0.15;
  /// Tight box on the torso/legs so arms, scarf, and bag padding do not collide.
  static final hitboxScale = Vector2(0.50, 0.50);
  /// Hitbox center, as a fraction of sprite height above the feet.
  static const hitboxCenterYFromFeet = 0.36;
  /// Crouched jump pose is compact; keep the airborne box smaller than the run box.
  static final jumpHitboxScale = Vector2(0.40, 0.36);
  static const jumpHitboxCenterYFromFeet = 0.40;

  static Vector2 hitboxSizeFor(Vector2 spriteSize, {bool jumping = false}) {
    final scale = jumping ? jumpHitboxScale : hitboxScale;
    return Vector2(spriteSize.x * scale.x, spriteSize.y * scale.y);
  }

  /// World-space center offset from the feet (bottom-center). Used by tests.
  static Vector2 hitboxCenterOffset(Vector2 spriteSize, {bool jumping = false}) {
    final fromFeet =
        jumping ? jumpHitboxCenterYFromFeet : hitboxCenterYFromFeet;
    return Vector2(0, -spriteSize.y * fromFeet);
  }

  /// Flame local position (top-left parent space) for a centered hitbox.
  static Vector2 hitboxLocalCenter(Vector2 spriteSize, {bool jumping = false}) {
    final fromFeet =
        jumping ? jumpHitboxCenterYFromFeet : hitboxCenterYFromFeet;
    return Vector2(spriteSize.x / 2, spriteSize.y * (1 - fromFeet));
  }

  /// Bottom of the airborne hitbox at jump peak (Y-down).
  static double jumpPeakHitboxBottom(double screenHeight) {
    final groundY = screenHeight * (1 - groundHeightRatio);
    final peakFeetY = groundY - jumpPeakHeight;
    final h = screenHeight * heightRatio;
    final spriteSize = Vector2(h, h);
    final box = hitboxSizeFor(spriteSize, jumping: true);
    final offset = hitboxCenterOffset(spriteSize, jumping: true);
    return peakFeetY + offset.y + box.y / 2;
  }

  /// Peak rise in pixels from [jumpVelocity] and [gravity] (Y-down world).
  static double get jumpPeakHeight =>
      jumpVelocity * jumpVelocity / (2 * gravity);
  static const runStepTime = 0.055;
  static const jumpStartDuration = 0.08;
  static const jumpLandDuration = 0.08;

  static const _runFrameSuffixes = [
    'run_1.png',
    'run_2.png',
    'run_3.png',
    'run_4.png',
    'run_5.png',
    'run_6.png',
    'run_7.png',
    'run_8.png',
  ];

  PlayerComponent() : super(anchor: Anchor.bottomCenter);

  double velocityY = 0;
  double groundY = 0;
  double _fixedX = 0;
  double _stateTimer = 0;
  bool _hit = false;
  Set<String>? _imageAssets;
  RectangleHitbox? _bodyHitbox;

  bool get isOnGround =>
      velocityY >= 0 && (position.y - groundY).abs() <= 0.5;

  double get _landProximity => height * 0.18;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final selected = await CharacterService.getSelectedCharacter();
    final prefix =
        selected == CharacterService.female
            ? CharacterService.female
            : CharacterService.male;

    final runSprites = await _loadRunSprites(prefix);
    final jumpStart = await _loadPoseSprite(
      prefix,
      preferred: 'jump_start.png',
      fallbacks: const ['jump.png', 'run.png'],
    );
    final jumpAir = await _loadPoseSprite(
      prefix,
      preferred: 'jump.png',
      fallbacks: const ['jump_start.png', 'run.png'],
    );
    final jumpLand = await _loadPoseSprite(
      prefix,
      preferred: 'jump_land.png',
      fallbacks: const ['jump.png', 'run.png'],
    );

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
    paint.filterQuality = FilterQuality.high;
    _layout();
    position = Vector2(_fixedX, groundY);
    _bodyHitbox = RectangleHitbox(
      size: _hitboxSize,
      position: _hitboxPosition,
      anchor: Anchor.center,
      collisionType: CollisionType.active,
    );
    HitboxDebug.apply(_bodyHitbox!, HitboxDebug.playerColor);
    await add(_bodyHitbox!);
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
    _syncHitbox();
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
    _playJumpSfx();
    velocityY = jumpVelocity;
    _stateTimer = jumpStartDuration;
    current = PlayerState.jumpStart;
  }

  Future<void> _playJumpSfx() async {
    if (!await SettingsService.getSoundEnabled()) return;
    if (!AudioService.shouldPlay) return;
    AudioService.ensureReady();
    try {
      FlameAudio.play('jump.mp3').ignore();
    } catch (_) {}
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
    _syncHitbox();
  }

  Vector2 get _hitboxSize => hitboxSizeFor(size, jumping: !isOnGround);

  Vector2 get _hitboxPosition =>
      hitboxLocalCenter(size, jumping: !isOnGround);

  void _syncHitbox() {
    final box = _bodyHitbox;
    if (box == null) return;
    box.size.setFrom(_hitboxSize);
    box.position.setFrom(_hitboxPosition);
  }

  /// Smooth multi-frame run cycle for [prefix], falling back to that
  /// character's single `*_run.png` only (never another character's body).
  Future<List<Sprite>> _loadRunSprites(String prefix) async {
    final frames = <Sprite>[];
    for (final suffix in _runFrameSuffixes) {
      final name = '${prefix}_$suffix';
      if (prefix == CharacterService.male || await _hasImage(name)) {
        try {
          frames.add(await game.loadSprite(name));
        } catch (_) {}
      }
    }
    if (frames.length >= 2) return frames;

    final baseRun = '${prefix}_run.png';
    return [await game.loadSprite(baseRun)];
  }

  Future<Sprite> _loadPoseSprite(
    String prefix, {
    required String preferred,
    required List<String> fallbacks,
  }) async {
    for (final suffix in [preferred, ...fallbacks]) {
      final name = '${prefix}_$suffix';
      if (prefix == CharacterService.male || await _hasImage(name)) {
        try {
          return await game.loadSprite(name);
        } catch (_) {}
      }
    }
    return game.loadSprite('${prefix}_run.png');
  }

  Future<bool> _hasImage(String filename) async {
    _imageAssets ??= (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .toSet();
    return _imageAssets!.contains('assets/images/$filename');
  }

  bool _isObstacle(PositionComponent other) {
    return other is ObstacleComponent || other.parent is ObstacleComponent;
  }
}

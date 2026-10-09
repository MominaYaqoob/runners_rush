import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:runners_rush/game/coin_component.dart';
import 'package:runners_rush/game/hitbox_debug.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/game/shield_component.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/character_service.dart';
import 'package:runners_rush/services/settings_service.dart';

enum PlayerState { running, jumpStart, jumpAir, jumpLand }

/// Outcome of an obstacle collision against shield / invulnerability.
enum ObstacleHitOutcome {
  absorbedByShield,
  ignoredInvulnerable,
  fatal,
}

/// Runner with a looping run cycle and a one-shot jump sequence.
class PlayerComponent extends SpriteAnimationGroupComponent<PlayerState>
    with CollisionCallbacks, HasGameReference<RunnersRushGame> {
  /// Snappy jump: peak ≈ 151px, air time ≈ 0.70s.
  static const gravity = 2450.0;
  static const jumpVelocity = -860.0;
  static const groundHeightRatio = 0.165;
  static const heightRatio = 0.32;
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
  static const runStepTime = 0.08;
  /// Scaled with shorter air time (was 0.12 / 0.14 at the old jump).
  static const jumpStartDuration = 0.074;
  static const jumpLandDuration = 0.087;
  static const jumpAirStepTime = 0.08;
  /// How long a jump tap is remembered while airborne / landing.
  static const jumpBufferSeconds = 0.15;
  /// Invulnerability after a shield absorbs a hit.
  static const shieldInvulnerabilitySeconds = 1.0;

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

  static const _jumpStartSuffixes = [
    'jump_1.png',
    'jump_2.png',
  ];

  static const _jumpAirSuffixes = [
    'jump_3.png',
    'jump_4.png',
    'jump_5.png',
    'jump_6.png',
  ];

  static const _jumpLandSuffixes = [
    'jump_7.png',
    'jump_8.png',
  ];

  PlayerComponent() : super(anchor: Anchor.bottomCenter);

  double velocityY = 0;
  double groundY = 0;
  double _fixedX = 0;
  double _stateTimer = 0;
  double _jumpBuffer = 0;
  double _invulnerableRemaining = 0;
  bool hasShield = false;
  bool _hit = false;
  Set<String>? _imageAssets;
  RectangleHitbox? _bodyHitbox;

  bool get isInvulnerable => _invulnerableRemaining > 0;

  bool get isOnGround =>
      velocityY >= 0 && (position.y - groundY).abs() <= 0.5;

  /// True when grounded or falling and about to land within [nearLandingSeconds].
  bool canCollectGroundCoin({double nearLandingSeconds = 0.12}) {
    return eligibleForGroundCoin(
      isOnGround: isOnGround,
      feetY: position.y,
      groundY: groundY,
      velocityY: velocityY,
      nearLandingSeconds: nearLandingSeconds,
    );
  }

  /// Pure eligibility check used by gameplay and unit tests.
  @visibleForTesting
  static bool eligibleForGroundCoin({
    required bool isOnGround,
    required double feetY,
    required double groundY,
    required double velocityY,
    double nearLandingSeconds = 0.12,
  }) {
    if (isOnGround) return true;
    if (velocityY <= 0) return false;
    final dy = groundY - feetY;
    if (dy <= 0) return true;
    return dy / velocityY <= nearLandingSeconds;
  }

  /// Player body AABB in world space (optionally scaled by [inflateFactor]).
  Rect bodyWorldRect({double inflateFactor = 1.0}) {
    final box = hitboxSizeFor(size, jumping: !isOnGround);
    final offset = hitboxCenterOffset(size, jumping: !isOnGround);
    final center = Offset(position.x + offset.x, position.y + offset.y);
    return Rect.fromCenter(
      center: center,
      width: box.x * inflateFactor,
      height: box.y * inflateFactor,
    );
  }

  bool get _canJump =>
      canJumpNow(current: current, isOnGround: isOnGround, hit: _hit);

  /// Shared jump gate used by [jump] / buffer and unit tests.
  @visibleForTesting
  static bool canJumpNow({
    required PlayerState? current,
    required bool isOnGround,
    required bool hit,
  }) {
    return !hit &&
        isOnGround &&
        (current == PlayerState.running || current == PlayerState.jumpLand);
  }

  /// Counts down a stored jump tap; returns true when a jump should start.
  @visibleForTesting
  static double tickJumpBuffer(
    double remaining,
    double dt, {
    required bool canJump,
  }) {
    if (remaining <= 0) return 0;
    remaining -= dt;
    if (canJump) return -1; // sentinel: consume / fire
    if (remaining < 0) return 0;
    return remaining;
  }

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
    final jumpStartSprites = await _loadNamedSprites(prefix, _jumpStartSuffixes);
    final jumpAirSprites = await _loadNamedSprites(prefix, _jumpAirSuffixes);
    final jumpLandSprites = await _loadNamedSprites(prefix, _jumpLandSuffixes);

    animations = {
      PlayerState.running: SpriteAnimation.spriteList(
        runSprites,
        stepTime: runStepTime,
        loop: true,
      ),
      PlayerState.jumpStart: SpriteAnimation.spriteList(
        jumpStartSprites,
        stepTime: jumpStartDuration / jumpStartSprites.length,
        loop: false,
      ),
      PlayerState.jumpAir: SpriteAnimation.spriteList(
        jumpAirSprites,
        stepTime: jumpAirStepTime,
        loop: true,
      ),
      PlayerState.jumpLand: SpriteAnimation.spriteList(
        jumpLandSprites,
        stepTime: jumpLandDuration / jumpLandSprites.length,
        loop: false,
      ),
    };
    current = PlayerState.running;
    playing = true;
    paint.filterQuality = FilterQuality.none;
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

  /// Clears shield and invulnerability (new run / restart).
  void resetPowerUps() {
    hasShield = false;
    _invulnerableRemaining = 0;
  }

  void activateShield() {
    hasShield = true;
  }

  /// Resolves an obstacle contact. Used by collision and unit tests.
  ObstacleHitOutcome resolveObstacleHit() {
    if (_invulnerableRemaining > 0) {
      return ObstacleHitOutcome.ignoredInvulnerable;
    }
    if (hasShield) {
      hasShield = false;
      _invulnerableRemaining = shieldInvulnerabilitySeconds;
      return ObstacleHitOutcome.absorbedByShield;
    }
    return ObstacleHitOutcome.fatal;
  }

  /// Advances invulnerability timer (also called from [update]).
  @visibleForTesting
  void tickInvulnerability(double dt) {
    if (_invulnerableRemaining <= 0) return;
    _invulnerableRemaining -= dt;
    if (_invulnerableRemaining < 0) _invulnerableRemaining = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    tickInvulnerability(dt);
    velocityY += gravity * dt;
    position.y += velocityY * dt;
    position.x = _fixedX;

    // Keep the sprite from leaving the top of phone landscape screens.
    final minFeetY = height * 0.12;
    if (position.y < minFeetY) {
      position.y = minFeetY;
      if (velocityY < 0) velocityY = 0;
    }

    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;
    }
    _syncHitbox();
    _updateState(dt);
    _tickJumpBuffer(dt);
  }

  @override
  void render(Canvas canvas) {
    if (hasShield) {
      final radius = (width > height ? width : height) * 0.55;
      final center = Offset(width / 2, height * 0.45);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0x5540B0FF)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xAA7EC8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    super.render(canvas);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    final coin = _asCoin(other);
    if (coin != null) {
      coin.collect();
      return;
    }
    final shield = _asShield(other);
    if (shield != null) {
      shield.collect();
      return;
    }
    if (_isObstacle(other)) {
      switch (resolveObstacleHit()) {
        case ObstacleHitOutcome.absorbedByShield:
          _asObstacle(other)?.removeFromParent();
          game.onShieldConsumed();
          return;
        case ObstacleHitOutcome.ignoredInvulnerable:
          return;
        case ObstacleHitOutcome.fatal:
          _hit = true;
          playing = false;
          game.handlePlayerHit();
      }
    }
  }

  void jump() {
    if (_hit) return;
    if (_canJump) {
      _startJump();
      return;
    }
    _jumpBuffer = jumpBufferSeconds;
  }

  /// Drops a pending buffered jump (pause / resume / lifecycle interrupt).
  void clearJumpBuffer() {
    _jumpBuffer = 0;
  }

  void _startJump() {
    _jumpBuffer = 0;
    _playJumpSfx();
    velocityY = jumpVelocity;
    _stateTimer = jumpStartDuration;
    current = PlayerState.jumpStart;
  }

  void _tickJumpBuffer(double dt) {
    if (_jumpBuffer <= 0) return;
    final next = tickJumpBuffer(_jumpBuffer, dt, canJump: _canJump);
    if (next < 0) {
      _startJump();
      return;
    }
    _jumpBuffer = next;
  }

  Future<void> _playJumpSfx() async {
    if (!await SettingsService.getSoundEnabled()) return;
    AudioService.playJump();
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

  /// Load each named pose frame for [prefix]; if missing, fall back to a
  /// single pose sprite for that character (never swap bodies).
  Future<List<Sprite>> _loadNamedSprites(
    String prefix,
    List<String> suffixes,
  ) async {
    final frames = <Sprite>[];
    for (final suffix in suffixes) {
      final name = '${prefix}_$suffix';
      if (prefix == CharacterService.male || await _hasImage(name)) {
        try {
          frames.add(await game.loadSprite(name));
        } catch (_) {}
      }
    }
    if (frames.isNotEmpty) return frames;

    // Female (and any other char) may only ship single jump poses.
    final preferred = switch (suffixes.first) {
      final s when s.startsWith('jump_1') || s.startsWith('jump_2') =>
        'jump_start.png',
      final s when s.startsWith('jump_7') || s.startsWith('jump_8') =>
        'jump_land.png',
      _ => 'jump.png',
    };
    return [
      await _loadPoseSprite(
        prefix,
        preferred: preferred,
        fallbacks: const ['jump.png', 'jump_start.png', 'run.png'],
      ),
    ];
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

  ObstacleComponent? _asObstacle(PositionComponent other) {
    if (other is ObstacleComponent) return other;
    final parent = other.parent;
    return parent is ObstacleComponent ? parent : null;
  }

  CoinComponent? _asCoin(PositionComponent other) {
    if (other is CoinComponent) return other;
    final parent = other.parent;
    return parent is CoinComponent ? parent : null;
  }

  ShieldComponent? _asShield(PositionComponent other) {
    if (other is ShieldComponent) return other;
    final parent = other.parent;
    return parent is ShieldComponent ? parent : null;
  }
}

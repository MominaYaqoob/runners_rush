import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/game/coin_component.dart';
import 'package:runners_rush/game/cover_background_component.dart';
import 'package:runners_rush/game/ground_strip_component.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/shield_component.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/character_service.dart';
import 'package:runners_rush/services/score_service.dart';
import 'package:runners_rush/services/settings_service.dart';
import 'package:runners_rush/services/shop_service.dart';
import 'package:vibration/vibration.dart';

class RunnersRushGame extends FlameGame
    with TapCallbacks, HasCollisionDetection {
  static const placeholderColor = Color(0xFF2A1A3A);
  static const initialSpeed = 200.0;
  static const maxSpeed = 500.0;
  static const speedIncreasePerSecond = 2.0;
  static const spawnIntervalMin = 2.5;
  static const spawnIntervalMax = 4.0;
  static const minSpawnInterval = 1.0;
  /// Minimum seconds between obstacle arrivals at the player.
  static const minArrivalGap = 1.5;
  /// Coin must arrive ≥ this many seconds from every hazard (obstacles + shields).
  static const coinHazardArrivalGap = 1.1;
  static const flyingAtLeastEvery = 4;
  /// Spawn mix: ground 55%, low flyer 20%, high flyer 25%.
  static const groundSpawnWeight = 0.55;
  static const lowFlyerSpawnWeight = 0.20;
  static const highFlyerSpawnWeight = 0.25;
  /// After a ground/low (jump) obstacle, no high flyer within this arrival gap.
  static const highFlyerAfterJumpObstacleGap = 1.3;
  /// First single ground coin appears after this many seconds.
  static const coinFirstSpawnMin = 6.0;
  static const coinSpawnIntervalMin = 9.0;
  static const coinSpawnIntervalMax = 15.0;
  /// Player body AABB scale used when sweeping coin collection.
  static const coinCollectInflate = 1.15;
  static const coinNearLandingSeconds = 0.12;
  static const shieldSpawnIntervalMin = 25.0;
  static const shieldSpawnIntervalMax = 40.0;

  static const _groundSprites = [
    'obstacle_stone.png',
    'obstacle_rocks.png',
    'obstacle_stump.png',
    'obstacle_2.png',
  ];
  static const _flyingSprite = 'obstacle_flying.png';

  CoverBackgroundComponent? _background;
  GroundStripComponent? _ground;
  late final PlayerComponent player;
  late final Timer _spawnTimer;
  late final Timer _coinTimer;
  late final Timer _shieldTimer;
  final Random _random = Random();
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> coinsCollected = ValueNotifier<int>(0);
  final ValueNotifier<bool> shieldActive = ValueNotifier<bool>(false);
  double _elapsed = 0;
  bool _isGameOver = false;
  double currentSpeed = initialSpeed;
  int _spawnsSinceFlying = 0;
  int _consecutiveFlyers = 0;
  String? _lastGroundSprite;
  String? _secondLastGroundSprite;

  /// Seconds since the Flame game started. Used by later gameplay systems.
  double get elapsed => _elapsed;

  bool get isGameOver => _isGameOver;

  static double speedAt(double elapsed) {
    return min(
      maxSpeed,
      initialSpeed + elapsed * speedIncreasePerSecond,
    );
  }

  static double spawnScaleAt(double speed) {
    return initialSpeed / speed.clamp(initialSpeed, maxSpeed);
  }

  /// True when [candidateEta] is at least [minGap] seconds from every existing
  /// obstacle arrival time (handles faster flying arrows vs ground obstacles).
  static bool arrivalGapOk({
    required double candidateEta,
    required Iterable<double> existingEtas,
    double minGap = minArrivalGap,
  }) {
    for (final eta in existingEtas) {
      if ((candidateEta - eta).abs() < minGap) return false;
    }
    return true;
  }

  /// Swept coin AABB vs inflated player body (pure helper for gameplay + tests).
  static bool sweptCoinOverlapsPlayer({
    required Rect coinSweep,
    required Rect playerBody,
  }) {
    return coinSweep.overlaps(playerBody);
  }

  @override
  Color backgroundColor() => placeholderColor;

  @override
  void onRemove() {
    ObstacleComponent.disposeRimCache();
    super.onRemove();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    try {
      _background = CoverBackgroundComponent();
      await camera.backdrop.add(_background!);
    } catch (_) {
      _background = null;
    }

    try {
      _ground = GroundStripComponent();
      await world.add(_ground!);
    } catch (_) {
      _ground = null;
    }

    player = PlayerComponent();
    await world.add(player);

    _spawnTimer = Timer(
      _nextSpawnInterval(),
      onTick: _spawnObstacle,
      repeat: true,
    );
    _coinTimer = Timer(
      coinFirstSpawnMin,
      onTick: _spawnCoin,
      repeat: true,
    );
    _shieldTimer = Timer(
      _nextShieldInterval(),
      onTick: _spawnShield,
      repeat: true,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    _background?.layoutTo(size);
    _ground?.layoutTo(size);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isGameOver) return;
    _elapsed += dt;
    currentSpeed = speedAt(_elapsed);
    score.value = (_elapsed * 10).floor();
    _spawnTimer.update(dt);
    _coinTimer.update(dt);
    _shieldTimer.update(dt);
    _collectCoinsSwept();
  }

  /// Reliable coin pickup: swept X motion vs inflated player body.
  void _collectCoinsSwept() {
    if (!player.canCollectGroundCoin(
      nearLandingSeconds: coinNearLandingSeconds,
    )) {
      return;
    }
    final body = player.bodyWorldRect(inflateFactor: coinCollectInflate);
    for (final coin in world.children.whereType<CoinComponent>().toList()) {
      if (coin.isCollected) continue;
      if (sweptCoinOverlapsPlayer(
        coinSweep: coin.sweepCollectionRect(),
        playerBody: body,
      )) {
        coin.collect();
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_isGameOver) return;
    player.jump();
  }

  void handlePlayerHit() {
    if (_isGameOver) return;
    final capturedScore = score.value;
    _isGameOver = true;
    pauseEngine();
    _playHitFeedback();
    unawaited(_finishRun(capturedScore));
  }

  /// Persists the run first (no [BuildContext]), then navigates to Game Over
  /// when a mounted context is available.
  Future<void> _finishRun(int score) async {
    final previousBest = await ScoreService.getHighScore();
    await ScoreService.saveHighScoreIfBetter(score);
    final earnedCoins = ShopService.coinsForRun(
      score: score,
      collected: coinsCollected.value,
    );
    if (earnedCoins > 0) {
      await ShopService.addCoins(earnedCoins);
      AudioService.playCoin();
    }
    final character = await CharacterService.getSelectedCharacter();
    final best = score > previousBest ? score : previousBest;

    final ctx = buildContext;
    if (ctx == null || !ctx.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pushReplacementNamed(
        AppRoutes.gameOver,
        arguments: {
          'score': score,
          'best': best,
          'isNewHighScore': score > previousBest,
          'coinsEarned': earnedCoins,
          'character': character,
        },
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _playHitFeedback() async {
    if (await SettingsService.getSoundEnabled() && AudioService.shouldPlay) {
      AudioService.ensureReady();
      try {
        FlameAudio.play('collision.mp3').ignore();
      } catch (_) {}
    }
    if (!await SettingsService.getVibrationEnabled()) return;
    final inWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (inWidgetTest) return;
    try {
      if (await Vibration.hasVibrator() != true) return;
      await Vibration.vibrate(duration: 200);
    } catch (_) {}
  }

  double _nextSpawnInterval() {
    final scale = spawnScaleAt(currentSpeed);
    final minInterval = max(minSpawnInterval, spawnIntervalMin * scale);
    final maxInterval = max(minInterval, spawnIntervalMax * scale);
    return minInterval + _random.nextDouble() * (maxInterval - minInterval);
  }

  void onCoinCollected() {
    coinsCollected.value++;
    AudioService.playCoin();
  }

  void onShieldCollected() {
    player.activateShield();
    shieldActive.value = true;
  }

  void onShieldConsumed() {
    shieldActive.value = false;
  }

  /// Clears shield HUD / player power-ups for a fresh run.
  void resetShieldState() {
    if (isLoaded) {
      player.resetPowerUps();
    }
    shieldActive.value = false;
  }

  void _spawnObstacle() {
    if (_isGameOver) return;
    _spawnTimer.limit = _nextSpawnInterval();

    final kind = _pickObstacleKind();
    final flying = kind != _ObstacleKind.ground;
    final flyingLane =
        kind == _ObstacleKind.lowFlyer ? FlyingLane.low : FlyingLane.high;
    final spritePath = flying ? _flyingSprite : _pickGroundSprite();
    final speed = flying
        ? currentSpeed * ObstacleComponent.flyingSpeedMultiplier
        : currentSpeed;

    if (!_hasEnoughArrivalSpacing(speed)) return;

    if (kind == _ObstacleKind.highFlyer) {
      final playerX = player.position.x;
      final eta = (size.x - playerX) / speed;
      if (!_highFlyerAfterJumpFair(eta, playerX)) return;
    }

    if (flying) {
      _consecutiveFlyers++;
      _spawnsSinceFlying = 0;
    } else {
      _consecutiveFlyers = 0;
      _spawnsSinceFlying++;
      _secondLastGroundSprite = _lastGroundSprite;
      _lastGroundSprite = spritePath;
    }

    world.add(
      ObstacleComponent(
        spritePath: spritePath,
        flying: flying,
        flyingLane: flyingLane,
        speed: speed,
      ),
    );
  }

  /// Ground 55% / low 20% / high 25%. Never 3 flyers in a row; flyer at least
  /// every [flyingAtLeastEvery] spawns.
  _ObstacleKind _pickObstacleKind() {
    final forceFlyer = (_spawnsSinceFlying + 1) >= flyingAtLeastEvery;
    if (_consecutiveFlyers >= 2) {
      return _ObstacleKind.ground;
    }
    if (forceFlyer) {
      final flyerTotal = lowFlyerSpawnWeight + highFlyerSpawnWeight;
      return _random.nextDouble() < (lowFlyerSpawnWeight / flyerTotal)
          ? _ObstacleKind.lowFlyer
          : _ObstacleKind.highFlyer;
    }
    final r = _random.nextDouble();
    if (r < groundSpawnWeight) return _ObstacleKind.ground;
    if (r < groundSpawnWeight + lowFlyerSpawnWeight) {
      return _ObstacleKind.lowFlyer;
    }
    return _ObstacleKind.highFlyer;
  }

  /// High flyer must not arrive within [highFlyerAfterJumpObstacleGap] after a
  /// ground or low flyer (player still airborne from jumping those).
  bool _highFlyerAfterJumpFair(double candidateEta, double playerX) {
    for (final o in world.children.whereType<ObstacleComponent>()) {
      if (!o.isJumpObstacle) continue;
      final eta = (o.position.x - playerX) / o.speed;
      if (candidateEta >= eta &&
          candidateEta - eta < highFlyerAfterJumpObstacleGap) {
        return false;
      }
    }
    return true;
  }

  void _spawnCoin() {
    if (_isGameOver) return;
    _coinTimer.limit = _nextCoinInterval();

    final speed = currentSpeed;
    if (speed <= 0) return;

    final playerX = player.position.x;
    final startX = size.x + size.y * 0.12;
    final groundY = size.y * (1 - PlayerComponent.groundHeightRatio);
    final playerH = size.y * PlayerComponent.heightRatio;
    // Straight run-line only (same height as standing torso/hitbox center).
    final y = groundY - playerH * PlayerComponent.hitboxCenterYFromFeet;
    final eta = (startX - playerX) / speed;

    // Skip this spawn if unsafe — do not retry until the next timer tick.
    if (!_coinArrivalSafe(eta, playerX)) return;

    world.add(
      CoinComponent(
        speed: speed,
        spawnPosition: Vector2(startX, y),
      ),
    );
  }

  bool _coinArrivalSafe(double candidateEta, double playerX) {
    if (!arrivalGapOk(
      candidateEta: candidateEta,
      existingEtas: _obstacleEtas(playerX),
      minGap: coinHazardArrivalGap,
    )) {
      return false;
    }
    if (!arrivalGapOk(
      candidateEta: candidateEta,
      existingEtas: _shieldEtas(playerX),
      minGap: coinHazardArrivalGap,
    )) {
      return false;
    }
    return arrivalGapOk(
      candidateEta: candidateEta,
      existingEtas: _coinEtas(playerX),
      minGap: coinHazardArrivalGap,
    );
  }

  double _nextCoinInterval() {
    return coinSpawnIntervalMin +
        _random.nextDouble() * (coinSpawnIntervalMax - coinSpawnIntervalMin);
  }

  void _spawnShield() {
    if (_isGameOver) return;
    _shieldTimer.limit = _nextShieldInterval();

    final speed = currentSpeed;
    if (speed <= 0) return;

    final playerX = player.position.x;
    final startX = size.x + size.y * 0.12;
    final groundY = size.y * (1 - PlayerComponent.groundHeightRatio);
    final playerH = size.y * PlayerComponent.heightRatio;
    final y = groundY - playerH * PlayerComponent.hitboxCenterYFromFeet;
    final eta = (startX - playerX) / speed;

    if (!arrivalGapOk(
      candidateEta: eta,
      existingEtas: _obstacleEtas(playerX),
    )) {
      return;
    }
    if (!arrivalGapOk(
      candidateEta: eta,
      existingEtas: _coinEtas(playerX),
      minGap: coinHazardArrivalGap,
    )) {
      return;
    }
    if (!arrivalGapOk(
      candidateEta: eta,
      existingEtas: _shieldEtas(playerX),
      minGap: coinHazardArrivalGap,
    )) {
      return;
    }

    world.add(
      ShieldComponent(
        speed: speed,
        spawnPosition: Vector2(startX, y),
      ),
    );
  }

  double _nextShieldInterval() {
    return shieldSpawnIntervalMin +
        _random.nextDouble() *
            (shieldSpawnIntervalMax - shieldSpawnIntervalMin);
  }

  String _pickGroundSprite() {
    final options = List<String>.from(_groundSprites);
    if (_lastGroundSprite != null &&
        _lastGroundSprite == _secondLastGroundSprite) {
      options.remove(_lastGroundSprite);
    }
    return options[_random.nextInt(options.length)];
  }

  bool _hasEnoughArrivalSpacing(double candidateSpeed) {
    if (candidateSpeed <= 0) return false;
    final playerX = player.position.x;
    final candidateEta = (size.x - playerX) / candidateSpeed;
    if (!arrivalGapOk(
      candidateEta: candidateEta,
      existingEtas: _obstacleEtas(playerX),
    )) {
      return false;
    }
    if (!arrivalGapOk(
      candidateEta: candidateEta,
      existingEtas: _coinEtas(playerX),
      minGap: coinHazardArrivalGap,
    )) {
      return false;
    }
    return arrivalGapOk(
      candidateEta: candidateEta,
      existingEtas: _shieldEtas(playerX),
      minGap: coinHazardArrivalGap,
    );
  }

  Iterable<double> _obstacleEtas(double playerX) {
    return world.children.whereType<ObstacleComponent>().map(
          (o) => (o.position.x - playerX) / o.speed,
        );
  }

  Iterable<double> _coinEtas(double playerX) {
    return world.children.whereType<CoinComponent>().map(
          (c) => (c.position.x - playerX) / c.speed,
        );
  }

  Iterable<double> _shieldEtas(double playerX) {
    return world.children.whereType<ShieldComponent>().map(
          (s) => (s.position.x - playerX) / s.speed,
        );
  }
}

enum _ObstacleKind { ground, lowFlyer, highFlyer }

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
  /// Gap between coin and obstacle arrivals (seconds).
  static const coinObstacleArrivalGap = 0.8;
  static const flyingAtLeastEvery = 4;
  static const flyingChance = 0.25;
  static const coinGroupSpacingFactor = 0.16;
  static const coinFirstSpawnMin = 3.0;
  static const coinSpawnIntervalMin = 4.0;
  static const coinSpawnIntervalMax = 7.0;
  static const coinGroupMinCount = 3;
  static const coinGroupMaxCount = 5;

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
  final Random _random = Random();
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> coinsCollected = ValueNotifier<int>(0);
  double _elapsed = 0;
  bool _isGameOver = false;
  double currentSpeed = initialSpeed;
  int _spawnsSinceFlying = 0;
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

  /// World positions for a coin group (flat run-line or jump arc).
  static List<Vector2> coinGroupPositions({
    required int count,
    required bool arc,
    required double startX,
    required double baseY,
    required double spacing,
    required double arcHeight,
  }) {
    final clamped = count.clamp(coinGroupMinCount, coinGroupMaxCount);
    final positions = <Vector2>[];
    for (var i = 0; i < clamped; i++) {
      final x = startX + i * spacing;
      var y = baseY;
      if (arc && clamped > 1) {
        y = baseY - arcHeight * sin(pi * i / (clamped - 1));
      }
      positions.add(Vector2(x, y));
    }
    return positions;
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
      onTick: _spawnCoinGroup,
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

  void _spawnObstacle() {
    if (_isGameOver) return;
    _spawnTimer.limit = _nextSpawnInterval();

    final forceFlying = (_spawnsSinceFlying + 1) >= flyingAtLeastEvery;
    final flying = forceFlying || _random.nextDouble() < flyingChance;
    final spritePath = flying ? _flyingSprite : _pickGroundSprite();
    final speed = flying
        ? currentSpeed * ObstacleComponent.flyingSpeedMultiplier
        : currentSpeed;

    if (!_hasEnoughArrivalSpacing(speed)) return;

    _spawnsSinceFlying = flying ? 0 : _spawnsSinceFlying + 1;
    if (!flying) {
      _secondLastGroundSprite = _lastGroundSprite;
      _lastGroundSprite = spritePath;
    }

    world.add(
      ObstacleComponent(
        spritePath: spritePath,
        flying: flying,
        speed: speed,
      ),
    );
  }

  void _spawnCoinGroup() {
    if (_isGameOver) return;
    _coinTimer.limit = coinSpawnIntervalMin +
        _random.nextDouble() * (coinSpawnIntervalMax - coinSpawnIntervalMin);

    final count = coinGroupMinCount +
        _random.nextInt(coinGroupMaxCount - coinGroupMinCount + 1);
    final arc = _random.nextBool();
    final speed = currentSpeed;
    if (speed <= 0) return;

    final playerX = player.position.x;
    final groundY = size.y * (1 - PlayerComponent.groundHeightRatio);
    final playerH = size.y * PlayerComponent.heightRatio;
    final baseY =
        groundY - playerH * PlayerComponent.hitboxCenterYFromFeet;
    final spacing = size.y * coinGroupSpacingFactor;
    final startX = size.x + spacing;
    final arcHeight = PlayerComponent.jumpPeakHeight * 0.75;

    final positions = coinGroupPositions(
      count: count,
      arc: arc,
      startX: startX,
      baseY: baseY,
      spacing: spacing,
      arcHeight: arcHeight,
    );

    final coinEtas =
        positions.map((p) => (p.x - playerX) / speed).toList(growable: false);
    final obstacleEtas = _obstacleEtas(playerX);
    for (final eta in coinEtas) {
      if (!arrivalGapOk(
        candidateEta: eta,
        existingEtas: obstacleEtas,
        minGap: coinObstacleArrivalGap,
      )) {
        return;
      }
    }

    for (final pos in positions) {
      world.add(CoinComponent(speed: speed, spawnPosition: pos));
    }
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
    return arrivalGapOk(
      candidateEta: candidateEta,
      existingEtas: _coinEtas(playerX),
      minGap: coinObstacleArrivalGap,
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
}

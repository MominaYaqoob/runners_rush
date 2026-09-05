import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:runners_rush/app_routes.dart';
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
  static const minObstacleGap = 420.0;
  static const flyingAtLeastEvery = 2;

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
  final Random _random = Random();
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  double _elapsed = 0;
  bool _isGameOver = false;
  double currentSpeed = initialSpeed;
  int _spawnsSinceFlying = 0;

  /// Seconds since the Flame game started. Used by later gameplay systems.
  double get elapsed => _elapsed;

  static double speedAt(double elapsed) {
    return min(
      maxSpeed,
      initialSpeed + elapsed * speedIncreasePerSecond,
    );
  }

  static double spawnScaleAt(double speed) {
    return initialSpeed / speed.clamp(initialSpeed, maxSpeed);
  }

  @override
  Color backgroundColor() => placeholderColor;

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
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_isGameOver) return;
    player.jump();
  }

  void handlePlayerHit() {
    if (_isGameOver) return;
    _isGameOver = true;
    final capturedScore = score.value;
    pauseEngine();
    _playHitFeedback();

    final ctx = buildContext;
    if (ctx == null || !ctx.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final previousBest = await ScoreService.getHighScore();
      await ScoreService.saveHighScoreIfBetter(capturedScore);
      final earnedCoins = (capturedScore * 0.1).floor();
      if (earnedCoins > 0) {
        await ShopService.addCoins(earnedCoins);
      }
      final character = await CharacterService.getSelectedCharacter();
      final best = capturedScore > previousBest ? capturedScore : previousBest;
      if (!ctx.mounted) return;
      Navigator.of(ctx).pushReplacementNamed(
        AppRoutes.gameOver,
        arguments: {
          'score': capturedScore,
          'best': best,
          'isNewHighScore': capturedScore > previousBest,
          'coinsEarned': earnedCoins,
          'character': character,
        },
      );
    });
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

  void _spawnObstacle() {
    if (_isGameOver) return;
    _spawnTimer.limit = _nextSpawnInterval();
    if (!_hasEnoughSpacing()) return;
    _spawnsSinceFlying++;
    final flying =
        _spawnsSinceFlying >= flyingAtLeastEvery || _random.nextDouble() < 0.4;
    final spritePath = flying
        ? _flyingSprite
        : _groundSprites[_random.nextInt(_groundSprites.length)];
    if (flying) _spawnsSinceFlying = 0;
    world.add(
      ObstacleComponent(
        spritePath: spritePath,
        flying: flying,
        speed: flying
            ? currentSpeed * ObstacleComponent.flyingSpeedMultiplier
            : currentSpeed,
      ),
    );
  }

  bool _hasEnoughSpacing() {
    for (final obstacle in world.children.whereType<ObstacleComponent>()) {
      if (size.x - obstacle.position.x < minObstacleGap) {
        return false;
      }
    }
    return true;
  }
}

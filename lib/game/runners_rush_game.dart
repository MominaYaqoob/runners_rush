import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/game/obstacle_component.dart';
import 'package:runners_rush/game/player_component.dart';

class RunnersRushGame extends FlameGame
    with TapCallbacks, HasCollisionDetection {
  static const placeholderColor = Color(0xFF2A1A3A);
  static const spawnIntervalMin = 2.5;
  static const spawnIntervalMax = 4.0;
  static const minObstacleGap = 420.0;

  static const _obstacleSprites = [
    'obstacle.png',
    'obstacle_2.png',
    'obstacle_flying.png',
  ];

  late final RectangleComponent _background;
  late final PlayerComponent player;
  late final Timer _spawnTimer;
  final Random _random = Random();
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  double _elapsed = 0;
  bool _isGameOver = false;

  /// Seconds since the Flame game started. Used by later gameplay systems.
  double get elapsed => _elapsed;

  @override
  Color backgroundColor() => placeholderColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    _background = RectangleComponent(
      size: size.clone(),
      paint: Paint()..color = placeholderColor,
    );
    camera.backdrop.add(_background);

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
    if (isLoaded) {
      _background.size = size.clone();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isGameOver) return;
    _elapsed += dt;
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

    final ctx = buildContext;
    if (ctx == null || !ctx.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pushReplacementNamed(
        AppRoutes.gameOver,
        arguments: capturedScore,
      );
    });
  }

  double _nextSpawnInterval() {
    return spawnIntervalMin +
        _random.nextDouble() * (spawnIntervalMax - spawnIntervalMin);
  }

  void _spawnObstacle() {
    if (_isGameOver) return;
    _spawnTimer.limit = _nextSpawnInterval();
    if (!_hasEnoughSpacing()) return;
    final spritePath =
        _obstacleSprites[_random.nextInt(_obstacleSprites.length)];
    world.add(
      ObstacleComponent(
        spritePath: spritePath,
        flying: spritePath.contains('flying'),
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

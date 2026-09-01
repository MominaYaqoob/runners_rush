import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Full-screen evening sky, tiled horizontally and scrolled slower than the ground.
class CoverBackgroundComponent extends PositionComponent
    with HasGameReference<RunnersRushGame>, HasPaint {
  static const spritePath = 'background_evening.png';
  static const parallaxFactor = 0.25;

  Sprite? _sprite;
  final List<SpriteComponent> _pieces = [];

  CoverBackgroundComponent()
      : super(anchor: Anchor.topLeft, position: Vector2.zero());

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sprite = await game.loadSprite(spritePath);
    paint.filterQuality = FilterQuality.medium;
    layoutTo(game.size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      layoutTo(size);
    }
  }

  void layoutTo(Vector2 viewSize) {
    size = viewSize.clone();
    position = Vector2.zero();

    final src = _sprite?.srcSize;
    if (src == null || src.x <= 0 || src.y <= 0) return;

    // BoxFit.cover: fill the view, then tile extra copies for scrolling.
    final scale = max(viewSize.x / src.x, viewSize.y / src.y);
    final pieceSize = Vector2(src.x * scale, src.y * scale);
    final offsetY = (viewSize.y - pieceSize.y) / 2;
    final count = max(2, (viewSize.x / pieceSize.x).ceil() + 1);
    _ensurePieces(count, pieceSize, offsetY);
  }

  void _ensurePieces(int count, Vector2 pieceSize, double offsetY) {
    while (_pieces.length > count) {
      _pieces.removeLast().removeFromParent();
    }
    while (_pieces.length < count) {
      final piece = SpriteComponent(
        sprite: _sprite,
        anchor: Anchor.topLeft,
        paint: paint,
      );
      _pieces.add(piece);
      add(piece);
    }
    for (var i = 0; i < _pieces.length; i++) {
      _pieces[i].sprite = _sprite;
      _pieces[i].size = pieceSize.clone();
      _pieces[i].position = Vector2(i * pieceSize.x, offsetY);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pieces.isEmpty) return;
    final dx = game.currentSpeed * parallaxFactor * dt;
    for (final piece in _pieces) {
      piece.position.x -= dx;
    }
    _wrapOffscreenPieces();
  }

  void _wrapOffscreenPieces() {
    var wrapped = true;
    while (wrapped) {
      wrapped = false;
      var rightEdge = 0.0;
      for (final piece in _pieces) {
        final edge = piece.position.x + piece.size.x;
        if (edge > rightEdge) rightEdge = edge;
      }
      for (final piece in _pieces) {
        if (piece.position.x + piece.size.x > 0) continue;
        piece.position.x = rightEdge;
        rightEdge = piece.position.x + piece.size.x;
        wrapped = true;
      }
    }
  }
}

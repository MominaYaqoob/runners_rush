import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

/// Two-or-more looping copies of [ground_texture.png], scrolling at obstacle speed.
class GroundStripComponent extends PositionComponent
    with HasGameReference<RunnersRushGame>, HasPaint {
  static const spritePath = 'ground_texture.png';

  Sprite? _sprite;
  final List<SpriteComponent> _pieces = [];

  GroundStripComponent()
      : super(anchor: Anchor.topLeft, priority: -10);

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
    final height = viewSize.y * PlayerComponent.groundHeightRatio;
    size = Vector2(viewSize.x, height);
    position = Vector2(0, viewSize.y - height);

    final src = _sprite?.srcSize;
    if (src == null || src.y <= 0 || height <= 0) return;
    final tileW = height * (src.x / src.y);
    final count = _pieceCount(viewSize.x, tileW);
    _ensurePieces(count, tileW, height);
  }

  int _pieceCount(double viewW, double tileW) {
    if (tileW <= 0) return 2;
    return (viewW / tileW).ceil() + 1;
  }

  void _ensurePieces(int count, double tileW, double height) {
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
      _pieces[i].size = Vector2(tileW, height);
      _pieces[i].position = Vector2(i * tileW, 0);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pieces.isEmpty) return;
    final dx = game.currentSpeed * dt;
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

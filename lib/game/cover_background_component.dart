import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runners_rush/game/player_component.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/services/shop_service.dart';

/// Full-screen sky, tiled horizontally and scrolled slower than the ground.
///
/// Odd tiles are horizontally mirrored so left/right art edges meet. Themes
/// that bake a stone path into the PNG crop it out via
/// [ShopBackground.bakedGroundFraction].
class CoverBackgroundComponent extends PositionComponent
    with HasGameReference<RunnersRushGame>, HasPaint {
  static const parallaxFactor = 0.25;

  Sprite? _sprite;
  final List<_ParallaxTile> _pieces = [];
  String _spritePath =
      ShopService.backgroundById(ShopService.eveningId).assetPath;
  double _bakedGroundFraction = 0;

  CoverBackgroundComponent()
      : super(anchor: Anchor.topLeft, position: Vector2.zero());

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final id = await ShopService.getSelectedBackground();
      final bg = ShopService.backgroundById(id);
      _spritePath = bg.assetPath;
      _bakedGroundFraction = bg.bakedGroundFraction.clamp(0.0, 0.9);
    } catch (_) {
      final bg = ShopService.backgroundById(ShopService.eveningId);
      _spritePath = bg.assetPath;
      _bakedGroundFraction = bg.bakedGroundFraction;
    }
    final image = await game.images.load(_spritePath);
    final cropH = image.height * (1.0 - _bakedGroundFraction);
    _sprite = Sprite(
      image,
      srcPosition: Vector2.zero(),
      srcSize: Vector2(image.width.toDouble(), cropH),
    );
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

    // Cover the area above the ground strip; crop bottom meets the strip top.
    final groundTop =
        viewSize.y * (1 - PlayerComponent.groundHeightRatio);
    final scale = max(viewSize.x / src.x, groundTop / src.y);
    final pieceSize = Vector2(src.x * scale, src.y * scale);
    final offsetY = groundTop - pieceSize.y;
    var count = max(2, (viewSize.x / pieceSize.x).ceil() + 1);
    if (count.isOdd) count++; // even count keeps mirror alternation on wrap
    _ensurePieces(count, pieceSize, offsetY);
  }

  void _ensurePieces(int count, Vector2 pieceSize, double offsetY) {
    while (_pieces.length > count) {
      _pieces.removeLast().removeFromParent();
    }
    while (_pieces.length < count) {
      final index = _pieces.length;
      final piece = _ParallaxTile(
        sprite: _sprite,
        stripeIndex: index,
        paint: paint,
      );
      _pieces.add(piece);
      add(piece);
    }
    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      piece.sprite = _sprite;
      piece.stripeIndex = i;
      piece.size = pieceSize.clone();
      piece.position = Vector2(i * pieceSize.x, offsetY);
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
      var maxStripe = -1;
      for (final piece in _pieces) {
        final edge = piece.position.x + piece.size.x;
        if (edge > rightEdge) rightEdge = edge;
        if (piece.stripeIndex > maxStripe) maxStripe = piece.stripeIndex;
      }
      for (final piece in _pieces) {
        if (piece.position.x + piece.size.x > 0) continue;
        piece.position.x = rightEdge;
        piece.stripeIndex = maxStripe + 1;
        maxStripe = piece.stripeIndex;
        rightEdge = piece.position.x + piece.size.x;
        wrapped = true;
      }
    }
  }
}

/// Parallax tile that mirrors odd stripes so left/right edges of the art meet.
class _ParallaxTile extends SpriteComponent {
  _ParallaxTile({
    required super.sprite,
    required this.stripeIndex,
    Paint? paint,
  }) : super(anchor: Anchor.topLeft) {
    if (paint != null) {
      this.paint = paint;
    }
  }

  int stripeIndex;

  bool get mirrored => stripeIndex.isOdd;

  @override
  void render(Canvas canvas) {
    if (!mirrored) {
      super.render(canvas);
      return;
    }
    canvas.save();
    canvas.translate(size.x, 0);
    canvas.scale(-1, 1);
    super.render(canvas);
    canvas.restore();
  }
}

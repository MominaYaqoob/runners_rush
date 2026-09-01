import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

/// Toggle to paint AABBs in-game. Leave off in play; flip on to debug collisions.
abstract final class HitboxDebug {
  static const enabled = false;

  static final playerColor = Colors.blue.withOpacity(0.4);
  static final obstacleColor = Colors.red.withOpacity(0.4);

  static void apply(RectangleHitbox hitbox, Color color) {
    if (!enabled) return;
    hitbox.renderShape = true;
    hitbox.paint.color = color;
  }
}

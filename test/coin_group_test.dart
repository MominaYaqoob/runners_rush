import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/runners_rush_game.dart';

void main() {
  test('coinGroupPositions flat keeps equal Y and spaced X', () {
    final positions = RunnersRushGame.coinGroupPositions(
      count: 4,
      arc: false,
      startX: 100,
      baseY: 200,
      spacing: 40,
      arcHeight: 80,
    );

    expect(positions, hasLength(4));
    for (var i = 0; i < positions.length; i++) {
      expect(positions[i].x, closeTo(100 + i * 40, 1e-9));
      expect(positions[i].y, 200);
    }
  });

  test('coinGroupPositions arc rises then falls via sin', () {
    const baseY = 300.0;
    const arcHeight = 100.0;
    final positions = RunnersRushGame.coinGroupPositions(
      count: 5,
      arc: true,
      startX: 0,
      baseY: baseY,
      spacing: 50,
      arcHeight: arcHeight,
    );

    expect(positions, hasLength(5));
    expect(positions.first.y, closeTo(baseY, 1e-9));
    expect(positions.last.y, closeTo(baseY, 1e-9));
    expect(positions[2].y, closeTo(baseY - arcHeight, 1e-9));

    for (var i = 0; i < positions.length; i++) {
      final expectedY =
          baseY - arcHeight * sin(pi * i / (positions.length - 1));
      expect(positions[i].y, closeTo(expectedY, 1e-6));
    }
  });

  test('coinGroupPositions clamps count to 3..5', () {
    expect(
      RunnersRushGame.coinGroupPositions(
        count: 2,
        arc: false,
        startX: 0,
        baseY: 0,
        spacing: 10,
        arcHeight: 0,
      ),
      hasLength(3),
    );
    expect(
      RunnersRushGame.coinGroupPositions(
        count: 9,
        arc: false,
        startX: 0,
        baseY: 0,
        spacing: 10,
        arcHeight: 0,
      ),
      hasLength(5),
    );
  });
}

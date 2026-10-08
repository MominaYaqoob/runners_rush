import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runners_rush/game/obstacle_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ObstacleComponent.disposeRimCache();
  });

  test('rim cache bakes once per sprite path and disposes cleanly', () async {
    Flame.images.prefix = 'assets/images/';
    final sprite = await Sprite.load('obstacle_stone.png');

    final a = await ObstacleComponent.rimImageFor('obstacle_stone.png', sprite);
    final b = await ObstacleComponent.rimImageFor('obstacle_stone.png', sprite);
    expect(identical(a, b), isTrue);
    expect(a.width, greaterThan(sprite.srcSize.x));
    expect(a.height, greaterThan(sprite.srcSize.y));

    ObstacleComponent.disposeRimCache();
    final c = await ObstacleComponent.rimImageFor('obstacle_stone.png', sprite);
    expect(identical(a, c), isFalse);
    ObstacleComponent.disposeRimCache();
  });

  test('cached rim paint is faster than live MaskFilter blur (3 obstacles)',
      () async {
    Flame.images.prefix = 'assets/images/';
    final sprite = await Sprite.load('obstacle_stone.png');
    final rim = await ObstacleComponent.rimImageFor('obstacle_stone.png', sprite);

    // Display size similar to a phone landscape ground obstacle.
    const display = Size(120, 90);
    const frames = 180; // ~3s at 60fps
    const obstacles = 3;

    Future<int> microsLive() async {
      final sw = Stopwatch()..start();
      for (var f = 0; f < frames; f++) {
        for (var o = 0; o < obstacles; o++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          _paintLiveRim(canvas, sprite, display);
          sprite.render(
            canvas,
            size: Vector2(display.width, display.height),
          );
          recorder.endRecording().dispose();
        }
      }
      sw.stop();
      return sw.elapsedMicroseconds;
    }

    Future<int> microsCached() async {
      final sw = Stopwatch()..start();
      for (var f = 0; f < frames; f++) {
        for (var o = 0; o < obstacles; o++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          _paintCachedRim(canvas, rim, sprite, display);
          sprite.render(
            canvas,
            size: Vector2(display.width, display.height),
          );
          recorder.endRecording().dispose();
        }
      }
      sw.stop();
      return sw.elapsedMicroseconds;
    }

    // Warm-up
    await microsLive();
    await microsCached();

    final liveUs = await microsLive();
    final cachedUs = await microsCached();
    final liveMs = liveUs / 1000;
    final cachedMs = cachedUs / 1000;
    final livePerFrame = liveMs / frames;
    final cachedPerFrame = cachedMs / frames;

    // eslint-disable-next-line no-print
    // ignore: avoid_print
    print(
      'Rim paint microbench (3 obstacles × $frames frames):\n'
      '  live MaskFilter:  ${liveMs.toStringAsFixed(1)} ms total, '
      '${livePerFrame.toStringAsFixed(3)} ms/frame\n'
      '  cached drawImage: ${cachedMs.toStringAsFixed(1)} ms total, '
      '${cachedPerFrame.toStringAsFixed(3)} ms/frame\n'
      '  speedup: ${(liveMs / cachedMs).toStringAsFixed(2)}×',
    );

    expect(cachedUs, lessThan(liveUs));

    // Visual snapshot at 844x390-ish obstacle crop for side-by-side check.
    await _writeComparePngs(sprite, rim, display);
    ObstacleComponent.disposeRimCache();
  });
}

void _paintLiveRim(Canvas canvas, Sprite sprite, Size display) {
  final size = Vector2(display.width, display.height);
  final cx = size.x / 2;
  final cy = size.y;
  void rim({
    required double scale,
    required double blur,
    required Color tint,
  }) {
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);
    canvas.translate(-cx, -cy);
    sprite.render(canvas, size: size, overridePaint: paint);
    canvas.restore();
  }

  rim(scale: 1.06, blur: 3.5, tint: const Color(0xB3FFF8E7));
  rim(scale: 1.03, blur: 1.5, tint: const Color(0xE6FFEFC2));
}

void _paintCachedRim(
  Canvas canvas,
  ui.Image rim,
  Sprite sprite,
  Size display,
) {
  final pad = ObstacleComponent.rimPadPx();
  final scaleX = display.width / sprite.srcSize.x;
  final scaleY = display.height / sprite.srcSize.y;
  final padX = pad * scaleX;
  final padY = pad * scaleY;
  canvas.drawImageRect(
    rim,
    Rect.fromLTWH(0, 0, rim.width.toDouble(), rim.height.toDouble()),
    Rect.fromLTWH(-padX, -padY, display.width + padX * 2, display.height + padY * 2),
    Paint()..filterQuality = FilterQuality.medium,
  );
}

Future<void> _writeComparePngs(
  Sprite sprite,
  ui.Image rim,
  Size display,
) async {
  Future<void> dump(String name, void Function(Canvas) paint) async {
    final pad = ObstacleComponent.rimPadPx();
    final scaleX = display.width / sprite.srcSize.x;
    final scaleY = display.height / sprite.srcSize.y;
    final w = (display.width + pad * scaleX * 2).ceil();
    final h = (display.height + pad * scaleY * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(pad * scaleX, pad * scaleY);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = Directory('tools/screenshots');
    await dir.create(recursive: true);
    await File('${dir.path}/$name').writeAsBytes(bytes!.buffer.asUint8List());
  }

  await dump('obstacle_rim_live_844.png', (c) {
    _paintLiveRim(c, sprite, display);
    sprite.render(c, size: Vector2(display.width, display.height));
  });
  await dump('obstacle_rim_cached_844.png', (c) {
    _paintCachedRim(c, rim, sprite, display);
    sprite.render(c, size: Vector2(display.width, display.height));
  });
}

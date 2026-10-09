import 'package:flutter/rendering.dart';

/// Shared code-drawn shield icon (pickup + HUD).
class ShieldPainter {
  ShieldPainter._();

  static Path shieldPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.50, h * 0.08);
    path.cubicTo(w * 0.78, h * 0.10, w * 0.92, h * 0.22, w * 0.92, h * 0.42);
    path.cubicTo(w * 0.92, h * 0.68, w * 0.72, h * 0.88, w * 0.50, h * 0.96);
    path.cubicTo(w * 0.28, h * 0.88, w * 0.08, h * 0.68, w * 0.08, h * 0.42);
    path.cubicTo(w * 0.08, h * 0.22, w * 0.22, h * 0.10, w * 0.50, h * 0.08);
    path.close();
    return path;
  }

  static void paint(Canvas canvas, Size size) {
    final path = shieldPath(size);
    final bounds = Offset.zero & size;
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF9AD8FF),
          Color(0xFF3A8FE8),
          Color(0xFF1E5FAF),
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(bounds);
    canvas.drawPath(path, fill);

    final gloss = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.center,
        colors: [
          Color(0xCCFFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(bounds);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(bounds, gloss);
    canvas.restore();

    final outline = Paint()
      ..color = const Color(0xFFF5FBFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.shortestSide * 0.07).clamp(1.5, 3.0)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outline);

    final inner = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.shortestSide * 0.03).clamp(0.8, 1.5);
    canvas.drawPath(path, inner);
  }
}

/// Flutter [CustomPainter] wrapper for HUD badges.
class ShieldIconPainter extends CustomPainter {
  const ShieldIconPainter();

  @override
  void paint(Canvas canvas, Size size) => ShieldPainter.paint(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

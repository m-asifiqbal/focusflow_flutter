/// The multi-colour Google "G" (Continue with Google, account email row).
///
/// Google's brand guidelines require the four official colours on any
/// background, so these are the one place in features that does not read
/// the theme: they are brand assets, not UI colours.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: const _GooglePainter(),
    ),
  );
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final r = (s - stroke) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    double rad(double deg) => deg * math.pi / 180;
    Paint p(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas
      ..drawArc(rect, rad(0), rad(45), false, p(_blue))
      ..drawArc(rect, rad(45), rad(92), false, p(_green))
      ..drawArc(rect, rad(135), rad(83), false, p(_yellow))
      ..drawArc(rect, rad(216), rad(102), false, p(_red))
      ..drawRect(
        Rect.fromLTRB(
          c.dx,
          c.dy - stroke / 2,
          c.dx + r + stroke / 2,
          c.dy + stroke / 2,
        ),
        Paint()..color = _blue,
      );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}

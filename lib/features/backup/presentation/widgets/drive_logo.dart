/// The three-colour Google Drive triangle (Backup & Sync card, Save to
/// Google Drive tile).
///
/// Like the Google "G" (auth/widgets/google_logo.dart) this is a brand
/// mark: its official colours are drawn as-is on any background, so these
/// are the one place in the feature that does not read the theme.
library;

import 'package:flutter/widgets.dart';

class DriveLogo extends StatelessWidget {
  const DriveLogo({this.size = 22, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(size, size * 0.87),
      painter: const _DrivePainter(),
    ),
  );
}

class _DrivePainter extends CustomPainter {
  const _DrivePainter();

  static const _green = Color(0xFF0F9D58);
  static const _yellow = Color(0xFFF4B400);
  static const _blue = Color(0xFF4285F4);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Path poly(List<(double, double)> pts) =>
        Path()
          ..addPolygon([for (final p in pts) Offset(p.$1 * w, p.$2 * h)], true);
    canvas
      ..drawPath(
        poly([(0.33, 0), (0.5, 0.33), (0.17, 1), (0, 0.67)]),
        Paint()..color = _green,
      )
      ..drawPath(
        poly([(0.33, 0), (0.67, 0), (1, 0.67), (0.67, 0.67)]),
        Paint()..color = _yellow,
      )
      ..drawPath(
        poly([(0.33, 0.67), (1, 0.67), (0.83, 1), (0.17, 1)]),
        Paint()..color = _blue,
      );
  }

  @override
  bool shouldRepaint(_DrivePainter oldDelegate) => false;
}

// Renders the launcher icon PNGs from code (no image editor needed):
//   flutter test tool/icon/render_icon_test.dart && dart run flutter_launcher_icons
// Writes assets/images/app_icon.png (1024², full-bleed for iOS) and
// assets/images/app_icon_foreground.png (Android adaptive foreground).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

/// Font Awesome 6 "bolt" outline (viewBox 448×512), as polygon points.
const List<Offset> _bolt = [
  Offset(349.4, 44.6),
  Offset(166.6, 44.6),
  Offset(80.5, 278.6),
  Offset(190.5, 278.6),
  Offset(129.3, 467.4),
  Offset(367.5, 199.4),
  Offset(250.1, 199.4),
];

void _paintBolt(Canvas canvas, Rect box) {
  final scale = box.height / 512;
  final dx = box.left + (box.width - 448 * scale) / 2;
  final path = Path()
    ..addPolygon([
      for (final p in _bolt) Offset(dx + p.dx * scale, box.top + p.dy * scale),
    ], true);
  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34 * scale
      ..strokeJoin = StrokeJoin.round,
  );
}

const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF0F766E)],
);

Future<void> _write(String path, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    _size.toInt(),
    _size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render launcher icons', () async {
    const full = Rect.fromLTWH(0, 0, _size, _size);
    await _write('assets/images/app_icon.png', (c) {
      c.drawRect(full, Paint()..shader = _gradient.createShader(full));
      // Soft highlight circle, as on the onboarding hero.
      c.drawCircle(
        const Offset(_size * 0.82, _size * 0.12),
        _size * 0.34,
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
      _paintBolt(c, Rect.fromCenter(
        center: full.center,
        width: _size * 0.5,
        height: _size * 0.5,
      ));
    });
    // Adaptive foreground: content inside the 66% safe zone, transparent bg
    // (background colour comes from pubspec adaptive_icon_background).
    await _write('assets/images/app_icon_foreground.png', (c) {
      final tile = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: full.center,
          width: _size * 0.56,
          height: _size * 0.56,
        ),
        const Radius.circular(_size * 0.14),
      );
      c.drawRRect(tile, Paint()..shader = _gradient.createShader(tile.outerRect));
      _paintBolt(c, Rect.fromCenter(
        center: full.center,
        width: _size * 0.3,
        height: _size * 0.3,
      ));
    });
  });
}

/// ============================================================
/// NOTE CARET PARTS — the teardrop painter and drag of NoteCaretHandle
/// ============================================================
///
/// Split out of note_caret_handle.dart (file size); see that file for the
/// handle's behaviour.
/// ============================================================
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The [Drag] handed to Flutter by the handle's recogniser.
class NoteHandleDrag implements Drag {
  NoteHandleDrag({required this.onUpdate, required this.onEnd});

  final ValueChanged<DragUpdateDetails> onUpdate;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onUpdate(details);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

/// A teardrop with its point up, top-centre of the box.
class NoteTeardropPainter extends CustomPainter {
  const NoteTeardropPainter({
    required this.color,
    required this.shadow,
    required this.size,
  });

  final Color color;
  final Color shadow;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final r = size / 2;
    final cx = box.width / 2;
    final cy = 2 + r + 5;
    final body = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    // Pointed top: a triangle from the tip to the circle's upper tangents.
    final tip = Offset(cx, 2);
    final k = r * 0.72;
    final point = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(cx - k, cy - k)
      ..lineTo(cx + k, cy - k)
      ..close();
    final drop = Path.combine(PathOperation.union, body, point);
    canvas.drawShadow(drop, shadow, 3, true);
    canvas.drawPath(drop, Paint()..color = color);
  }

  @override
  bool shouldRepaint(NoteTeardropPainter old) =>
      old.color != color || old.shadow != shadow || old.size != size;
}

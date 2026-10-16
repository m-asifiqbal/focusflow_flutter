/// Motion contact sheets for eyeballing an animation without a device.
///
/// [captureFilmstrip] grabs the current frame, then pumps [step] at a time
/// and grabs again; every frame becomes one labelled thumbnail on a single
/// PNG (`build/screens/<name>.png`). Call it right after the gesture that
/// starts the animation (after its first `pump()`).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> captureFilmstrip(
  WidgetTester tester,
  String name, {
  int frames = 12,
  Duration step = const Duration(milliseconds: 32),
  int columns = 6,
  double scale = 0.3,
}) async {
  final view = tester.binding.renderViews.first;
  final bounds = Offset.zero & (view.size * tester.view.devicePixelRatio);
  final shots = <ui.Image>[];
  var elapsed = 0;
  final labels = <String>[];
  for (var i = 0; i < frames; i++) {
    if (i > 0) {
      await tester.pump(step);
      elapsed += step.inMilliseconds;
    }
    // ignore: invalid_use_of_protected_member
    final layer = view.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      shots.add(await layer.toImage(bounds, pixelRatio: scale));
    });
    labels.add('+$elapsed ms');
  }
  final cellW = shots.first.width.toDouble();
  final cellH = shots.first.height.toDouble();
  final rows = (frames / columns).ceil();
  const gap = 8.0;
  final sheetW = columns * (cellW + gap) + gap;
  final sheetH = rows * (cellH + gap + 22) + gap;
  late File file;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sheetW, sheetH),
      Paint()..color = const Color(0xFF222222),
    );
    for (var i = 0; i < shots.length; i++) {
      final x = gap + (i % columns) * (cellW + gap);
      final y = gap + (i ~/ columns) * (cellH + gap + 22);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
      canvas.drawImage(shots[i], Offset(x, y + 22), Paint());
    }
    final image = await recorder.endRecording().toImage(
      sheetW.ceil(),
      sheetH.ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    for (final s in shots) {
      s.dispose();
    }
    file = File('build/screens/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
  return file;
}

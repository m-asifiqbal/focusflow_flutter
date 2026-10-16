/// Seed data for the notes list tests: the six notes of
/// design/07_notes_list.png (folders Ideas, Work, Personal, Travel,
/// Health; a checklist, a cover image, two colours, two pinned).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/test_container.dart';

/// Friday 12 June 2026, 9:41.
final DateTime kListNow = DateTime(2026, 6, 12, 9, 41);

/// Ids of the seeded notes by title.
typedef SeededNotes = Map<String, String>;

/// Seeds the mockup notes (run inside `tester.runAsync`). [docs] is the
/// overridden documents dir (cover image); [locked] locks the roadmap.
Future<SeededNotes> seedNotesList(
  TestHarness h,
  Directory docs, {
  bool locked = false,
}) async {
  final folders = h.read(foldersRepositoryProvider);
  final notes = h.read(notesRepositoryProvider);
  final ids = <String, String>{};
  final folder = <String, String>{};
  for (final name in ['Ideas', 'Work', 'Personal', 'Travel', 'Health']) {
    folder[name] = await folders.create(ItemType.note, name);
  }
  final cover = await _writeCover(docs);

  Future<void> add(
    String title,
    DateTime at, {
    required String folderName,
    String? tag,
    String? color,
    String body = '',
    List<(String, bool)> checklist = const [],
    bool pinned = false,
    String? coverPath,
  }) async {
    h.clock.set(at);
    final id = await notes.createEmpty(
      folderId: folder[folderName],
      colorHex: color,
      tagNames: [?tag],
      title: title,
    );
    final ops = <Map<String, Object?>>[
      for (final line in body.split('\n'))
        if (line.isNotEmpty) {'insert': '$line\n'},
      for (final (text, done) in checklist) ...[
        {'insert': text},
        {
          'insert': '\n',
          'attributes': {'list': done ? 'checked' : 'unchecked'},
        },
      ],
    ];
    final delta = jsonEncode(
      ops.isEmpty
          ? [
              {'insert': '\n'},
            ]
          : ops,
    );
    final content = NoteContent.fromDeltaJson(delta);
    await notes.saveContent(
      id,
      title: title,
      deltaJson: delta,
      plainText: content.plainText,
      checklist: content.checklist,
      wordCount: content.wordCount(title),
    );
    if (pinned) await notes.setPinned(id, true);
    if (coverPath != null) await notes.setCover(id, coverPath);
    ids[title] = id;
  }

  await add(
    'Mobile App Design Trends 2024',
    DateTime(2026, 6, 12, 9, 12),
    folderName: 'Ideas',
    tag: 'ideas',
    color: 'D1FAE5',
    pinned: true,
    body:
        'Focus on minimalism, organic shapes and personalised experiences '
        'using AI. Emphasise dark mode and accessibility in every flow, '
        'with calm motion.',
  );
  await add(
    'Project FocusFlow Roadmap',
    DateTime(2026, 6, 10, 16),
    folderName: 'Work',
    tag: 'work',
    pinned: true,
    body:
        'Phase 1: Research & wireframes. Phase 2: UI design system. '
        'Phase 3: Prototyping and testing.',
  );
  await add(
    'Shopping List',
    DateTime(2026, 6, 11, 18),
    folderName: 'Personal',
    tag: 'personal',
    checklist: [
      ('Organic coffee beans', true),
      ('Avocado oil', false),
      ('Greek yogurt', false),
    ],
  );
  await add(
    'Inspiration Trip',
    DateTime(2026, 6, 8, 7),
    folderName: 'Travel',
    coverPath: cover,
    body: 'Great colours in the morning light at the peaks.',
  );
  await add(
    'Morning Routine',
    DateTime(2026, 6, 5, 6),
    folderName: 'Health',
    color: 'FEF3C7',
    body: '1. Drink water\n2. Meditate 10 min\n3. Plan top-3 priorities',
  );
  await add(
    'Meeting notes — Sprint 12',
    DateTime(2026, 6, 2, 11),
    folderName: 'Work',
    tag: 'work',
    body:
        'Ship vault autofill, fix sync conflict banner, finalise habit '
        'heatmap.',
  );
  if (locked) {
    await notes.setLocked(ids['Project FocusFlow Roadmap']!, true);
  }
  h.clock.set(kListNow);
  return ids;
}

/// A sky-to-mint gradient with two hills (the mockup's cover), written to
/// `attachments/cover.png` under [docs]. Returns the relative path.
Future<String> _writeCover(Directory docs) async {
  const w = 480.0;
  const h = 200.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), [
          const Color(0xFF7DD3FC),
          const Color(0xFF86EFAC),
        ]),
    );
  final hills = Path()
    ..moveTo(0, h)
    ..lineTo(w * 0.24, h * 0.62)
    ..lineTo(w * 0.45, h * 0.86)
    ..lineTo(w * 0.72, h * 0.5)
    ..lineTo(w, h * 0.88)
    ..lineTo(w, h)
    ..close();
  canvas.drawPath(
    hills,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, h * 0.5),
        const Offset(0, h),
        [const Color(0xFF6EE7B7), const Color(0xFF34A27A)],
      ),
  );
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  const relative = 'attachments/cover.png';
  final file = File(p.join(docs.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return relative;
}

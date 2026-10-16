/// ============================================================
/// NOTE CONTENT — what the app derives from a note body (Quill Delta)
/// ============================================================
///
/// The editor stores the body as Quill Delta JSON (the source of truth).
/// Lists, search and the Library need cheaper, derived values: the plain
/// text (previews + FTS), the checklist lines (card preview), the images
/// (cover + attachment bookkeeping) and the word count. [NoteContent]
/// computes all of them from the JSON in pure Dart, so it runs in tests
/// and repositories without a Flutter binding or a Quill document.
///
/// Delta shape reminder: block attributes (`header`, `list`, `blockquote`)
/// live on the `"\n"` that ends a line; embeds are map inserts such as
/// `{"insert": {"image": "attachments/ab12.jpg"}}`.
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';

/// One line of a Delta document with its block attributes.
@immutable
class DeltaLine {
  const DeltaLine({
    required this.segments,
    this.header,
    this.list,
    this.quote = false,
    this.images = const [],
  });

  /// Text runs with their inline attributes (bold / italic …).
  final List<DeltaSegment> segments;

  /// 1–6 for headings, null for paragraphs.
  final int? header;

  /// `bullet`, `ordered`, `checked`, `unchecked` or null.
  final String? list;
  final bool quote;

  /// Image embeds on this line (relative paths).
  final List<String> images;

  String get text => segments.map((s) => s.text).join();
  bool get isChecklist => list == 'checked' || list == 'unchecked';
}

/// A run of text inside a [DeltaLine].
@immutable
class DeltaSegment {
  const DeltaSegment(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;
}

/// Derived values of a note body.
@immutable
class NoteContent {
  const NoteContent({
    required this.lines,
    required this.plainText,
    required this.checklist,
    required this.imagePaths,
  });

  static const empty = NoteContent(
    lines: [],
    plainText: '',
    checklist: [],
    imagePaths: [],
  );

  final List<DeltaLine> lines;

  /// Body text without embeds; lines joined by `\n`, trailing blank
  /// lines removed.
  final String plainText;

  /// Checklist lines in document order.
  final List<ChecklistItem> checklist;

  /// Relative paths of every image embed, in document order.
  final List<String> imagePaths;

  /// The first image (used as the card cover), if any.
  String? get coverImage => imagePaths.isEmpty ? null : imagePaths.first;

  /// Words in [title] + body — the same rule the repository uses on
  /// create, so the count never jumps after the first save.
  int wordCount(String title) => countWords('$title $plainText');

  static int countWords(String text) => RegExp(r'\S+').allMatches(text).length;

  /// Parses Delta JSON (`[{"insert": …}, …]`). Invalid input → [empty].
  static NoteContent fromDeltaJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return empty;
    }
    if (decoded is! List) return empty;
    return fromOps(decoded);
  }

  /// Parses decoded Delta ops (the output of `Delta.toJson()`).
  static NoteContent fromOps(List<Object?> ops) {
    final lines = <DeltaLine>[];
    var segments = <DeltaSegment>[];
    var images = <String>[];

    void endLine(Map<Object?, Object?>? attrs) {
      final header = attrs?['header'];
      final list = attrs?['list'];
      lines.add(
        DeltaLine(
          segments: segments,
          header: header is int ? header : null,
          list: list is String ? list : null,
          quote: attrs?['blockquote'] == true,
          images: images,
        ),
      );
      segments = [];
      images = [];
    }

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      final attrs = op['attributes'] is Map
          ? op['attributes'] as Map<Object?, Object?>
          : null;
      if (insert is Map) {
        final image = insert['image'];
        if (image is String && image.isNotEmpty) images.add(image);
        continue;
      }
      if (insert is! String) continue;
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          segments.add(
            DeltaSegment(
              parts[i],
              bold: attrs?['bold'] == true,
              italic: attrs?['italic'] == true,
            ),
          );
        }
        if (i < parts.length - 1) endLine(attrs);
      }
    }
    if (segments.isNotEmpty || images.isNotEmpty) endLine(null);

    final texts = lines.map((l) => l.text).toList();
    while (texts.isNotEmpty && texts.last.trim().isEmpty) {
      texts.removeLast();
    }
    return NoteContent(
      lines: List.unmodifiable(lines),
      plainText: texts.join('\n').trimRight(),
      checklist: List.unmodifiable([
        for (final l in lines)
          if (l.isChecklist && l.text.trim().isNotEmpty)
            ChecklistItem(text: l.text.trim(), done: l.list == 'checked'),
      ]),
      imagePaths: List.unmodifiable([for (final l in lines) ...l.images]),
    );
  }
}

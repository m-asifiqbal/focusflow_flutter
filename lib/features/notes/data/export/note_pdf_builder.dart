/// ============================================================
/// NOTE PDF BUILDER — lays a note out as an A4 PDF (pdf package)
/// ============================================================
///
/// Uses the app's bundled fonts (Lexend Deca headings, Nunito Sans body)
/// so the export looks like the editor and renders non-ASCII text. Images
/// are embedded when the file still exists. Pure layout: writing the file
/// and opening the share sheet live in NoteShareService.
/// ============================================================
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class NotePdfBuilder {
  const NotePdfBuilder({this.resolveImage});

  /// Maps a relative image path to a file (null = skip images).
  final File? Function(String relativePath)? resolveImage;

  static const _ink = PdfColor.fromInt(0xFF064E3B);
  static const _muted = PdfColor.fromInt(0xFF5F7F75);
  static const _accent = PdfColor.fromInt(0xFF10B981);

  Future<pw.Font> _font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));

  /// Builds the PDF bytes for [note]. [subtitle] is printed under the
  /// title ("Edited Jun 13, 2026 · 214 words").
  Future<Uint8List> build(Note note, {String? subtitle}) async {
    final body = await _font('assets/fonts/NunitoSans-Regular.ttf');
    final bold = await _font('assets/fonts/NunitoSans-Bold.ttf');
    final italic = await _font('assets/fonts/NunitoSans-Italic.ttf');
    final heading = await _font('assets/fonts/LexendDeca-Bold.ttf');
    final content = NoteContent.fromDeltaJson(note.contentDelta);

    final doc = pw.Document(
      title: note.displayTitle,
      theme: pw.ThemeData.withFont(base: body, bold: bold, italic: italic),
    );
    final images = <String, pw.MemoryImage>{};
    for (final path in content.imagePaths) {
      final file = resolveImage?.call(path);
      if (file != null && await file.exists()) {
        images[path] = pw.MemoryImage(await file.readAsBytes());
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => [
          pw.Text(
            note.displayTitle,
            style: pw.TextStyle(font: heading, fontSize: 24, color: _ink),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
          ],
          pw.SizedBox(height: 18),
          ..._lines(content, heading, images),
        ],
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _lines(
    NoteContent content,
    pw.Font heading,
    Map<String, pw.MemoryImage> images,
  ) {
    final out = <pw.Widget>[];
    var ordered = 0;
    for (final line in content.lines) {
      ordered = line.list == 'ordered' ? ordered + 1 : 0;
      for (final path in line.images) {
        final img = images[path];
        if (img != null) {
          out.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Image(img, height: 200, fit: pw.BoxFit.contain),
            ),
          );
        }
      }
      final text = pw.RichText(
        text: pw.TextSpan(
          children: [
            for (final s in line.segments)
              pw.TextSpan(
                text: s.text,
                style: pw.TextStyle(
                  fontWeight: s.bold ? pw.FontWeight.bold : null,
                  fontStyle: s.italic ? pw.FontStyle.italic : null,
                  decoration: line.list == 'checked'
                      ? pw.TextDecoration.lineThrough
                      : null,
                ),
              ),
          ],
          style: line.header != null
              ? pw.TextStyle(font: heading, fontSize: 15, color: _ink)
              : pw.TextStyle(
                  fontSize: 11.5,
                  lineSpacing: 4,
                  color: line.quote ? _muted : _ink,
                  fontStyle: line.quote ? pw.FontStyle.italic : null,
                ),
        ),
      );
      final pw.Widget? lead = switch (line.list) {
        'checked' || 'unchecked' => pw.Container(
          width: 9,
          height: 9,
          margin: const pw.EdgeInsets.only(top: 3),
          decoration: pw.BoxDecoration(
            color: line.list == 'checked' ? _accent : null,
            border: pw.Border.all(color: _accent),
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        'bullet' => pw.Text('•'),
        'ordered' => pw.Text('$ordered.'),
        _ => null,
      };
      pw.Widget row = lead == null
          ? text
          : pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 16, child: lead),
                pw.Expanded(child: text),
              ],
            );
      if (line.quote) {
        row = pw.Container(
          padding: const pw.EdgeInsets.only(left: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: _accent, width: 3)),
          ),
          child: row,
        );
      }
      out.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            top: line.header != null ? 10 : 2,
            bottom: line.header != null ? 4 : 2,
          ),
          child: row,
        ),
      );
    }
    return out;
  }
}

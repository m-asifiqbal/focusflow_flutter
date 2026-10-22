/// ============================================================
/// NOTES PDF EXPORT — every exported note in one PDF
/// ============================================================
///
/// What: title + plain text of each note (one after another, page breaks
/// between notes) with the bundled fonts, for the PDF/MD export format.
/// Why: the single-note PDF (notes feature) renders rich Quill content; an
/// archive export of many notes only needs readable text, which keeps it
/// fast and independent of the editor.
/// ============================================================
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:focusflow/core/l10n/tr.dart';

class NotesPdfExport {
  const NotesPdfExport();

  static const _ink = PdfColor.fromInt(0xFF064E3B);
  static const _muted = PdfColor.fromInt(0xFF5F7F75);

  Future<pw.Font> _font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));

  /// [notes] = (title, subtitle, text) per note.
  Future<Uint8List> build(
    List<({String title, String subtitle, String text})> notes,
  ) async {
    final body = await _font('assets/fonts/NunitoSans-Regular.ttf');
    final bold = await _font('assets/fonts/NunitoSans-Bold.ttf');
    final heading = await _font('assets/fonts/LexendDeca-Bold.ttf');
    final doc = pw.Document(
      title: trPrint('FocusFlow notes'),
      theme: pw.ThemeData.withFont(base: body, bold: bold),
    );
    for (final n in notes) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          build: (context) => [
            pw.Text(
              n.title,
              style: pw.TextStyle(font: heading, fontSize: 22, color: _ink),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              n.subtitle,
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
            pw.SizedBox(height: 16),
            for (final para in n.text.split('\n'))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(para, style: const pw.TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
    }
    if (notes.isEmpty) {
      doc.addPage(pw.Page(build: (_) => pw.Text(trPrint('No notes'))));
    }
    return doc.save();
  }
}

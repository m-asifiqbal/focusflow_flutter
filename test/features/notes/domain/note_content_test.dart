/// NoteContent (Delta → plain text / checklist / images / words) and
/// NoteExport (TXT + Markdown) over the screen-08 mockup note.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';
import 'package:focusflow/features/notes/domain/services/note_export.dart';

import '../notes_fixtures.dart';

void main() {
  group('NoteContent', () {
    final content = NoteContent.fromDeltaJson(kMockupDelta);

    test('splits lines with their block attributes', () {
      final heading = content.lines.firstWhere((l) => l.header != null);
      expect(heading.text, '1. Minimalism & White Space');
      expect(heading.header, 3);
      final quote = content.lines.firstWhere((l) => l.quote);
      expect(quote.text, startsWith('Wait, we should'));
      final bold = content.lines
          .expand((l) => l.segments)
          .firstWhere((s) => s.bold);
      expect(bold.text, 'generous padding');
    });

    test('extracts the checklist in order', () {
      expect(content.checklist, const [
        ChecklistItem(text: 'Audit current spacing scale', done: true),
        ChecklistItem(text: 'Define 8-pt grid tokens'),
      ]);
    });

    test('plain text drops formatting and trailing blank lines', () {
      expect(content.plainText, startsWith('The landscape of mobile'));
      expect(content.plainText, isNot(endsWith('\n')));
      expect(content.plainText, contains('\nAudit current spacing scale\n'));
    });

    test('counts title + body words', () {
      expect(NoteContent.countWords('  two   words '), 2);
      expect(
        content.wordCount('Title here'),
        2 + NoteContent.countWords(content.plainText),
      );
    });

    test('collects image embeds; the first is the cover', () {
      final withImages = NoteContent.fromDeltaJson(
        jsonEncode([
          {'insert': 'Look\n'},
          {
            'insert': {'image': 'attachments/a.jpg'},
          },
          {'insert': '\n'},
          {
            'insert': {'image': 'attachments/b.png'},
          },
          {'insert': '\n'},
        ]),
      );
      expect(withImages.imagePaths, ['attachments/a.jpg', 'attachments/b.png']);
      expect(withImages.coverImage, 'attachments/a.jpg');
      expect(withImages.plainText, 'Look');
    });

    test('invalid JSON yields empty content', () {
      expect(NoteContent.fromDeltaJson('not json'), same(NoteContent.empty));
      expect(NoteContent.fromDeltaJson('{}'), same(NoteContent.empty));
      expect(NoteContent.empty.coverImage, isNull);
    });
  });

  group('NoteExport', () {
    final note = Note(
      id: 'n1',
      title: 'Mobile App Design Trends 2024',
      contentDelta: kMockupDelta,
      createdAt: kNotesNow,
      updatedAt: kNotesNow,
    );

    test('plain text uses [x] / [ ] for checklists', () {
      final text = NoteExport.toText(note);
      expect(text, startsWith('Mobile App Design Trends 2024\n\n'));
      expect(text, contains('[x] Audit current spacing scale'));
      expect(text, contains('[ ] Define 8-pt grid tokens'));
      expect(text, contains('“Wait, we should'));
    });

    test('markdown renders headings, emphasis, tasks and quotes', () {
      final md = NoteExport.toMarkdown(note);
      expect(md, startsWith('# Mobile App Design Trends 2024'));
      expect(md, contains('#### 1. Minimalism & White Space'));
      expect(md, contains('**generous padding**'));
      expect(md, contains('- [x] Audit current spacing scale'));
      expect(md, contains('> Wait, we should'));
    });

    test('file stem is safe and bounded', () {
      expect(NoteExport.fileStem(note), 'Mobile App Design Trends 2024');
      final odd = Note(
        id: 'x',
        title: 'a/b:c*?"<>|',
        createdAt: kNotesNow,
        updatedAt: kNotesNow,
      );
      expect(NoteExport.fileStem(odd), 'a b c');
      expect(NoteExport.fileStem(note.copyWith(title: 'x' * 100)).length, 60);
    });

    test('formats know their extension and mime type', () {
      expect(NoteExportFormat.pdf.extension, 'pdf');
      expect(NoteExportFormat.markdown.mimeType, 'text/markdown');
    });
  });
}

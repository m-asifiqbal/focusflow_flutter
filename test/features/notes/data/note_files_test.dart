/// NoteFileStore (attachments under the documents dir, relative paths)
/// and NoteShareService (render bytes; plaintext export deleted after share).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/notes/data/export/note_pdf_builder.dart';
import 'package:focusflow/features/notes/data/export/note_share_service.dart';
import 'package:focusflow/features/notes/data/files/note_file_store.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/services/note_export.dart';

import '../notes_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late NoteFileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ff_files');
    store = NoteFileStore(root);
  });
  tearDown(() => root.deleteSync(recursive: true));

  group('NoteFileStore', () {
    test('imports an image as attachments/<id>.<ext>', () async {
      final src = File('${root.path}/IMG_1.PNG')..writeAsBytesSync([1, 2, 3]);
      final stored = await store.importImage(src.path, 'abc');
      expect(stored.relativePath, 'attachments/abc.png');
      expect(stored.fileName, 'IMG_1.PNG');
      expect(stored.mimeType, 'image/png');
      expect(stored.sizeBytes, 3);
      expect(store.resolve(stored.relativePath)!.readAsBytesSync(), [1, 2, 3]);
    });

    test('unknown extensions fall back to .jpg', () async {
      final src = File('${root.path}/photo')..writeAsBytesSync([1]);
      final stored = await store.importImage(src.path, 'x');
      expect(stored.relativePath, 'attachments/x.jpg');
      expect(stored.mimeType, 'image/jpeg');
    });

    test('never resolves outside the documents directory', () {
      expect(store.resolve(''), isNull);
      expect(store.resolve('/etc/passwd'), isNull);
      expect(store.resolve('../outside.jpg'), isNull);
      expect(store.resolve('attachments/../../x'), isNull);
      expect(store.resolve('attachments/a.jpg'), isNotNull);
    });

    test('delete removes the file and ignores missing ones', () async {
      final src = File('${root.path}/a.jpg')..writeAsBytesSync([1]);
      final stored = await store.importImage(src.path, 'd');
      await store.delete(stored.relativePath);
      expect(store.resolve(stored.relativePath)!.existsSync(), isFalse);
      await store.delete('attachments/missing.jpg');
    });
  });

  group('NoteShareService.render', () {
    final note = Note(
      id: 'n1',
      title: 'Mobile App Design Trends 2024',
      contentDelta: kMockupDelta,
      createdAt: kNotesNow,
      updatedAt: kNotesNow,
    );
    final service = NoteShareService(
      pdf: NotePdfBuilder(resolveImage: (p) => null),
    );

    test('text and markdown are UTF-8 of NoteExport', () async {
      final txt = await service.render(note, NoteExportFormat.text);
      expect(utf8.decode(txt), NoteExport.toText(note));
      final md = await service.render(note, NoteExportFormat.markdown);
      expect(utf8.decode(md), NoteExport.toMarkdown(note));
    });

    test('pdf is a real PDF document', () async {
      final pdf = await service.render(
        note,
        NoteExportFormat.pdf,
        subtitle: 'Edited today · 214 words',
      );
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(pdf.length, greaterThan(1000));
    });
  });

  group('NoteShareService.share', () {
    final note = Note(
      id: 'n2',
      title: 'Secret plans',
      contentDelta: kMockupDelta,
      createdAt: kNotesNow,
      updatedAt: kNotesNow,
    );

    NoteShareService service({required bool keep, required ShareFiles share}) =>
        NoteShareService(
          pdf: NotePdfBuilder(resolveImage: (p) => null),
          shareFiles: share,
          tempDir: () async => root,
          keepUntilNextExport: keep,
        );

    test(
      'the plaintext file exists during the share and is gone after',
      () async {
        String? sharedPath;
        final ok = await service(
          keep: false,
          share: (files, subject) async {
            sharedPath = files.single.path;
            expect(File(sharedPath!).existsSync(), isTrue);
            expect(subject, 'Secret plans');
            return true;
          },
        ).share(note, NoteExportFormat.text);
        expect(ok, isTrue);
        expect(File(sharedPath!).existsSync(), isFalse);
      },
    );

    test('deleted even when the share sheet throws', () async {
      String? sharedPath;
      await expectLater(
        service(
          keep: false,
          share: (files, _) async {
            sharedPath = files.single.path;
            throw StateError('platform');
          },
        ).share(note, NoteExportFormat.markdown),
        throwsStateError,
      );
      expect(File(sharedPath!).existsSync(), isFalse);
    });

    test('Android keeps it only until the next export / purge', () async {
      final paths = <String>[];
      final s = service(
        keep: true,
        share: (files, _) async {
          paths.add(files.single.path);
          return false;
        },
      );
      expect(await s.share(note, NoteExportFormat.text), isFalse);
      expect(File(paths.first).existsSync(), isTrue);
      await s.share(note, NoteExportFormat.markdown);
      expect(File(paths.first).existsSync(), isFalse);
      await s.purgeExports();
      expect(File(paths.last).existsSync(), isFalse);
    });
  });
}

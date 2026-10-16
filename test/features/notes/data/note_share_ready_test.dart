/// The export service is only handed out once the file store is ready, so
/// a PDF export right after launch still resolves its images.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';

import '../../../helpers/test_container.dart';
import '../notes_fixtures.dart';

void main() {
  test('noteShareServiceReadyProvider waits for the file store', () async {
    final docs = Directory.systemTemp.createTempSync('ff_share');
    addTearDown(() => docs.deleteSync(recursive: true));
    final h = await TestHarness.create(
      now: kNotesNow,
      overrides: notesOverrides(docs),
    );
    addTearDown(h.dispose);

    // Read synchronously before the store resolved: no image resolver.
    expect(h.read(noteShareServiceProvider).pdf.resolveImage, isNull);

    final service = await h.read(noteShareServiceReadyProvider.future);
    final resolve = service.pdf.resolveImage;
    expect(resolve, isNotNull);
    expect(resolve!('attachments/a.png')!.path, startsWith(docs.path));
  });
}

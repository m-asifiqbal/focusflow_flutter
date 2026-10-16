/// NoteEditorController: create / open, debounced auto-save, flush,
/// discard of empty new notes, colour / pin / tags, image attachments.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notes/presentation/notifiers/note_editor_controller.dart';
import 'package:focusflow/features/notes/presentation/state/note_editor_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/test_container.dart';
import '../notes_fixtures.dart';

void main() {
  late Directory docs;
  late TestHarness h;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('ff_docs');
    h = await TestHarness.create(
      now: kNotesNow,
      overrides: notesOverrides(docs),
    );
  });
  tearDown(() async {
    await h.dispose();
    docs.deleteSync(recursive: true);
  });

  /// Opens an editor session and keeps it alive like a mounted screen.
  Future<(NoteEditorController, NoteEditorState)> open(
    NoteEditorArgs args,
  ) async {
    final provider = noteEditorControllerProvider(args);
    final sub = h.container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    final state = await h.container.read(provider.future);
    return (h.container.read(provider.notifier), state);
  }

  NoteDraft draft(String title, String body) => NoteDraft(
    title: title,
    deltaJson: jsonEncode([
      {'insert': '$body\n'},
    ]),
  );

  NotesRepository notes() => h.read(notesRepositoryProvider);

  test(
    'creates a prefilled new note in folder + tag + default colour',
    () async {
      await h.container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(notesDefaultColor: () => 'FEF3C7'));
      final folderId = await h
          .read(foldersRepositoryProvider)
          .create(ItemType.note, 'Ideas');
      final (_, state) = await open(
        NoteEditorArgs(
          text: 'Hello there',
          folderId: folderId,
          tag: 'ux',
          session: Object(),
        ),
      );
      expect(state.createdHere, isTrue);
      final note = (await notes().getNote(state.noteId))!;
      expect(note.plainText, 'Hello there');
      expect(note.folderName, 'Ideas');
      expect(note.tags.map((t) => t.name), ['ux']);
      expect(note.colorHex, 'FEF3C7');
    },
  );

  test('a missing note fails with NoteNotFoundException', () async {
    final provider = noteEditorControllerProvider(
      const NoteEditorArgs(noteId: 'nope'),
    );
    final sub = h.container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      h.container.read(provider.future),
      throwsA(isA<NoteNotFoundException>()),
    );
  });

  test('debounces edits, then saves derived content', () async {
    final id = await seedMockupNote(h);
    final (controller, _) = await open(NoteEditorArgs(noteId: id));
    final provider = noteEditorControllerProvider(NoteEditorArgs(noteId: id));

    controller.onChanged(draft('Renamed', 'one two three'));
    expect(h.container.read(provider).value!.status, NoteSaveStatus.saving);
    expect((await notes().getNote(id))!.title, isNot('Renamed'));

    await Future<void>.delayed(
      NoteEditorController.debounce + const Duration(milliseconds: 150),
    );
    final note = (await notes().getNote(id))!;
    expect(note.title, 'Renamed');
    expect(note.plainText, 'one two three');
    expect(note.wordCount, 4);
    expect(h.container.read(provider).value!.status, NoteSaveStatus.saved);
  });

  test(
    'flush writes immediately; reverting to saved content is a no-op',
    () async {
      final id = await seedMockupNote(h);
      final (controller, _) = await open(NoteEditorArgs(noteId: id));
      controller.onChanged(draft('Now', 'body'));
      await controller.flush();
      expect((await notes().getNote(id))!.title, 'Now');

      controller.onChanged(draft('Now', 'body'));
      final provider = noteEditorControllerProvider(NoteEditorArgs(noteId: id));
      expect(h.container.read(provider).value!.status, NoteSaveStatus.saved);
    },
  );

  test('close discards an untouched new note', () async {
    final (controller, state) = await open(NoteEditorArgs(session: Object()));
    expect(await notes().getNote(state.noteId), isNotNull);
    expect(await controller.close(), isTrue);
    expect(await notes().getNote(state.noteId), isNull);
    // Idempotent.
    expect(await controller.close(), isFalse);
  });

  test('close keeps a new note that got content (saved first)', () async {
    final (controller, state) = await open(NoteEditorArgs(session: Object()));
    controller.onChanged(draft('', 'Remember the milk'));
    expect(await controller.close(), isFalse);
    expect(
      (await notes().getNote(state.noteId))!.plainText,
      'Remember the milk',
    );
  });

  test('close never discards an existing note', () async {
    final id = await seedMockupNote(h);
    final (controller, _) = await open(NoteEditorArgs(noteId: id));
    controller.onChanged(draft('', ''));
    expect(await controller.close(), isFalse);
    expect(await notes().getNote(id), isNotNull);
  });

  test('colour, pin and tags write through the repository', () async {
    final id = await seedMockupNote(h);
    final (controller, _) = await open(NoteEditorArgs(noteId: id));
    await controller.setColor('DBEAFE');
    expect((await notes().getNote(id))!.colorHex, 'DBEAFE');
    await controller.setColor('ffffff');
    expect((await notes().getNote(id))!.colorHex, isNull);

    await controller.setPinned(false);
    expect((await notes().getNote(id))!.isPinned, isFalse);

    await controller.addTag('#Research ');
    await controller.addTag('research'); // duplicate (case-insensitive)
    var tags = (await notes().getNote(id))!.tags.map((t) => t.name).toSet();
    expect(tags, {'design', 'ux', 'research'});
    await controller.removeTag('UX');
    tags = (await notes().getNote(id))!.tags.map((t) => t.name).toSet();
    expect(tags, {'design', 'research'});
  });

  test('addImage copies into attachments; close prunes unused ones', () async {
    final id = await seedMockupNote(h);
    final (controller, _) = await open(NoteEditorArgs(noteId: id));
    final src = File('${docs.path}/pick.jpg')..writeAsBytesSync([9, 9]);
    final relative = (await controller.addImage(src.path))!;
    expect(relative, startsWith('attachments/'));
    final file = File('${docs.path}/$relative');
    expect(file.existsSync(), isTrue);

    // The image never made it into the body → pruned on close.
    await controller.close();
    expect(file.existsSync(), isFalse);
  });

  test('close keeps an image that sync added to the stored body', () async {
    final id = await seedMockupNote(h);
    final (controller, _) = await open(NoteEditorArgs(noteId: id));
    final file = File('${docs.path}/attachments/synced.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    // Sync / restore writes a new body with an image while the editor is
    // open (the editor's own snapshot doesn't know it).
    await notes().addAttachment(
      id,
      localPath: 'attachments/synced.png',
      fileName: 'synced.png',
    );
    await notes().saveContent(
      id,
      title: 'Synced',
      deltaJson: jsonEncode([
        {'insert': 'From the other phone\n'},
        {
          'insert': {'image': 'attachments/synced.png'},
        },
        {'insert': '\n'},
      ]),
      plainText: 'From the other phone',
      wordCount: 4,
    );
    await controller.close();
    expect(file.existsSync(), isTrue);
    final rows = await h.db
        .customSelect(
          "SELECT COUNT(*) AS c FROM attachments WHERE item_id = '$id'",
        )
        .getSingle();
    expect(rows.read<int>('c'), 1);
  });

  test('pruneAttachments never deletes a file another note uses', () async {
    final a = await notes().createEmpty(title: 'A');
    final b = await notes().createEmpty(title: 'B');
    for (final id in [a, b]) {
      await notes().addAttachment(
        id,
        localPath: 'attachments/shared.png',
        fileName: 'shared.png',
      );
    }
    await notes().addAttachment(
      a,
      localPath: 'attachments/own.png',
      fileName: 'own.png',
    );
    // Neither image is in A's body any more.
    final orphaned = await notes().pruneAttachments(a, const {});
    expect(orphaned, ['attachments/own.png']);
  });

  test('close keeps an empty new note the user archived meanwhile', () async {
    final (controller, state) = await open(NoteEditorArgs(session: Object()));
    await h.read(itemsRepositoryProvider).archive([
      ItemRef(ItemType.note, state.noteId),
    ]);
    expect(await controller.close(), isFalse);
    expect((await notes().getNote(state.noteId))!.isArchived, isTrue);
  });

  test('discarding an empty new note also removes its reminder', () async {
    final (controller, state) = await open(NoteEditorArgs(session: Object()));
    await h
        .read(remindersRepositoryProvider)
        .upsertLinkedReminder(
          ItemRef(ItemType.note, state.noteId),
          title: 'Untitled',
          at: kNotesNow.add(const Duration(days: 1)),
        );
    expect(await controller.close(), isTrue);
    final rows = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM reminders')
        .getSingle();
    expect(rows.read<int>('c'), 0);
  });

  test('close waits for holdCloseUntil work before the last save', () async {
    final id = await seedMockupNote(h);
    final (controller, _) = await open(NoteEditorArgs(noteId: id));
    final gate = Completer<void>();
    controller.holdCloseUntil(gate.future);
    final closing = controller.close();
    // The final dictation words arrive while closing.
    controller.onChanged(draft('Dictated', 'final words'));
    gate.complete();
    await closing;
    expect((await notes().getNote(id))!.plainText, 'final words');
  });

  test('markUnlocked flags the session', () async {
    final id = await seedMockupNote(h, locked: true);
    final (controller, state) = await open(NoteEditorArgs(noteId: id));
    expect(state.unlocked, isFalse);
    controller.markUnlocked();
    final provider = noteEditorControllerProvider(NoteEditorArgs(noteId: id));
    expect(h.container.read(provider).value!.unlocked, isTrue);
  });

  test('args with different sessions are different controllers', () {
    expect(
      NoteEditorArgs(session: Object()) == NoteEditorArgs(session: Object()),
      isFalse,
    );
    const a = NoteEditorArgs(noteId: 'a');
    expect(a, const NoteEditorArgs(noteId: 'a'));
    expect(a.isNew, isFalse);
  });
}

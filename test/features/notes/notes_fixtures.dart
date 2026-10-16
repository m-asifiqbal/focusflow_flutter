/// Shared seed data for the notes tests: the mockup note of screen 08
/// ("Mobile App Design Trends 2024" in Ideas, #design #ux, pinned,
/// reminder Friday) and fakes for the image picker / dictation services.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notes/data/files/note_image_picker.dart';
import 'package:focusflow/features/notes/data/voice/voice_dictation.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

/// Tuesday 9 June 2026, 9:41 — the mockup's status-bar time.
final DateTime kNotesNow = DateTime(2026, 6, 9, 9, 41);

/// The body of the mockup note as Quill Delta ops.
final List<Map<String, Object?>> kMockupOps = [
  {
    'insert':
        'The landscape of mobile app design is shifting towards more '
        'organic, fluid experiences. Here are the key pillars for '
        'FocusFlow:\n',
  },
  {'insert': '1. Minimalism & White Space'},
  {
    'insert': '\n',
    'attributes': {'header': 3},
  },
  {'insert': 'Reducing cognitive load is paramount. Use '},
  {
    'insert': 'generous padding',
    'attributes': {'bold': true},
  },
  {'insert': " and clear hierarchy to guide the user's eye.\n"},
  {'insert': 'Audit current spacing scale'},
  {
    'insert': '\n',
    'attributes': {'list': 'checked'},
  },
  {'insert': 'Define 8-pt grid tokens'},
  {
    'insert': '\n',
    'attributes': {'list': 'unchecked'},
  },
  {'insert': '2. Accessibility First'},
  {
    'insert': '\n',
    'attributes': {'header': 3},
  },
  {
    'insert':
        'High contrast and readable fonts are no longer optional. Every '
        'element should be tappable and accessible.\n',
  },
  {'insert': 'Wait, we should also consider the dark mode experience...'},
  {
    'insert': '\n',
    'attributes': {'blockquote': true},
  },
  {
    'insert':
        'Motion should feel calm: short, eased transitions that respect '
        'the reduce motion setting.\n',
  },
];

String get kMockupDelta => jsonEncode(kMockupOps);

/// Seeds the mockup note; returns its id. Run inside `tester.runAsync`.
Future<String> seedMockupNote(
  TestHarness h, {
  bool locked = false,
  bool archived = false,
}) async {
  final folderId = await h
      .read(foldersRepositoryProvider)
      .create(ItemType.note, 'Ideas');
  final notes = h.read(notesRepositoryProvider);
  h.clock.set(DateTime(2026, 6, 9, 9, 12));
  const title = 'Mobile App Design Trends 2024';
  final id = await notes.createEmpty(
    folderId: folderId,
    tagNames: ['design', 'ux'],
    title: title,
  );
  final content = NoteContent.fromDeltaJson(kMockupDelta);
  await notes.saveContent(
    id,
    title: title,
    deltaJson: kMockupDelta,
    plainText: content.plainText,
    checklist: content.checklist,
    wordCount: 214,
  );
  await notes.setPinned(id, true);
  await h
      .read(remindersRepositoryProvider)
      .upsertLinkedReminder(
        noteRef(id),
        title: title,
        at: DateTime(2026, 6, 12, 10),
      );
  if (locked) await notes.setLocked(id, true);
  if (archived) {
    await h.read(itemsRepositoryProvider).archive([noteRef(id)]);
  }
  h.clock.set(kNotesNow);
  return id;
}

ItemRef noteRef(String id) => ItemRef(ItemType.note, id);

/// Dictation fake: emits [words] as a partial then a final result.
class FakeVoiceDictation implements VoiceDictation {
  FakeVoiceDictation({this.words = 'hello from voice', this.available = true});

  final String words;
  final bool available;
  int stops = 0;

  @override
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(String text) onDone,
  }) async {
    if (!available) return false;
    onText(words.split(' ').first);
    onDone(words);
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}

/// Image picker fake returning a real temporary file.
class FakeImagePicker implements NoteImagePicker {
  FakeImagePicker(this.path);

  final String? path;
  final picked = <NoteImageSource>[];

  @override
  Future<String?> pick(NoteImageSource source) async {
    picked.add(source);
    return path;
  }
}

/// Overrides for a temp documents dir + the fakes.
List<Override> notesOverrides(
  Directory docs, {
  VoiceDictation? voice,
  NoteImagePicker? picker,
}) => [
  appDocumentsDirProvider.overrideWith((ref) async => docs),
  voiceDictationProvider.overrideWithValue(voice ?? FakeVoiceDictation()),
  noteImagePickerProvider.overrideWithValue(picker ?? FakeImagePicker(null)),
];

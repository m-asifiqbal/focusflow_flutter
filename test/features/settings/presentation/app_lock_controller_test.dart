/// AppLockController rules (unlock per OS result, resume re-locking) and
/// TagsFoldersController Undo round-trips, against a keyed temp-file DB.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/settings/data/local_device_authenticator.dart';
import 'package:focusflow/features/settings/domain/services/device_authenticator.dart';
import 'package:focusflow/features/settings/presentation/notifiers/tags_folders_controller.dart';
import 'package:focusflow/features/settings/presentation/providers/app_lock_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late FakeDeviceAuthenticator auth;

  setUp(() async {
    auth = FakeDeviceAuthenticator();
    h = await TestHarness.create(
      now: DateTime(2026, 6, 12, 9, 41),
      overrides: [deviceAuthenticatorProvider.overrideWithValue(auth)],
    );
    await h.updateSettings((s) => s.copyWith(appLockEnabled: true));
  });
  tearDown(() => h.dispose());

  AppLockController lock() => h.read(appLockControllerProvider.notifier);
  bool locked() => h.read(appLockControllerProvider).locked;

  group('unlock result', () {
    final cases = <DeviceAuthResult, bool>{
      DeviceAuthResult.success: true,
      DeviceAuthResult.cancelled: false,
      DeviceAuthResult.failed: false,
      DeviceAuthResult.lockedOut: false,
      // A screen lock still exists: a biometric error must not unlock.
      DeviceAuthResult.unavailable: false,
    };
    for (final MapEntry(key: result, value: unlocks) in cases.entries) {
      test('$result ${unlocks ? 'unlocks' : 'keeps it locked'}', () async {
        expect(locked(), isTrue);
        auth.result = result;
        expect(await lock().unlock(), unlocks);
        expect(locked(), !unlocks);
      });
    }

    test('no screen lock on the device at all lets the owner in', () async {
      auth.supported = false;
      expect(await lock().unlock(), isTrue);
      expect(locked(), isFalse);
      expect(h.read(appLockControllerProvider).message, isNotNull);
    });
  });

  test('resume reports justLocked only for a real background stint', () async {
    auth.result = DeviceAuthResult.cancelled;
    await lock().unlock();
    // Still locked after a cancel: resuming must not ask again.
    expect(lock().onResume(), isFalse);
    lock().onBackground();
    h.clock.advance(AppLockController.grace * 2);
    expect(lock().onResume(), isFalse);

    auth.result = DeviceAuthResult.success;
    await lock().unlock();
    lock().onBackground();
    h.clock.advance(AppLockController.grace);
    expect(lock().onResume(), isTrue);
    expect(locked(), isTrue);
  });

  group('tags & folders undo', () {
    Future<List<String>> tagNames(ItemRef r) async => [
      for (final t in await h.read(tagsRepositoryProvider).watchTagsOf(r).first)
        t.name,
    ];

    test('folder delete undo restores active, archived and deleted', () async {
      final folders = h.read(foldersRepositoryProvider);
      final notes = h.read(notesRepositoryProvider);
      final items = h.read(itemsRepositoryProvider);
      final fid = await folders.create(ItemType.note, 'Journal');
      final refs = [
        for (final t in ['a', 'b', 'c'])
          ItemRef(
            ItemType.note,
            await notes.createEmpty(folderId: fid, title: t),
          ),
      ];
      await items.archive([refs[1]]);
      await items.moveToTrash([refs[2]]);

      final folder = (await folders.getFolder(fid))!;
      final undo = await h
          .read(tagsFoldersControllerProvider)
          .deleteFolder(folder);
      expect(await folders.getFolder(fid), isNull);
      await undo();

      final restored = (await folders.watchFolders(ItemType.note).first)
          .singleWhere((f) => f.name == 'Journal');
      for (final r in refs) {
        expect(
          (await notes.getNote(r.id))!.folderId,
          restored.id,
          reason: r.id,
        );
      }
    });

    test('tag delete and merge undo restore every item', () async {
      final notes = h.read(notesRepositoryProvider);
      final items = h.read(itemsRepositoryProvider);
      final tags = h.read(tagsRepositoryProvider);
      final a = ItemRef(
        ItemType.note,
        await notes.createEmpty(tagNames: ['work', 'ideas']),
      );
      final b = ItemRef(
        ItemType.note,
        await notes.createEmpty(tagNames: ['work']),
      );
      await items.archive([b]);
      final ctl = h.read(tagsFoldersControllerProvider);

      var all = await tags.watchTags().first;
      final work = all.singleWhere((t) => t.name == 'work');
      final undoDelete = await ctl.deleteTag(work);
      expect(await tagNames(a), ['ideas']);
      await undoDelete();
      expect(await tagNames(a), unorderedEquals(['work', 'ideas']));
      expect(await tagNames(b), ['work']);

      all = await tags.watchTags().first;
      final work2 = all.singleWhere((t) => t.name == 'work');
      final ideas = all.singleWhere((t) => t.name == 'ideas');
      final undoMerge = await ctl.mergeTag(work2, ideas);
      expect(await tagNames(b), ['ideas']);
      await undoMerge();
      expect(await tagNames(a), unorderedEquals(['work', 'ideas']));
      expect(await tagNames(b), ['work']);
    });
  });
}

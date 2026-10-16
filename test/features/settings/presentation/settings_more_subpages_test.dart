/// Settings sub-pages — App lock (+ AppLockGate / controller), Tags &
/// folders, Storage, About and the module defaults: render (light + dark
/// captures, 360 pt @ 1.3), write the live settings, never delete user data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';
import 'package:focusflow/features/settings/domain/repository/storage_repository.dart';
import 'package:focusflow/features/settings/domain/services/device_authenticator.dart';
import 'package:focusflow/features/settings/domain/services/privacy_screen.dart';
import 'package:focusflow/features/settings/presentation/providers/app_lock_providers.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

class _FakeAuth implements DeviceAuthenticator {
  DeviceAuthResult next = DeviceAuthResult.success;
  int prompts = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<BiometricKind> biometricKind() async => BiometricKind.faceId;

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    prompts++;
    return next;
  }
}

class _FakePrivacy implements PrivacyScreen {
  bool? enabled;

  @override
  Future<void> setEnabled(bool enabled, {required Color coverColor}) async =>
      this.enabled = enabled;
}

class _FakeStorage implements StorageRepository {
  int cache = 3200000;
  int clears = 0;

  @override
  Future<StorageUsage> measure() async => StorageUsage(
    databaseBytes: 31000000,
    attachmentsBytes: 9400000,
    backupsBytes: 4600000,
    cacheBytes: cache,
  );

  @override
  Future<int> clearCache() async {
    clears++;
    final freed = cache;
    cache = 0;
    return freed;
  }
}

void main() {
  late TestHarness h;
  late _FakeAuth auth;
  late _FakePrivacy privacy;
  late _FakeStorage storage;

  Future<void> setUp(WidgetTester tester) async {
    await loadAppFonts();
    auth = _FakeAuth();
    privacy = _FakePrivacy();
    storage = _FakeStorage();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: DateTime(2026, 6, 12, 9, 41),
        overrides: [
          deviceAuthenticatorProvider.overrideWithValue(auth),
          privacyScreenProvider.overrideWithValue(privacy),
          storageRepositoryProvider.overrideWithValue(storage),
          appVersionProvider.overrideWith((ref) async => 'v1.0.0 (24)'),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(() async {
      final tags = h.read(tagsRepositoryProvider);
      await tags.findOrCreate('work');
      await tags.findOrCreate('ideas');
      final folders = h.read(foldersRepositoryProvider);
      await folders.create(ItemType.note, 'Journal');
      await folders.create(ItemType.task, 'Errands');
    });
  }

  AppSettings settings() => h.read(settingsProvider);

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  const pages = {
    'app_lock': AppRoutes.settingsAppLock,
    'tags_folders': AppRoutes.settingsTagsFolders,
    'storage': AppRoutes.settingsStorage,
    'about': AppRoutes.settingsAbout,
    'module_notes': '/settings/modules/notes',
    'module_tasks': '/settings/modules/tasks',
    'module_reminders': '/settings/modules/reminders',
    'module_habits': '/settings/modules/habits',
  };

  for (final MapEntry(key: name, value: route) in pages.entries) {
    testWidgets('$name renders light, dark and small', (tester) async {
      await setUp(tester);
      await pumpApp(tester, h, route);
      expect(tester.takeException(), isNull);
      await captureScreen(tester, 'settings_$name');
      await pumpApp(tester, h, route, dark: true);
      expect(tester.takeException(), isNull);
      await captureScreen(tester, 'settings_${name}_dark');
      await pumpApp(
        tester,
        h,
        route,
        size: const Size(360, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unknown module shows an empty state', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, '/settings/modules/nope');
    expect(find.text('Nothing to set here'), findsOneWidget);
  });

  testWidgets('app lock: switch asks the device owner both ways', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsAppLock);
    auth.next = DeviceAuthResult.cancelled;
    await tap(tester, find.text('Require Face ID'));
    expect(settings().appLockEnabled, isFalse);
    auth.next = DeviceAuthResult.success;
    await tap(tester, find.text('Require Face ID'));
    expect(settings().appLockEnabled, isTrue);
    final hide = settings().hideInAppSwitcher;
    await tap(tester, find.text('Hide content in app switcher'));
    expect(settings().hideInAppSwitcher, !hide);
    expect(privacy.enabled, !hide);
  });

  testWidgets('app lock: locks after the grace period in the background', (
    tester,
  ) async {
    await setUp(tester);
    await tester.runAsync(
      () => h.updateSettings((s) => s.copyWith(appLockEnabled: true)),
    );
    final lock = h.read(appLockControllerProvider.notifier);
    // A fresh launch is locked until the owner unlocks.
    auth.next = DeviceAuthResult.success;
    await tester.runAsync(lock.unlock);
    expect(h.read(appLockControllerProvider).locked, isFalse);
    // Quick switch: forgiven.
    lock.onBackground();
    h.clock.advance(const Duration(seconds: 3));
    expect(lock.onResume(), isFalse);
    // Longer than the grace period: locked, a failed prompt keeps it so.
    lock.onBackground();
    h.clock.advance(AppLockController.grace);
    expect(lock.onResume(), isTrue);
    auth.next = DeviceAuthResult.failed;
    await tester.runAsync(lock.unlock);
    expect(h.read(appLockControllerProvider).locked, isTrue);
    expect(h.read(appLockControllerProvider).message, isNotNull);
  });

  testWidgets('app lock gate covers the app until unlocked', (tester) async {
    await setUp(tester);
    await tester.runAsync(
      () => h.updateSettings((s) => s.copyWith(appLockEnabled: true)),
    );
    auth.next = DeviceAuthResult.cancelled;
    await pumpApp(tester, h, AppRoutes.settingsStorage);
    expect(find.text('Unlock with Face ID'), findsOneWidget);
    auth.next = DeviceAuthResult.success;
    await tap(tester, find.text('Unlock with Face ID'));
    expect(find.text('Unlock with Face ID'), findsNothing);
    expect(find.text('Clear cache'), findsOneWidget);
  });

  testWidgets('storage: cache is cleared only after confirmation', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsStorage);
    expect(find.text('48 MB on this device'), findsOneWidget);
    await tap(tester, find.text('Clear cache'));
    await tap(tester, find.text('Cancel'));
    expect(storage.clears, 0);
    await tap(tester, find.text('Clear cache').first);
    await tap(tester, find.text('Clear cache').last);
    expect(storage.clears, 1);
    expect(find.text('Freed 3.2 MB'), findsOneWidget);
  });

  testWidgets('tags & folders: live rows and manage sheets', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsTagsFolders);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Errands'), findsOneWidget);
    await tap(tester, find.text('Journal'));
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete folder'), findsOneWidget);
  });

  testWidgets('module defaults persist', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, '/settings/modules/notes');
    await tap(tester, find.text('Default view'));
    await tap(tester, find.text('List').last);
    expect(settings().notesView, NotesView.list);
    await tap(tester, find.text('Colour of new notes'));
    await tap(tester, find.text('Mint').last);
    expect(settings().notesDefaultColor, 'D1FAE5');

    await pumpApp(tester, h, '/settings/modules/tasks');
    final smart = settings().tasksSmartLists;
    await tap(tester, find.text('Smart lists'));
    expect(settings().tasksSmartLists, !smart);
    await tap(tester, find.text('Default list'));
    await tap(tester, find.text('Errands').last);
    expect(settings().tasksDefaultListId, isNotNull);

    await pumpApp(tester, h, '/settings/modules/reminders');
    await tap(tester, find.text('Default snooze'));
    await tap(tester, find.text('30 min').last);
    expect(settings().defaultSnoozeMinutes, 30);

    await pumpApp(tester, h, '/settings/modules/habits');
    await tap(tester, find.text('Day resets at'));
    await tap(tester, find.text('3:00 AM').last);
    expect(settings().habitResetMinutes, 180);
  });
}

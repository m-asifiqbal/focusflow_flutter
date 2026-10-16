/// "Reminders don't make a sound / don't arrive when the app is closed":
///   • every reminder tone ships as a real WAV (Android res/raw + asset);
///   • channels are versioned, tone channels carry their sound, alarms use
///     the alarm audio usage and are insistent, iOS requests set sound and
///     presentation explicitly;
///   • the channel is part of the fingerprint (moving to the new channels
///     re-schedules), old channels are retired after the first pass;
///   • saving in an editor hands the reminder to the OS before it returns
///     (no debounce), and so does the app going to the background;
///   • "Allow reminders in the background" is opt-in and asked once.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/background_delivery.dart';
import 'package:focusflow/core/notifications/engine/local_notifications_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/reconciling_engine.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_editor_controller.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/test_container.dart';
import 'fake_gateway.dart';
import 'planner_test_data.dart';

PlannedNotification _n({
  NotificationCategory category = NotificationCategory.reminder,
  String? sound = 'chime',
}) => PlannedNotification(
  id: 7,
  key: 'rem:r:1',
  fireAt: DateTime.utc(2026, 10, 13, 10),
  category: category,
  title: 'Call mom',
  payload: NotificationPayload(key: 'rem:r:1', category: category),
  sound: sound,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled tones', () {
    test('every tone the editor offers ships as a short 44.1 kHz WAV', () {
      final offered = {
        for (final s in ReminderAlertOptions.sounds)
          if (s.key != PlannedNotification.silentSound) s.key,
      };
      expect(NotificationChannelId.tones, offered);
      for (final tone in offered) {
        for (final path in [
          'assets/sounds/$tone.wav',
          'android/app/src/main/res/raw/$tone.wav',
        ]) {
          final bytes = File(path).readAsBytesSync();
          expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF', reason: path);
          expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE', reason: path);
          final header = bytes.buffer.asByteData();
          expect(header.getUint16(22, Endian.little), 1); // mono
          expect(header.getUint32(24, Endian.little), 44100);
          expect(header.getUint16(34, Endian.little), 16);
          final seconds = (bytes.length - 44) / (44100 * 2);
          expect(seconds, inExclusiveRange(0.5, 2.0), reason: path);
        }
      }
      // R8 resource shrinking must keep them (referenced only from Dart).
      final keep = File(
        'android/app/src/main/res/raw/keep.xml',
      ).readAsStringSync();
      for (final tone in offered) {
        expect(keep, contains('@raw/$tone'));
      }
    });
  });

  group('channels', () {
    test('a notification goes to the channel of its sound', () {
      expect(
        NotificationChannelId.forNotification(_n()),
        NotificationChannelId.chime,
      );
      expect(
        NotificationChannelId.forNotification(
          _n(category: NotificationCategory.task, sound: 'bell'),
        ),
        NotificationChannelId.bell,
      );
      expect(
        NotificationChannelId.forNotification(_n(sound: 'silent')),
        NotificationChannelId.silentReminders,
      );
      expect(
        NotificationChannelId.forNotification(
          _n(category: NotificationCategory.alarm),
        ),
        NotificationChannelId.alarms,
      );
      expect(
        NotificationChannelId.forNotification(_n(sound: 'marimba')),
        NotificationChannelId.reminders,
      );
      expect(
        NotificationChannelId.forNotification(
          _n(category: NotificationCategory.habit, sound: null),
        ),
        NotificationChannelId.habits,
      );
    });

    test('ids are versioned; legacy ids are not reused', () {
      final ids = {for (final c in NotificationChannelId.values) c.id};
      expect(ids, hasLength(NotificationChannelId.values.length));
      expect(
        ids.intersection(NotificationChannelId.legacyIds.toSet()),
        isEmpty,
      );
      expect(ids.every((id) => id.endsWith('_v2')), isTrue);
    });

    test('tone channels carry the sound; alarms use the alarm stream', () {
      final chime = LocalNotificationsGateway.channel(
        NotificationChannelId.chime,
      );
      expect(chime.importance, Importance.high);
      expect(chime.playSound, isTrue);
      expect(chime.enableVibration, isTrue);
      expect(
        (chime.sound! as RawResourceAndroidNotificationSound).sound,
        'chime',
      );

      final alarms = LocalNotificationsGateway.channel(
        NotificationChannelId.alarms,
      );
      expect(alarms.importance, Importance.max);
      expect(alarms.audioAttributesUsage, AudioAttributesUsage.alarm);

      final silent = LocalNotificationsGateway.channel(
        NotificationChannelId.silentReminders,
      );
      expect(silent.playSound, isFalse);
      expect(
        LocalNotificationsGateway.channel(
          NotificationChannelId.reminders,
        ).sound,
        isNull, // system default
      );
    });

    test('request details: explicit iOS sound; insistent alarms', () {
      const o = DeliveryOptions();
      final chime = LocalNotificationsGateway.details(_n(), o);
      expect(chime.android!.channelId, 'reminders_chime_v2');
      expect(chime.iOS!.presentSound, isTrue);
      expect(chime.iOS!.presentAlert, isTrue);
      expect(chime.iOS!.presentBanner, isTrue);
      expect(chime.iOS!.presentList, isTrue);
      expect(chime.iOS!.sound, 'chime.wav');

      final other = LocalNotificationsGateway.details(_n(sound: 'marimba'), o);
      expect(other.iOS!.presentSound, isTrue);
      expect(other.iOS!.sound, isNull); // default sound (presentSound)

      final silent = LocalNotificationsGateway.details(_n(sound: 'silent'), o);
      expect(silent.iOS!.presentSound, isFalse);
      expect(silent.android!.playSound, isFalse);

      final alarm = LocalNotificationsGateway.details(
        _n(category: NotificationCategory.alarm),
        o,
      );
      expect(alarm.android!.channelId, 'alarms_v2');
      expect(alarm.android!.audioAttributesUsage, AudioAttributesUsage.alarm);
      expect(alarm.android!.additionalFlags, [4]); // FLAG_INSISTENT
      expect(alarm.android!.fullScreenIntent, isTrue);
    });

    test('the channel is part of the fingerprint', () {
      expect(_n().fingerprint, isNot(_n(sound: 'bell').fingerprint));
      expect(_n(sound: 'marimba').fingerprint, isNot(_n().fingerprint));
    });
  });

  group('engine', () {
    final start = DateTime(2026, 10, 13, 9);
    late TestHarness h;
    late FakeGateway os;

    setUp(() async {
      os = FakeGateway();
      h = await TestHarness.create(
        now: start,
        prefs: {
          SettingsController.prefsKey: jsonEncode(
            quiet.copyWith(notifyReminders: true, notifyTasks: true).toJson(),
          ),
        },
        overrides: [
          notificationGatewayProvider.overrideWithValue(os),
          notificationLedgerStoreProvider.overrideWithValue(
            MemoryLedgerStore(),
          ),
        ],
      );
    });
    tearDown(() => h.dispose());

    Future<ReconcilingNotificationEngine> started() async {
      final engine =
          h.read(notificationEngineProvider) as ReconcilingNotificationEngine;
      await engine.start();
      return engine;
    }

    test('old channels are retired once, after the first pass', () async {
      final engine = await started();
      expect(os.retired, 1);
      await engine.reconcileNow();
      expect(os.retired, 1);
    });

    test('saving in the editor schedules before save() returns', () async {
      await started();
      final args = ReminderEditorArgs(
        title: 'Call mom',
        at: start.add(const Duration(hours: 2)),
      );
      final sub = h.container.listen(
        reminderEditorControllerProvider(args),
        (_, _) {},
      );
      addTearDown(sub.close);
      await h.read(reminderEditorControllerProvider(args).future);
      final id = await h
          .read(reminderEditorControllerProvider(args).notifier)
          .save();
      expect(id, isNotNull);
      // No debounce wait: it is already with the OS.
      expect(os.pending.values.map((n) => n.title), ['Call mom']);
      expect(
        os.pending.values.single.fireAt,
        start.add(const Duration(hours: 2)),
      );
    });

    test('going to the background flushes pending changes', () async {
      final engine = await started();
      expect(os.pending, isEmpty);
      // A write the debounced pass has not picked up yet.
      final refProvider = Provider<Ref>((ref) => ref);
      final ref = h.read(refProvider);
      await h
          .read(remindersRepositoryProvider)
          .save(
            Reminder.draft(
              triggerAt: start.add(const Duration(hours: 3)),
              title: 'Water plants',
            ),
          );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      // Well inside the 400 ms debounce: only the lifecycle flush can have
      // scheduled it.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(os.pending, hasLength(1));
      await engine.flush();
      expect(os.pending, hasLength(1));
      await flushNotifications(ref); // a no-op when nothing changed
      expect(os.pending, hasLength(1));
    });
  });

  group('background delivery (battery optimisation)', () {
    late TestHarness h;
    late FakeBackgroundDelivery battery;

    setUp(() async {
      battery = FakeBackgroundDelivery(unrestricted: false);
      h = await TestHarness.create(
        now: DateTime(2026, 10, 13, 9),
        overrides: [backgroundDeliveryProvider.overrideWithValue(battery)],
      );
    });
    tearDown(() => h.dispose());

    test('suggested until asked once; the request is opt-in', () async {
      await h.read(unrestrictedBackgroundProvider.future);
      expect(h.read(suggestUnrestrictedBackgroundProvider), isTrue);
      expect(battery.requests, 0);

      final refProvider = Provider<Ref>((ref) => ref);
      expect(await requestUnrestrictedBackground(h.read(refProvider)), isTrue);
      expect(battery.requests, 1);
      expect(
        h.read(sharedPreferencesProvider).getBool(backgroundDeliveryAskedKey),
        isTrue,
      );
      expect(await h.read(unrestrictedBackgroundProvider.future), isTrue);
      expect(h.read(suggestUnrestrictedBackgroundProvider), isFalse);
    });

    test('not applicable (iOS) never suggests', () async {
      battery.unrestricted = null;
      h.container.invalidate(unrestrictedBackgroundProvider);
      await h.read(unrestrictedBackgroundProvider.future);
      expect(h.read(suggestUnrestrictedBackgroundProvider), isFalse);
    });
  });
}

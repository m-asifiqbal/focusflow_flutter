/// ============================================================
/// ALARM DRIVER — real alarms (Android), behind a small port
/// ============================================================
///
/// Why: an alarm-style reminder has to *ring* — loop a sound on the alarm
/// stream, vibrate, light the screen over the lock screen — and it has to do
/// that when the app has been swiped away or the phone restarted. A
/// notification (even a "max priority, insistent" one) cannot promise that:
/// it plays its channel sound once and stays quiet in Do-not-disturb. The
/// proven recipe, which every alarm-clock app uses, is native:
///   • `AlarmManager.setAlarmClock` — exempt from Doze and battery savers,
///     shown by the system as "next alarm";
///   • a foreground service that owns the looping sound and vibration, so
///     nothing depends on Dart being alive;
///   • a full-screen intent for the lock screen, and a boot receiver that
///     re-arms the alarms after a restart.
/// The `alarm` package implements exactly that (this file is its only user),
/// including a native Snooze action. iOS has no such API: there alarm-style
/// reminders stay time-sensitive notifications (see the gateway).
///
/// The reconciler never sees this class: [LocalNotificationsGateway] sends a
/// planned *alarm* here instead of to the notification plugin, and
/// [pendingIds] / `cancel` cover both, so planning, the ledger, the inbox and
/// "Missed" catch-up work the same for both kinds.
/// ============================================================
library;

import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/utils/app_logger.dart';

/// A snooze the user chose on the ringing alarm's notification.
@immutable
class AlarmSnooze {
  const AlarmSnooze({required this.payload, required this.nextRingAt});

  /// The [NotificationPayload] string the alarm was armed with.
  final String payload;

  /// When the alarm rings again.
  final DateTime nextRingAt;
}

/// What an alarm needs besides the planned notification.
@immutable
class AlarmRequest {
  const AlarmRequest({
    required this.notification,
    required this.title,
    required this.body,
    this.fullScreen = true,
  });

  final PlannedNotification notification;

  /// Already shaped for the lock-screen setting.
  final String title;
  final String body;

  /// Light up the lock screen (Android 14+ lets the user refuse this).
  final bool fullScreen;
}

abstract class AlarmDriver {
  /// Starts the native side (and replays what happened while the app was
  /// dead). Safe to call more than once.
  Future<void> init();

  /// Arms the alarm for `request.notification.fireAt` (replacing one with
  /// the same id). False when the system refused (no exact-alarm grant,
  /// time already passed): the caller falls back to a notification.
  Future<bool> set(AlarmRequest request);

  /// Cancels the alarm — and silences it when it is ringing right now.
  Future<void> stop(int id);

  /// Ids of alarms armed for a time after [now]. A ringing alarm is not
  /// "scheduled" any more: it has been delivered.
  Future<Set<int>> scheduledIds(DateTime now);

  /// Alarms the service gave up on without ringing (the phone was off at
  /// their time, the system refused them). They stay "pending" until
  /// [forget] — so the reconciler sees a request that never came and shows
  /// it as "Missed", instead of mistaking it for a delivered one.
  Set<int> get dropped;

  /// The reconciler dealt with alarm [id] (cancelled or caught up).
  void forget(int id);

  /// Snoozes taken on the ringing alarm (while the app lives, and those
  /// recorded while it was dead that are still in the future).
  Stream<AlarmSnooze> get snoozes;
}

/// The `alarm` package.
class PackageAlarmDriver implements AlarmDriver {
  PackageAlarmDriver();

  /// Bundled tones (assets/sounds, pubspec) an alarm can loop.
  static const Set<String> tones = {'chime', 'bell', 'gentle', 'pulse'};

  /// The alarm sound is faded in so it never starts at full blast in a quiet
  /// room.
  static const Duration fadeIn = Duration(seconds: 3);

  Future<void>? _init;
  final Set<int> _dropped = {};
  final _snoozes = StreamController<AlarmSnooze>.broadcast();
  StreamSubscription<AlarmEvent>? _events;

  @override
  Stream<AlarmSnooze> get snoozes => _snoozes.stream;

  @override
  Set<int> get dropped => _dropped;

  @override
  void forget(int id) => _dropped.remove(id);

  @override
  Future<void> init() => _init ??= _start();

  Future<void> _start() async {
    try {
      await Alarm.init();
      _events ??= Alarm.events.listen(_onEvent);
    } catch (e) {
      // No native side (tests, an unsupported device): alarms degrade to
      // notifications instead of failing the whole engine.
      AppLogger.w('Alarm service unavailable: $e');
      _init = null;
      rethrow;
    }
  }

  Future<void> _onEvent(AlarmEvent event) async {
    if (event is AlarmDropped) {
      _dropped.add(event.id);
      await Alarm.acknowledgeEvent(event);
      return;
    }
    // Only a snooze that is still ahead: an older one has already rung again
    // on its own, and re-applying it would schedule a stray extra ring.
    if (event is! AlarmMoved ||
        event.cause != AlarmEventCause.snooze ||
        !event.nextRingAt.isAfter(DateTime.now())) {
      await Alarm.acknowledgeEvent(event);
      return;
    }
    try {
      final settings = await Alarm.getAlarm(event.id);
      final payload = settings?.payload;
      if (payload != null) {
        _snoozes.add(
          AlarmSnooze(payload: payload, nextRingAt: event.nextRingAt),
        );
      }
    } finally {
      await Alarm.acknowledgeEvent(event);
    }
  }

  @override
  Future<bool> set(AlarmRequest r) async {
    final n = r.notification;
    final tone = n.tone;
    final snooze = Duration(
      minutes: (n.payload.snoozeMinutes ?? 10).clamp(1, 60).toInt(),
    );
    try {
      await init();
      return await Alarm.set(
        alarmSettings: AlarmSettings(
          id: n.id,
          dateTime: n.fireAt,
          assetAudioPath: tone == null ? null : 'assets/sounds/$tone.wav',
          volumeSettings: VolumeSettings.fade(fadeDuration: fadeIn),
          notificationSettings: NotificationSettings(
            title: r.title,
            body: r.body,
            stopButton: 'Stop',
            androidSnoozeButton: 'Snooze',
            // A stray swipe must not silence a wake-up alarm.
            androidStopAlarmOnDismiss: false,
          ),
          payload: n.payload.encode(),
          androidFullScreenIntent: r.fullScreen,
          androidSnoozeDuration: snooze,
          // Keeps ringing when the app is swiped away: that is the point.
          androidStopAlarmOnTermination: false,
          // The "your alarm may not ring" notice is an iOS thing.
          warningNotificationOnKill: false,
          // An alarm whose phone was off is not worth ringing hours late;
          // the reconciler shows it as "Missed" instead.
          androidStaleAfter: const Duration(minutes: 15),
        ),
      );
    } catch (e) {
      AppLogger.w('Arming alarm #${n.id} failed: $e');
      return false;
    }
  }

  @override
  Future<void> stop(int id) async {
    try {
      await Alarm.stop(id);
    } catch (e) {
      AppLogger.w('Stopping alarm #$id failed: $e');
    }
  }

  @override
  Future<Set<int>> scheduledIds(DateTime now) async {
    try {
      await init();
      return {
        for (final a in await Alarm.getAlarms())
          if (a.dateTime.isAfter(now)) a.id,
      };
    } catch (_) {
      return const {};
    }
  }
}

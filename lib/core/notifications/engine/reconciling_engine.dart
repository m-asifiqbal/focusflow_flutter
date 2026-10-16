/// ============================================================
/// RECONCILING NOTIFICATION ENGINE — keeps the OS schedule in sync
/// ============================================================
///
/// What: the real [NotificationEngine]. After `start()` it watches
///   • schedulable reminders, active tasks and today's habits (repository
///     streams — used only as *triggers*),
///   • the settings and the OS permission,
/// and after each change (debounced) runs one reconcile pass over a fresh
/// planner snapshot. No editor schedules or cancels anything.
///
/// It also wakes itself at the next fire time (to record the delivery in
/// the inbox and roll the 60-request window forward) and at midnight
/// (today's habits / digests change), and handles taps: action buttons via
/// [NotificationActions], body taps as deep links through the router —
/// including the tap that launched the app.
///
/// A background isolate (notification action, maintenance task) pings
/// [NotificationRefreshPort] after writing: the engine then refreshes the
/// app's live queries and re-plans, as on resume.
///
/// Time zone rule (one for reminders, tasks and digests): wall times are
/// planned in the *device* zone, unless Settings › Time zone
/// (`AppSettings.timeZone`) overrides it — then that zone is used for every
/// schedule (NotificationZones.resolve). When the resolved zone changes
/// (travel, or the override edited) the trigger instants of task-linked
/// reminders are re-derived from their floating due day/time in the new
/// zone (TaskReminderZones.align, at the start of every pass) before planning.
///
/// Passes never overlap: a change during a pass schedules one more pass.
/// ============================================================
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/engine/notification_actions.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/engine/planner_snapshot.dart';
import 'package:focusflow/core/notifications/engine/refresh_port.dart';
import 'package:focusflow/core/notifications/engine/task_reminder_zones.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:timezone/timezone.dart' as tz;

class ReconcilingNotificationEngine implements NotificationEngine {
  ReconcilingNotificationEngine(this._ref, {this.debounce = _debounce});

  final Ref _ref;

  /// Quiet period after a change before reconciling (edits come in bursts).
  final Duration debounce;
  static const Duration _debounce = Duration(milliseconds: 400);

  /// Longest sleep between passes while the app runs.
  static const Duration maxSleep = Duration(hours: 6);

  bool _started = false;
  bool _supported = false;
  bool _disposed = false;
  String? _deviceZone;
  tz.Location _location = tz.UTC;
  DateTime? _watchedDay;

  final List<StreamSubscription<Object?>> _subs = [];
  final List<ProviderSubscription<dynamic>> _listeners = [];
  Timer? _debounceTimer;
  ReceivePort? _refreshPort;
  Timer? _wakeTimer;
  Future<void>? _pass;
  bool _again = false;

  /// Result of the last pass (tests, diagnostics).
  ReconcileResult? lastResult;

  NotificationGateway get _gateway => _ref.read(notificationGatewayProvider);

  @override
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    NotificationZones.ensureLoaded();
    try {
      _supported = await _gateway.initialize(onTap: _onTap);
    } catch (e) {
      // No plugin (tests, unsupported platform): stay inert.
      AppLogger.w('Notifications unavailable: $e');
      _supported = false;
    }
    if (!_supported) return;
    _deviceZone = await _gateway.deviceTimeZone();
    await _resolveZone();
    _ref.invalidate(notificationPermissionProvider);
    _refreshPort = NotificationRefreshPort.listen(
      () => unawaited(_refreshFromOtherIsolate()),
    );
    _watchRepositories();
    _listeners
      ..add(
        _ref.listen<AppSettings>(settingsProvider, (prev, next) {
          if (prev?.timeZone != next.timeZone) unawaited(_resolveZone());
          if (prev?.weekStartsOn != next.weekStartsOn) _watchRepositories();
          schedule();
        }),
      )
      ..add(_ref.listen(notificationPermissionProvider, (_, _) => schedule()))
      ..add(_ref.listen(exactAlarmPermissionProvider, (_, _) => schedule()));
    await reconcileNow();
    final tap = await _gateway.launchTap();
    if (tap != null) await _onTap(tap);
  }

  @override
  Future<void> onResume() async {
    if (!_started || !_supported || _disposed) return;
    _ref
      ..invalidate(exactAlarmPermissionProvider)
      ..invalidate(fullScreenAlarmsAllowedProvider);
    await _refreshFromOtherIsolate();
  }

  /// A background isolate may have written to the DB: let every live
  /// query re-read, re-check permissions and the zone, then re-plan.
  /// (The exact-alarm state is part of each pass: a grant / revoke made in
  /// system settings re-schedules every notification.)
  Future<void> _refreshFromOtherIsolate() async {
    if (!_started || !_supported || _disposed) return;
    final db = _ref.read(databaseProvider);
    db.markTablesUpdated([
      db.reminders,
      db.tasks,
      db.habits,
      db.habitLogs,
      db.inboxEntries,
    ]);
    _deviceZone = await _gateway.deviceTimeZone();
    await _resolveZone();
    _ref.invalidate(notificationPermissionProvider);
    await reconcileNow();
  }

  /// Requests a pass after the debounce period.
  void schedule() {
    if (!_supported || _disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(reconcileNow()));
  }

  /// Runs a pass now (or right after the running one).
  Future<void> reconcileNow() async {
    if (!_supported || _disposed) return;
    _debounceTimer?.cancel();
    if (_pass != null) {
      _again = true;
      return _pass;
    }
    final pass = _run();
    _pass = pass;
    try {
      await pass;
    } finally {
      _pass = null;
    }
    if (_again && !_disposed) {
      _again = false;
      await reconcileNow();
    }
  }

  Future<void> _run() async {
    try {
      final settings = _ref.read(settingsProvider);
      // Days follow the planner's zone (AppSettings.timeZone override).
      final today = _today();
      if (_watchedDay != today) _watchRepositories();
      final permission = await _ref.read(notificationPermissionProvider.future);
      // Task reminders follow their floating due time into this zone.
      await TaskReminderZones.align(
        _ref.read(remindersRepositoryProvider),
        _ref.read(sharedPreferencesProvider),
        _location,
        previous: _zones,
      );
      final input = await _ref
          .read(plannerSnapshotLoaderProvider)
          .load(settings, _location);
      final result = await _ref
          .read(notificationReconcilerProvider)
          .reconcile(
            input,
            allowed: permission == NotificationPermission.granted,
            location: _location,
          );
      lastResult = result;
      _armWake(
        result.nextFireAt,
        input.calendar.at(ZoneCalendar.addDays(today, 1), 0),
      );
    } catch (e, st) {
      AppLogger.e('Notification reconcile failed', error: e, stackTrace: st);
    }
  }

  void _armWake(DateTime? nextFire, DateTime midnight) {
    _wakeTimer?.cancel();
    if (_disposed) return;
    final now = _ref.read(clockProvider).now();
    var at = midnight;
    if (nextFire != null && nextFire.isBefore(at)) at = nextFire;
    var wait = at.difference(now) + const Duration(seconds: 2);
    if (wait.isNegative) wait = const Duration(seconds: 2);
    if (wait > maxSleep) wait = maxSleep;
    _wakeTimer = Timer(wait, () => unawaited(reconcileNow()));
  }

  /// Today in the planner's zone (device zone or the settings override).
  DateTime _today() =>
      ZoneCalendar(_location).dayOf(_ref.read(clockProvider).now());

  /// The planning zone (see the header's time zone rule).
  Future<void> _resolveZone() async {
    final previous = _location;
    _location = NotificationZones.resolve(
      override: _ref.read(settingsProvider).timeZone,
      device: _deviceZone,
    );
    if (_resolved && previous.name != _location.name) _zones.add(previous);
    _resolved = true;
  }

  bool _resolved = false;

  /// Zones planned in earlier this session (task reminder re-sync).
  final Set<tz.Location> _zones = {};

  /// (Re)subscribes to the repository streams; today's habits are
  /// re-watched when the day changes.
  void _watchRepositories() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    final settings = _ref.read(settingsProvider);
    final day = _today();
    _watchedDay = day;
    void trigger(Object? _) => schedule();
    void error(Object e) => AppLogger.w('Notification source failed: $e');
    _subs
      ..add(
        _ref
            .read(remindersRepositoryProvider)
            .watchSchedulable()
            .listen(trigger, onError: error),
      )
      ..add(
        _ref
            .read(tasksRepositoryProvider)
            .watchTasks(const TasksQuery())
            .listen(trigger, onError: error),
      )
      ..add(
        _ref
            .read(habitsRepositoryProvider)
            .watchTodayHabits(day, weekStartsOn: settings.weekStartsOn)
            .listen(trigger, onError: error),
      );
  }

  Future<void> _onTap(NotificationTap tap) async {
    final payload = NotificationPayload.decode(tap.payload);
    if (payload == null) return;
    final button = tap.button;
    if (button != null && button != NotificationButton.open) {
      // The OS dismisses the notification itself (cancelNotification).
      await _ref.read(notificationActionsProvider).perform(button, payload);
      await reconcileNow();
      return;
    }
    await reconcileNow(); // records the delivery in the inbox first
    final route = NotificationActions.tapRoute(payload);
    if (route == null) return;
    try {
      final router = _ref.read(routerProvider);
      if (payload.open != null || payload.target != null) {
        unawaited(router.push(route));
      } else {
        router.go(route);
      }
    } catch (e) {
      AppLogger.w('Notification deep link failed: $e');
    }
  }

  void dispose() {
    _disposed = true;
    final port = _refreshPort;
    if (port != null) NotificationRefreshPort.close(port);
    _debounceTimer?.cancel();
    _wakeTimer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    for (final l in _listeners) {
      l.close();
    }
  }
}

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
///
/// Edits reach the OS without waiting for the debounce when it matters:
/// editors await [flush] after saving (see `flushNotifications`), and the
/// engine flushes when the app goes to the background (paused / hidden /
/// detached) — a reminder saved right before the app is swiped away is
/// still handed to the OS, which delivers it with the app closed.
/// ============================================================
library;

import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart'
    show ResultSetImplementation, TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/background_delivery.dart';
import 'package:focusflow/core/notifications/engine/notification_actions.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/engine/planner_snapshot.dart';
import 'package:focusflow/core/notifications/engine/rearm_policy.dart';
import 'package:focusflow/core/notifications/engine/refresh_port.dart';
import 'package:focusflow/core/notifications/engine/task_reminder_zones.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/alarm_guard.dart';
import 'package:focusflow/core/notifications/alarm_overlay.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:timezone/timezone.dart' as tz;

class ReconcilingNotificationEngine implements NotificationEngine {
  ReconcilingNotificationEngine(
    this._ref, {
    this.debounce = _debounce,
    this.settle = Duration.zero,
  });

  final Ref _ref;

  /// How long [start] waits before the first pass when no notification tap
  /// launched the app (see `notificationSettleProvider`).
  final Duration settle;

  /// Quiet period after a change before reconciling (edits come in bursts).
  final Duration debounce;
  static const Duration _debounce = Duration(milliseconds: 400);

  /// Quiet period for [scheduleLazily].
  static const Duration lazyDebounce = Duration(seconds: 3);

  /// Longest sleep between passes while the app runs.
  static const Duration maxSleep = Duration(hours: 6);

  bool _started = false;

  /// The first pass of this process has run (it renews every alarm — see
  /// [NotificationReconciler.reconcile]).
  bool _rearmed = false;
  bool _supported = false;
  bool _disposed = false;
  String? _deviceZone;
  tz.Location _location = tz.UTC;

  final List<StreamSubscription<Object?>> _subs = [];
  final List<ProviderSubscription<dynamic>> _listeners = [];
  Timer? _debounceTimer;
  Timer? _lazyTimer;
  ReceivePort? _refreshPort;
  Timer? _wakeTimer;
  Future<void>? _pass;
  bool _again = false;

  /// Result of the last pass (tests, diagnostics).
  ReconcileResult? lastResult;

  _BackgroundFlush? _lifecycle;
  bool _legacyRetired = false;

  NotificationGateway get _gateway => _ref.read(notificationGatewayProvider);

  @override
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    try {
      _supported = await _gateway.initialize(onTap: _onTap);
    } catch (e) {
      // No plugin (tests, unsupported platform): stay inert.
      AppLogger.w('Notifications unavailable: $e');
      _supported = false;
    }
    if (!_supported) return;
    // A tap that launched the app is served at once — it opens its page.
    // Otherwise the first pass waits for the first screen to finish loading
    // and animating in: planning (with the habits' histories behind it) is
    // real work, and nothing it schedules is due within seconds.
    final tap = await _gateway.launchTap();
    if (tap == null && settle > Duration.zero) {
      await Future<void>.delayed(settle);
      if (_disposed) return;
    }
    NotificationZones.ensureLoaded();
    _deviceZone = await _gateway.deviceTimeZone();
    await _resolveZone();
    _ref.invalidate(notificationPermissionProvider);
    _refreshPort = NotificationRefreshPort.listen(
      () => unawaited(_refreshFromOtherIsolate()),
    );
    _watchChanges();
    _observeLifecycle();
    _listeners
      ..add(
        _ref.listen<AppSettings>(settingsProvider, (prev, next) {
          if (prev?.timeZone != next.timeZone) unawaited(_resolveZone());
          // The alarm guard follows its switch at once (nothing is re-planned).
          if (prev != null && prev.keepAlarmsAlive != next.keepAlarmsAlive) {
            unawaited(_syncGuard());
          }
          // A theme, layout or backup setting changes nothing that is
          // planned: it must not cost a full re-plan.
          if (prev == null || _changesPlan(prev, next)) schedule();
        }),
      )
      ..add(
        _ref.listen(notificationPermissionProvider, (prev, next) {
          // The first answer was read by the pass that asked for it; only a
          // *change* of the permission needs a new plan.
          if (_changed(prev, next)) schedule();
        }),
      )
      ..add(
        _ref.listen(exactAlarmPermissionProvider, (prev, next) {
          if (_changed(prev, next)) schedule();
        }),
      );
    if (tap != null) {
      // Serves the tap: runs the pass first (it records the delivery in the
      // inbox), then opens the page.
      await _onTap(tap);
    } else {
      await reconcileNow();
    }
  }

  /// [next] is a new answer that differs from a previous one.
  static bool _changed<T>(AsyncValue<T>? prev, AsyncValue<T> next) =>
      prev != null && prev.hasValue && prev.valueOrNull != next.valueOrNull;

  /// Settings that never change what is planned: appearance, layout,
  /// gestures, security, backup, account and search history. Everything else
  /// (also any setting added later) is assumed to matter.
  static const Set<String> _notPlanned = {
    'onboardingSeen',
    'accountMode',
    'displayName',
    'dailyFocusGoal',
    'languageCode',
    'startScreen',
    'dateFormat',
    'themeMode',
    'accent',
    'textScale',
    'appIcon',
    'listDensity',
    'reduceMotion',
    'useSystemFont',
    'performanceMode',
    'notesView',
    'notesSort',
    'notesDefaultColor',
    'tasksDefaultListId',
    'tasksShowCompleted',
    'tasksSmartLists',
    'homeSections',
    'hiddenHomeSections',
    'libraryShowCounts',
    'hiddenLibraryModules',
    'libraryModuleOrder',
    'swipeLeft',
    'swipeRight',
    'soundsEnabled',
    'hapticsEnabled',
    'appLockEnabled',
    'hideInAppSwitcher',
    'clipboardClearSeconds',
    'vaultBiometrics',
    'vaultAutoLockMinutes',
    'vaultLockOnBackground',
    'vaultBlockScreenshots',
    'vaultReauthToReveal',
    'breachMonitoring',
    'wipeAfterFailedAttempts',
    'autoBackupDrive',
    'syncOnOpen',
    'backupFrequency',
    'backupMinutes',
    'backupWifiOnly',
    'encryptBackups',
    'keepBackups',
    'localBackupFrequency',
    'lastSyncAt',
    'recentSearches',
    'keepAlarmsAlive',
  };

  static bool _changesPlan(AppSettings a, AppSettings b) {
    final before = a.toJson();
    final after = b.toJson();
    for (final e in before.entries) {
      if (_notPlanned.contains(e.key)) continue;
      if (e.value != after[e.key]) return true;
    }
    return false;
  }

  @override
  Future<void> onResume() async {
    if (!_started || !_supported || _disposed) return;
    _ref
      ..invalidate(exactAlarmPermissionProvider)
      ..invalidate(fullScreenAlarmsAllowedProvider)
      ..invalidate(alarmOverAppsAllowedProvider)
      ..invalidate(unrestrictedBackgroundProvider);
    // No table refresh here: a background isolate that wrote pinged the
    // refresh port (delivered, at the latest, as the app resumes), and
    // marking five tables updated makes every live query of the app
    // re-run for nothing.
    await _refreshFromOtherIsolate(markTables: false);
  }

  /// A background isolate may have written to the DB: let every live
  /// query re-read, re-check permissions and the zone, then re-plan.
  /// (The exact-alarm state is part of each pass: a grant / revoke made in
  /// system settings re-schedules every notification.)
  Future<void> _refreshFromOtherIsolate({bool markTables = true}) async {
    if (!_started || !_supported || _disposed) return;
    if (markTables) {
      final db = _ref.read(databaseProvider);
      db.markTablesUpdated([
        db.reminders,
        db.tasks,
        db.habits,
        db.habitLogs,
        db.inboxEntries,
      ]);
    }
    _deviceZone = await _gateway.deviceTimeZone();
    await _resolveZone();
    _ref.invalidate(notificationPermissionProvider);
    await reconcileNow();
  }

  /// Runs a pass that includes every write made before this call (skips
  /// the debounce; waits for a running pass first, since that one may have
  /// read the database before the write). Bounded by [timeout] so a caller
  /// (an editor closing) never hangs.
  Future<void> flush({Duration timeout = const Duration(seconds: 4)}) async {
    if (!_started || !_supported || _disposed) return;
    Future<void> run() async {
      final running = _pass;
      if (running != null) await running;
      await reconcileNow();
    }

    try {
      await run().timeout(timeout);
    } on TimeoutException {
      AppLogger.w('Notification flush timed out');
    }
  }

  void _observeLifecycle() {
    try {
      final observer = _BackgroundFlush(() => unawaited(flush()));
      WidgetsBinding.instance.addObserver(observer);
      _lifecycle = observer;
    } catch (_) {
      // No binding (plain unit tests): nothing to observe.
    }
  }

  /// Requests a pass after the debounce period.
  void schedule() {
    if (!_supported || _disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(reconcileNow()));
  }

  /// Like [schedule], for changes that rarely matter and come in long
  /// bursts (a note being typed saves every few hundred milliseconds).
  void scheduleLazily() {
    if (!_supported || _disposed) return;
    _lazyTimer?.cancel();
    _lazyTimer = Timer(lazyDebounce, () => unawaited(reconcileNow()));
  }

  /// Runs a pass now (or right after the running one).
  Future<void> reconcileNow() async {
    if (!_supported || _disposed) return;
    _debounceTimer?.cancel();
    _lazyTimer?.cancel();
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
      // First pass of this process: the app may have been killed (and its
      // alarms with it) since the last one, so the alarms are renewed — but
      // only those the OS no longer holds, unless a full renewal is due
      // (see RearmPolicy): re-sending all of them at every launch made it
      // stutter.
      final renew = !_rearmed;
      final prefs = _ref.read(sharedPreferencesProvider);
      final now = _ref.read(clockProvider).now();
      final full = renew && RearmPolicy.fullDue(prefs, now);
      final result = await _ref
          .read(notificationReconcilerProvider)
          .reconcile(
            input,
            allowed: permission == NotificationPermission.granted,
            location: _location,
            rearm: renew,
            trustArmed: renew && !full,
          );
      _rearmed = true;
      if (full) await RearmPolicy.markFull(prefs, now);
      lastResult = result;
      unawaited(_syncGuard());
      if (!_legacyRetired) {
        // Every pending request now uses the current channels.
        _legacyRetired = true;
        await _gateway.retireLegacyChannels();
      }
      _armWake(
        result.nextFireAt,
        input.calendar.at(ZoneCalendar.addDays(today, 1), 0),
      );
    } catch (e, st) {
      AppLogger.e('Notification reconcile failed', error: e, stackTrace: st);
    }
  }

  /// Reports what the OS now holds to the alarm guard, which keeps the app
  /// alive for it (core/notifications/alarm_guard.dart).
  Future<void> _syncGuard() async {
    final result = lastResult;
    if (result == null || _disposed) return;
    try {
      await _ref
          .read(alarmGuardProvider)
          .sync(
            enabled: _ref.read(settingsProvider).keepAlarmsAlive,
            pending: result.vitalPending,
            nextAt: result.nextVitalAt,
            lastAt: result.lastVitalAt,
          );
    } catch (e) {
      AppLogger.w('Alarm guard sync failed: $e');
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

  /// Subscribes to *table writes* — a trigger needs no data: the pass
  /// reads a fresh snapshot itself. (Watching the repository streams
  /// instead kept full reminder / task / habit queries, with subtasks and
  /// tags, alive for the whole session and re-ran them on every write,
  /// then ran them once more in the pass.)
  ///
  /// The planner reads reminders, tasks and habits (with their logs). Notes
  /// and vault items matter only through their lifecycle — a reminder
  /// linked to an archived note must stop — so their writes, which are
  /// mostly autosaves, are acted on lazily.
  void _watchChanges() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    final db = _ref.read(databaseProvider);
    void error(Object e) => AppLogger.w('Notification source failed: $e');
    Stream<Object?> writes(
      Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
    ) => db.tableUpdates(TableUpdateQuery.onAllTables(tables));
    _subs
      ..add(
        writes([
          db.reminders,
          db.tasks,
          db.habits,
          db.habitLogs,
        ]).listen((_) => schedule(), onError: error),
      )
      ..add(
        writes([
          db.notes,
          db.vaultItems,
        ]).listen((_) => scheduleLazily(), onError: error),
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
    final lifecycle = _lifecycle;
    if (lifecycle != null) {
      try {
        WidgetsBinding.instance.removeObserver(lifecycle);
      } catch (_) {}
    }
    final port = _refreshPort;
    if (port != null) NotificationRefreshPort.close(port);
    _debounceTimer?.cancel();
    _lazyTimer?.cancel();
    _wakeTimer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    for (final l in _listeners) {
      l.close();
    }
  }
}

/// Flushes pending notification work when the app leaves the foreground.
class _BackgroundFlush with WidgetsBindingObserver {
  _BackgroundFlush(this._flush);

  final void Function() _flush;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _flush();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }
}

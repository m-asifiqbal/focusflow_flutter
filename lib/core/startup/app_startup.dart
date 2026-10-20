/// ============================================================
/// APP STARTUP HOST — runs app-level jobs after the first frame and on resume
/// ============================================================
///
/// - Notification engine start / resume reconcile (core/notifications)
/// - Background job scheduling (core/sync/background_tasks.dart), which also
///   runs an overdue backup
/// - Maintenance: purge Recently Deleted items older than 30 days
/// - Sync on open (core/sync/open_sync.dart): at launch, and on a resume
///   after at least [OpenSync.resumeAfter] in the background
///
/// Every job is fire-and-forget and isolated: one failing never blocks the UI
/// or the others.
///
/// Only the notification engine starts at once (a notification tap that
/// launched the app must open its page now). Scheduling, the overdue backup,
/// the purge and the launch sync wait [settleDelay]: they are not needed to
/// show anything, and running them while the first screen loads its data
/// and animates in costs frames. Opening the app is the moment the user
/// watches it most.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/startup/maintenance.dart';
import 'package:focusflow/core/sync/background_tasks.dart';
import 'package:focusflow/core/sync/open_sync.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class AppStartupHost extends ConsumerStatefulWidget {
  const AppStartupHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppStartupHost> createState() => _AppStartupHostState();
}

class _AppStartupHostState extends ConsumerState<AppStartupHost>
    with WidgetsBindingObserver {
  /// How long after launch the non-urgent jobs wait.
  static const Duration settleDelay = Duration(seconds: 4);

  Timer? _settleTimer;

  /// When the app last left the foreground (null while visible).
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLaunch());
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _hiddenAt ??= ref.read(clockProvider).now();
      case AppLifecycleState.resumed:
        final hidden = _hiddenAt;
        _hiddenAt = null;
        _onResume(
          away: hidden == null
              ? Duration.zero
              : ref.read(clockProvider).now().difference(hidden),
        );
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _onLaunch() {
    _run(
      'notifications.start',
      () => ref.read(notificationEngineProvider).start(),
    );
    _settleTimer = Timer(settleDelay, () {
      if (!mounted) return;
      _run(
        'background.schedule',
        () => ref.read(backgroundTasksProvider).ensureScheduled(),
      );
      _run('maintenance', () => ref.read(maintenanceProvider).runIfDue());
      _run('sync.open', () => ref.read(openSyncProvider).runIfDue());
    });
  }

  void _onResume({required Duration away}) {
    _run(
      'notifications.resume',
      () => ref.read(notificationEngineProvider).onResume(),
    );
    _run('maintenance', () => ref.read(maintenanceProvider).runIfDue());
    // Back after a real break counts as opening the app again. Before the
    // launch sync had its turn (settle timer pending) it isn't needed.
    if (away >= OpenSync.resumeAfter && !(_settleTimer?.isActive ?? true)) {
      _run('sync.open', () => ref.read(openSyncProvider).runIfDue());
    }
  }

  void _run(String name, Future<void> Function() job) {
    unawaited(
      Future(job).catchError((Object e, StackTrace st) {
        AppLogger.e('Startup job "$name" failed', error: e, stackTrace: st);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

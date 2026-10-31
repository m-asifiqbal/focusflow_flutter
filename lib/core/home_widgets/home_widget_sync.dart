/// ============================================================
/// HOME WIDGET SYNC — keeps the Android widgets current while the app runs
/// ============================================================
///
/// What: while the app is open, watches the data the widgets show (today's
/// tasks, reminders, habits, medicine doses, recent notes) and the settings
/// that change how they look, and — after a short quiet period — builds a new
/// snapshot ([WidgetSnapshotBuilder]) and pushes it to the launcher side
/// ([HomeWidgetChannel]). An unchanged snapshot is not pushed again. The
/// native side also refreshes on its own schedule and after a tap on a
/// widget; the background isolate pushes after a widget action
/// ([pushWidgetSnapshot]).
/// Why debounced: completing five tasks in a row, or an import, must cost one
/// rebuild, not five (rule: do not decrease performance). Nothing runs when
/// there is no widget feature (iOS) or no widget placed ([HomeWidgetChannel]
/// reports it; the build is still cheap — a handful of indexed queries).
/// ============================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/home_widgets/home_widget_channel.dart';
import 'package:focusflow/core/home_widgets/widget_snapshot_builder.dart';
import 'package:focusflow/core/items/data/stream_utils.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Reads a provider (a `Ref.read` or a container's `read`).
typedef WidgetReader = T Function<T>(ProviderListenable<T> provider);

/// The settings the widgets depend on, as one comparable string (for
/// `select`).
String widgetSettingsOf(AppSettings s) => [
  s.widgetsTheme.name,
  s.widgetsShowNoteText,
  s.widgetsShowCompleted,
  s.accent.name,
  s.themeMode.name,
  s.use24HourTime,
  s.weekStartsOn,
  s.languageCode,
].join('|');

/// Builds a snapshot from [read] and pushes it. Used by the app (debounced)
/// and by the background isolate after a widget action. Never throws.
Future<bool> pushWidgetSnapshot(
  WidgetReader read, {
  HomeWidgetChannel? channel,
}) async {
  try {
    final snapshot = await _builder(read).build();
    return await (channel ?? const HomeWidgetChannel()).push(
      jsonEncode(snapshot),
    );
  } on Object catch (e, st) {
    AppLogger.w('Widget snapshot failed (${e.runtimeType})');
    AppLogger.e('widget snapshot', error: e, stackTrace: st);
    return false;
  }
}

WidgetSnapshotBuilder _builder(WidgetReader read) => WidgetSnapshotBuilder(
  tasks: read(tasksRepositoryProvider),
  reminders: read(remindersRepositoryProvider),
  habits: read(habitsRepositoryProvider),
  medicines: read(medicinesRepositoryProvider),
  notes: read(notesRepositoryProvider),
  settings: read(settingsProvider),
  now: read(clockProvider).now(),
);

class HomeWidgetSync {
  HomeWidgetSync(this._ref, {HomeWidgetChannel? channel})
    : _channel = channel ?? const HomeWidgetChannel();

  final Ref _ref;
  final HomeWidgetChannel _channel;

  /// Quiet time after the last change before a snapshot is built.
  static const Duration debounce = Duration(milliseconds: 1500);

  /// The doses' "due / missed" states move with the clock.
  static const Duration refreshEvery = Duration(minutes: 15);

  StreamSubscription<List<Object?>>? _data;
  ProviderSubscription<String>? _settings;
  Timer? _debounce;
  Timer? _tick;
  String? _last;
  bool _running = false;
  bool _dirty = false;

  bool _starting = false;

  /// Starts watching (once) — only when a widget is actually on the home
  /// screen: with none there is nothing to feed, so no stream, timer or
  /// query runs at all. Called at launch, on resume and after the user adds
  /// a widget, so the first one placed starts it.
  Future<void> start() async {
    if (!HomeWidgetChannel.supported || _data != null || _starting) return;
    _starting = true;
    try {
      final counts = await _channel.counts();
      if (counts.values.every((n) => n == 0)) return;
    } finally {
      _starting = false;
    }
    if (_data != null) return;
    final today = DateUtilsX.dateOnly(_ref.read(clockProvider).now());
    _data = combineLatestList<List<Object?>>(<Stream<Object?>>[
      _ref
          .read(tasksRepositoryProvider)
          .watchTasks(TasksQuery(scope: TasksScope.today, day: today)),
      _ref.read(remindersRepositoryProvider).watchForDay(today),
      _ref
          .read(habitsRepositoryProvider)
          .watchTodayHabits(
            today,
            weekStartsOn: _ref.read(settingsProvider).weekStartsOn,
          ),
      _ref.read(medicinesRepositoryProvider).watchDay(today),
      _ref
          .read(notesRepositoryProvider)
          .watchNotes(const NotesQuery(limit: WidgetSnapshotBuilder.maxItems)),
    ], (v) => v).listen((_) => schedule(), onError: (_) {});
    _settings = _ref.listen<String>(
      settingsProvider.select(widgetSettingsOf),
      (_, _) => schedule(),
    );
    _tick = Timer.periodic(refreshEvery, (_) => schedule(force: true));
    schedule();
  }

  /// A change happened: rebuild after the quiet period.
  void schedule({bool force = false}) {
    if (!HomeWidgetChannel.supported) return;
    if (_data == null) {
      unawaited(start());
      return;
    }
    if (force) _last = null;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(refresh()));
  }

  /// Builds and pushes now (skipped when nothing changed). One at a time;
  /// a change during a build runs it once more.
  Future<void> refresh() async {
    if (_running) {
      _dirty = true;
      return;
    }
    _running = true;
    try {
      do {
        _dirty = false;
        final snapshot = await _builder(_ref.read).build();
        final key = jsonEncode(snapshot..remove('at'));
        if (key == _last) continue;
        final ok = await _channel.push(
          jsonEncode({
            ...snapshot,
            'at': DateTime.now().millisecondsSinceEpoch,
          }),
        );
        if (ok) _last = key;
      } while (_dirty);
    } on Object catch (e) {
      AppLogger.w('Widget sync failed (${e.runtimeType})');
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _debounce?.cancel();
    _tick?.cancel();
    _settings?.close();
    unawaited(_data?.cancel());
    _data = null;
  }
}

final homeWidgetSyncProvider = Provider<HomeWidgetSync>((ref) {
  final sync = HomeWidgetSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});

/// ============================================================
/// WIDGET ACTIONS — what a tap on a widget's check circle does
/// ============================================================
///
/// What: the action the native widget hands over (via a WorkManager task, see
/// BackgroundTasks.widgetActionTask) when the user taps the check circle of a
/// task, reminder, habit or medicine dose: [WidgetActionKind.complete] a task
/// or reminder, [WidgetActionKind.checkIn] a habit (one more check-in),
/// [WidgetActionKind.take] a dose. It runs in the background isolate with the
/// same [NotificationActions] the notification buttons use, so a widget tap
/// and a notification tap can never disagree; then pushes a fresh snapshot
/// (the widget showed the change optimistically) and pings the running app,
/// whose Drift streams cannot see this isolate's writes.
/// Why not open the app: the point of a widget is to finish a thing without
/// leaving the home screen.
/// ============================================================
library;

import 'package:focusflow/core/home_widgets/home_widget_sync.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/engine/refresh_port.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

enum WidgetActionKind {
  complete('complete'),
  checkIn('checkin'),
  take('take');

  const WidgetActionKind(this.wire);

  /// The string the native side sends.
  final String wire;

  static WidgetActionKind? fromWire(Object? v) {
    for (final k in values) {
      if (k.wire == v) return k;
    }
    return null;
  }
}

/// Performs the action described by [input] (`action`, `kind` = item type
/// name, `id`, and for a dose `day` + `min`). True when something changed.
/// Never throws.
Future<bool> runWidgetAction(
  WidgetReader read,
  Map<String, Object?> input,
) async {
  var changed = false;
  try {
    final action = WidgetActionKind.fromWire(input['action']);
    final id = input['id'];
    if (action == null || id is! String || id.isEmpty) return false;
    final actions = read(notificationActionsProvider);
    switch (action) {
      case WidgetActionKind.complete:
        final type = input['kind'] == ItemType.reminder.name
            ? ItemType.reminder
            : ItemType.task;
        changed = await actions.markDone(ItemRef(type, id));
      case WidgetActionKind.checkIn:
        changed = await actions.checkIn(ItemRef(ItemType.habit, id));
      case WidgetActionKind.take:
        final day = _day(input['day']);
        final minutes = input['min'];
        if (day == null || minutes is! int) return false;
        final meds = read(medicinesRepositoryProvider);
        final m = await meds.getMedicine(id);
        if (m == null || !m.isActive) return false;
        await meds.markTaken(id, day, minutes);
        changed = true;
    }
  } on Object catch (e) {
    AppLogger.w('Widget action failed (${e.runtimeType})');
  }
  // Even when nothing changed the widget may be showing a stale optimistic
  // state: a fresh snapshot puts it right.
  await pushWidgetSnapshot(read);
  if (changed) NotificationRefreshPort.ping();
  return changed;
}

DateTime? _day(Object? key) {
  if (key is! String) return null;
  try {
    return DateUtilsX.parseDayKey(key);
  } on Object {
    return null;
  }
}

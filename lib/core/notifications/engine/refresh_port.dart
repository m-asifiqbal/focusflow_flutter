/// ============================================================
/// NOTIFICATION REFRESH PORT — background isolate → running app
/// ============================================================
///
/// What: a named [SendPort] the running app registers; a background
/// isolate (notification action, 12 h maintenance task) pings it after
/// writing to the database.
///
/// Why: Done / Snooze / Check in run on a background isolate without
/// bringing the app forward (Android `showsUserInterface: false`). Drift
/// streams of the app's isolate never see that isolate's writes, so the
/// lists would stay stale while the app is visible (e.g. the notification
/// shade pulled over it — no resume). On a ping the engine marks the
/// tables updated and re-plans, exactly as it does on resume. When the app
/// is not running nobody is registered and the ping is a no-op.
/// ============================================================
library;

import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

abstract final class NotificationRefreshPort {
  static const String name = 'focusflow.notifications.refresh';

  /// Registers this isolate as the receiver (replacing a stale mapping).
  static ReceivePort listen(void Function() onPing) {
    IsolateNameServer.removePortNameMapping(name);
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, name);
    port.listen((_) => onPing());
    return port;
  }

  /// Unregisters [port] (only if it is still the registered one).
  static void close(ReceivePort port) {
    final current = IsolateNameServer.lookupPortByName(name);
    if (current == port.sendPort) {
      IsolateNameServer.removePortNameMapping(name);
    }
    port.close();
  }

  /// Tells the running app (if any) that the database changed.
  static void ping() {
    try {
      IsolateNameServer.lookupPortByName(name)?.send(1);
    } catch (_) {
      // Best effort: the app also refreshes on resume.
    }
  }
}

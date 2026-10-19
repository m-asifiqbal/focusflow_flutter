/// ============================================================
/// REARM POLICY — when a launch must renew every alarm, and when it may not
/// ============================================================
///
/// Why: the first pass of a process renews the alarms the OS holds, because
/// Android drops them all when the app is force-stopped. Doing that blindly
/// at every launch re-sends every planned request (up to 240) to
/// flutter_local_notifications, which rewrites its whole stored list on the
/// platform thread for each one — N × N work while the user is already
/// scrolling. A launch now asks the OS which alarms are still armed
/// (`NotificationGateway.armedIds`) and renews only the others; after a
/// force-stop that is all of them, so nothing is lost.
///
/// As a belt-and-braces measure a *full* renewal (every request, no questions
/// asked) still happens whenever the last one is [fullEvery] old, and always
/// in the background maintenance task, where nobody is watching the frames.
/// ============================================================
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract final class RearmPolicy {
  /// Preference: epoch milliseconds of the last full renewal.
  static const String lastFullKey = 'notifications.last_full_rearm';

  /// How long a launch may trust the OS' answer before renewing everything.
  static const Duration fullEvery = Duration(hours: 24);

  /// A launch at [now] renews every request (no verification) when there has
  /// never been a full renewal, the last one is [fullEvery] old, or the clock
  /// went back past it.
  static bool fullDue(SharedPreferences prefs, DateTime now) {
    final ms = prefs.getInt(lastFullKey);
    if (ms == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(ms);
    return now.isBefore(last) || now.difference(last) >= fullEvery;
  }

  /// Records a full renewal at [now].
  static Future<void> markFull(SharedPreferences prefs, DateTime now) =>
      prefs.setInt(lastFullKey, now.millisecondsSinceEpoch);
}

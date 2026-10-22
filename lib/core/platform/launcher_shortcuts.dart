/// ============================================================
/// LAUNCHER SHORTCUTS — the quick actions of the app icon's long press
/// ============================================================
///
/// What: Notifications · New note · New reminder · Habit tracker, offered by
/// the launcher when the app icon is long-pressed (Android static shortcuts
/// in `res/xml/shortcuts.xml`; iOS Home Screen quick actions in Info.plist).
/// This file maps a shortcut to its route and owns the tiny platform channel
/// `focusflow/shortcuts` the native side uses to hand a tapped shortcut over:
/// `getInitial` (the one that cold-started the app, consumed once) and, while
/// running, a native `onShortcut` call.
/// Why: a channel instead of a quick-actions plugin — no new dependency, the
/// shortcut list is static (declared natively), and the same Dart code serves
/// both platforms. The keys below are the contract with
/// `android/.../MainActivity.kt`, `shortcuts.xml` and `ios/Runner/Info.plist`.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/open_location.dart';
import 'package:go_router/go_router.dart';

enum LauncherShortcut {
  notifications('notifications', AppRoutes.notificationCenter),
  newNote('new_note', AppRoutes.newNote),
  newReminder('new_reminder', AppRoutes.newReminderPath),
  habits('habits', AppRoutes.habits);

  const LauncherShortcut(this.key, this.route);

  /// Stable id shared with the native shortcut definitions.
  final String key;

  /// Where it goes.
  final String route;

  static LauncherShortcut? fromKey(String? key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// Opens [shortcut] on top of whatever the app is showing: editors and the
/// notification centre are pushed (back returns to where the user was), the
/// habit tracker follows [openLocationOn] (a tab page). Does nothing when
/// that exact page is already the current one.
void openLauncherShortcut(GoRouter router, LauncherShortcut shortcut) {
  if (router.state.uri.toString() == shortcut.route) return;
  openLocationOn(router, shortcut.route);
}

class LauncherShortcuts {
  const LauncherShortcuts([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'focusflow/shortcuts';

  final MethodChannel _channel;

  /// The shortcut that launched the app (null when it was started normally
  /// or the platform has none); returned once.
  Future<LauncherShortcut?> initial() async {
    try {
      return LauncherShortcut.fromKey(
        await _channel.invokeMethod<String>('getInitial'),
      );
    } on MissingPluginException {
      return null; // tests, desktop
    } on PlatformException {
      return null;
    }
  }

  /// Calls [onShortcut] for every shortcut tapped while the app is running.
  void listen(void Function(LauncherShortcut shortcut) onShortcut) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onShortcut') return;
      final s = LauncherShortcut.fromKey(call.arguments as String?);
      if (s != null) onShortcut(s);
    });
  }

  void stopListening() => _channel.setMethodCallHandler(null);
}

final launcherShortcutsProvider = Provider<LauncherShortcuts>(
  (ref) => const LauncherShortcuts(),
);

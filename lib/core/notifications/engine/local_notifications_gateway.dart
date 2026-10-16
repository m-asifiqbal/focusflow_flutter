/// ============================================================
/// LOCAL NOTIFICATIONS GATEWAY — flutter_local_notifications adapter
/// ============================================================
///
/// The only file that talks to flutter_local_notifications:
///   • Android channels (reminders, alarms full-screen, tasks, habits,
///     digests, security & sync) and iOS categories with Done / Snooze /
///     Check in buttons.
///   • Exact alarms when the OS allows them, inexact otherwise (the
///     reconciler passes the mode in [DeliveryOptions.exact] and keeps it in
///     the ledger fingerprint); alarm-style reminders use the alarm clock
///     mode + full-screen intent. Android 14+ may deny full-screen intents
///     ([canUseFullScreenIntent], asked when alarm-style is switched on):
///     the alarm then shows as a max-priority heads-up notification.
///   • iOS alarm-style = `InterruptionLevel.timeSensitive`. Breaking through
///     Focus needs the `com.apple.developer.usernotifications.time-sensitive`
///     entitlement, a capability that must be enabled on the App ID and in
///     the provisioning profile — so it is NOT added to Runner (it would
///     break builds signed without that profile). Without it iOS delivers
///     the notification at the normal (active) level. To enable: add the
///     capability in Xcode › Signing & Capabilities.
///   • Lock-screen visibility from Settings:
///       full       → Android public; iOS: everything (iOS's own "Show
///                    Previews" setting may still hide the body),
///       title only → Android private (the system shows the app name and
///                    "Contents hidden" while locked — the plugin has no
///                    public version, so the title cannot be kept); iOS
///                    categories carry `hiddenPreviewShowTitle`, so the
///                    title stays when iOS hides previews,
///       hidden     → a generic "Reminder" / "Open FocusFlow" text on both
///                    platforms (+ Android secret: nothing while locked).
///   • Sound: reminders set to "Silent" use the silent Android channel and
///     no iOS sound. (Custom tones need bundled sound files — not shipped.)
///   • Badge: Android launchers count notifications (`number`); iOS badge
///     is set per notification (`badgeNumber`) and, while the app is in the
///     foreground, immediately via a silent request.
///   • Taps and action buttons → [NotificationTap]. Done / Snooze / Check in
///     run without opening the app ([notificationBackgroundHandler], a
///     background isolate, which then pings the running app to refresh —
///     see `NotificationRefreshPort`); "Open" brings the app forward.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/notifications/engine/background_handler.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationsGateway implements NotificationGateway {
  LocalNotificationsGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  bool? _exactAllowed;
  int? _lastBadge;

  /// Reserved id of the silent iOS badge request (never planned: the
  /// planner and RemindersDao skip [reservedNotificationId]).
  static const int _badgeId = reservedNotificationId;

  /// Native helpers in MainActivity.kt (full-screen intent permission).
  static const MethodChannel _native = MethodChannel('focusflow/notifications');

  static const String _androidIcon = '@mipmap/ic_launcher';

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Settings shared by the app and the background isolate.
  static InitializationSettings get initializationSettings =>
      InitializationSettings(
        android: const AndroidInitializationSettings(_androidIcon),
        iOS: DarwinInitializationSettings(
          // Asked explicitly (onboarding / settings), never at start-up.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [for (final c in _categories) c],
        ),
      );

  /// Every category keeps the title on the lock screen when iOS hides
  /// previews ("Title only"); button-less notifications use `ff.`.
  static List<DarwinNotificationCategory> get _categories => [
    for (final buttons in const [
      <NotificationButton>[],
      [NotificationButton.done, NotificationButton.snooze],
      [
        NotificationButton.done,
        NotificationButton.snooze,
        NotificationButton.open,
      ],
      [NotificationButton.checkIn],
    ])
      DarwinNotificationCategory(
        _iosCategory(buttons),
        actions: [
          for (final b in buttons)
            DarwinNotificationAction.plain(
              b.id,
              _label(b),
              options: b.showsUserInterface
                  ? const {DarwinNotificationActionOption.foreground}
                  : const <DarwinNotificationActionOption>{},
            ),
        ],
        options: const {
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
  ];

  static String _iosCategory(List<NotificationButton> buttons) =>
      'ff.${buttons.map((b) => b.id).join('_')}';

  /// Generic text of every notification while "Show on lock screen" is
  /// Hidden (the inbox keeps the real one, behind the app lock).
  static const String hiddenTitle = 'Reminder';
  static const String hiddenBody = 'Open ${AppInfo.name}';

  /// (title, body) the OS shows for [n].
  static (String, String?) _text(PlannedNotification n, DeliveryOptions o) =>
      o.lockScreen == LockScreenVisibility.hidden
      ? (hiddenTitle, hiddenBody)
      : (n.title, n.body.isEmpty ? null : n.body);

  @override
  Future<bool> initialize({
    required void Function(NotificationTap) onTap,
  }) async {
    if (!_isAndroid && !_isIOS) return false;
    final ok = await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (r) =>
          onTap(NotificationTap(payload: r.payload, actionId: r.actionId)),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    final android = _android;
    if (android != null) {
      for (final c in NotificationChannelId.values) {
        await android.createNotificationChannel(_channel(c));
      }
    }
    _ready = ok ?? false;
    _exactAllowed = null;
    return _ready;
  }

  /// Initialization for the background isolate (no tap callback).
  Future<void> initializeInBackground() async {
    await _plugin.initialize(settings: initializationSettings);
    _ready = true;
  }

  static AndroidNotificationChannel _channel(NotificationChannelId c) =>
      AndroidNotificationChannel(
        c.id,
        c.label,
        description: c.description,
        importance: switch (c) {
          NotificationChannelId.alarms => Importance.max,
          NotificationChannelId.digests => Importance.defaultImportance,
          _ => Importance.high,
        },
        playSound: c != NotificationChannelId.silentReminders,
      );

  @override
  Future<NotificationTap?> launchTap() async {
    if (!_ready) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d == null || !d.didNotificationLaunchApp || r == null) return null;
    return NotificationTap(payload: r.payload, actionId: r.actionId);
  }

  @override
  Future<Set<int>> pendingIds() async {
    if (!_ready) return {};
    final list = await _plugin.pendingNotificationRequests();
    return {for (final p in list) p.id}..remove(_badgeId);
  }

  @override
  Future<void> schedule(
    PlannedNotification n,
    tz.Location location,
    DeliveryOptions options,
  ) async {
    if (!_ready) return;
    final when = tz.TZDateTime.from(n.fireAt, location);
    final (title, body) = _text(n, options);
    await _plugin.zonedSchedule(
      id: n.id,
      scheduledDate: when,
      title: title,
      body: body,
      payload: n.payload.encode(),
      notificationDetails: _details(n, options),
      androidScheduleMode: await _mode(n, options),
    );
  }

  @override
  Future<void> showNow(PlannedNotification n, DeliveryOptions options) async {
    if (!_ready) return;
    final (title, body) = _text(n, options);
    await _plugin.show(
      id: n.id,
      title: title,
      body: body,
      payload: n.payload.encode(),
      notificationDetails: _details(n, options),
    );
  }

  Future<AndroidScheduleMode> _mode(
    PlannedNotification n,
    DeliveryOptions options,
  ) async {
    if (!_isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    if (!options.exact) return AndroidScheduleMode.inexactAllowWhileIdle;
    // Defensive: an exact request without the grant throws on Android 12+.
    _exactAllowed ??= await _android?.canScheduleExactNotifications() ?? false;
    if (_exactAllowed != true) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return n.category == NotificationCategory.alarm
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;
  }

  static NotificationDetails _details(
    PlannedNotification n,
    DeliveryOptions o,
  ) {
    final c = n.isSilent
        ? NotificationChannelId.silentReminders
        : n.category.channel;
    final alarm = n.category == NotificationCategory.alarm;
    final (_, body) = _text(n, o);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        c.id,
        c.label,
        channelDescription: c.description,
        importance: alarm ? Importance.max : Importance.high,
        priority: alarm ? Priority.max : Priority.high,
        category: alarm
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        fullScreenIntent: alarm,
        visibility: switch (o.lockScreen) {
          LockScreenVisibility.full => NotificationVisibility.public,
          LockScreenVisibility.titleOnly => NotificationVisibility.private,
          LockScreenVisibility.hidden => NotificationVisibility.secret,
        },
        playSound: !n.isSilent,
        styleInformation: body != null && body.length > 40
            ? BigTextStyleInformation(body)
            : null,
        number: n.badge,
        actions: [
          for (final b in n.buttons)
            AndroidNotificationAction(
              b.id,
              _label(b),
              showsUserInterface: b.showsUserInterface,
            ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: _iosCategory(n.buttons),
        presentSound: n.isSilent ? false : null,
        badgeNumber: n.badge,
        threadIdentifier: c.id,
        interruptionLevel: alarm
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
  }

  static String _label(NotificationButton b) => switch (b) {
    NotificationButton.done => 'Done',
    NotificationButton.snooze => 'Snooze',
    NotificationButton.checkIn => 'Check in',
    NotificationButton.open => 'Open',
  };

  @override
  Future<void> cancel(int id) async {
    if (_ready) await _plugin.cancel(id: id);
  }

  @override
  Future<void> setBadge(int count) async {
    // Android launchers derive the badge from posted notifications.
    if (!_ready || !_isIOS) return;
    // Only in the foreground: a background request would be shown.
    AppLifecycleState? state;
    try {
      state = WidgetsBinding.instance.lifecycleState;
    } catch (_) {
      return; // background isolate: no binding, never in the foreground
    }
    if (state != AppLifecycleState.resumed || _lastBadge == count) return;
    _lastBadge = count;
    try {
      await _plugin.show(
        id: _badgeId,
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBanner: false,
            presentList: false,
            presentSound: false,
            presentBadge: true,
            badgeNumber: count,
          ),
        ),
      );
      await _plugin.cancel(id: _badgeId);
    } catch (e) {
      AppLogger.w('Badge update failed: $e');
    }
  }

  @override
  Future<NotificationPermission> permission({required bool askedBefore}) async {
    if (!_ready) return NotificationPermission.notDetermined;
    bool? enabled;
    if (_isAndroid) {
      enabled = await _android?.areNotificationsEnabled();
      _exactAllowed = null; // re-check after a trip to system settings
    } else if (_isIOS) {
      enabled = (await _ios?.checkPermissions())?.isEnabled;
    }
    if (enabled == true) return NotificationPermission.granted;
    return askedBefore
        ? NotificationPermission.denied
        : NotificationPermission.notDetermined;
  }

  @override
  Future<NotificationPermission> requestPermission({
    bool exactAlarms = true,
  }) async {
    if (!_ready) return NotificationPermission.notDetermined;
    bool? granted;
    if (_isAndroid) {
      granted = await _android?.requestNotificationsPermission();
      if (granted == true && exactAlarms) {
        final can = await _android?.canScheduleExactNotifications();
        if (can == false) await _android?.requestExactAlarmsPermission();
        _exactAllowed = null;
      }
    } else if (_isIOS) {
      granted = await _ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return granted == true
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  @override
  Future<void> openSettings() async {
    if (!_ready) return;
    if (_isAndroid) {
      await _android?.openAppNotificationSettings();
    } else if (_isIOS) {
      await _ios?.openAppNotificationSettings();
    }
  }

  @override
  Future<ExactAlarmPermission> exactAlarmPermission() async {
    if (!_ready || !_isAndroid) return ExactAlarmPermission.notApplicable;
    // Always asked fresh: the user may have flipped it in system settings.
    final can = await _android?.canScheduleExactNotifications();
    _exactAllowed = can;
    if (can == null) return ExactAlarmPermission.notApplicable;
    return can ? ExactAlarmPermission.granted : ExactAlarmPermission.denied;
  }

  @override
  Future<ExactAlarmPermission> requestExactAlarms() async {
    if (!_ready || !_isAndroid) return ExactAlarmPermission.notApplicable;
    if (await exactAlarmPermission() == ExactAlarmPermission.denied) {
      await _android?.requestExactAlarmsPermission();
    }
    return exactAlarmPermission();
  }

  @override
  Future<bool> canUseFullScreenIntent() async {
    if (!_isAndroid) return true;
    try {
      return await _native.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<bool> requestFullScreenIntent() async {
    if (!_ready || !_isAndroid) return true;
    if (await canUseFullScreenIntent()) return true;
    final granted = await _android?.requestFullScreenIntentPermission();
    return granted ?? await canUseFullScreenIntent();
  }

  @override
  Future<String?> deviceTimeZone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (e) {
      AppLogger.w('Device time zone unavailable: $e');
      return null;
    }
  }
}

/// ============================================================
/// APP ROUTES — every path in one place (master prompt §6 Navigation map)
/// ============================================================
///
/// Tabs (StatefulShellRoute, tab bar visible):
///   /home · /library (+ module lists under it) · /insights · /settings (+ sub-pages)
/// Full-screen (root navigator, no tab bar): editors, details, search,
///   calendar, notification centre, onboarding, sign-in.
///
/// New-item routes take optional query parameters (see [AppRoutes.newTask]
/// etc.) so Quick Add / Calendar / quick capture can prefill editors.
///
/// Usage: `context.push(AppRoutes.note(id))`, `context.go(AppRoutes.home)`.
/// ============================================================
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';

abstract final class AppRoutes {
  // ── Launch ──
  static const splash = '/splash';
  static const onboarding = '/onboarding';

  /// `?intent=restore` → after Google login go straight to the restore picker.
  static const signIn = '/sign-in';
  static const signInRestore = '/sign-in?intent=restore';

  // ── Tab roots ──
  static const home = '/home';
  static const library = '/library';
  static const insights = '/insights';
  static const settings = '/settings';

  // ── Library branch (tab bar stays visible) ──
  static const notes = '/library/notes';
  static const tasks = '/library/tasks';
  static const reminders = '/library/reminders';
  static const habits = '/library/habits';

  /// Vault gate → list with inner tabs (Vault · Generator · Favourites · Security).
  static const vault = '/library/vault';
  static const archive = '/library/archive';
  static const trash = '/library/trash';
  static const pinned = '/library/pinned';
  static const favourites = '/library/favourites';
  static const tags = '/library/tags';
  static String tag(String tagId) => '/library/tags/$tagId';

  // ── Full-screen ──
  static const search = '/search';
  static const calendar = '/calendar';

  /// `/calendar?date=yyyy-MM-dd` — the calendar opened on [day].
  static String calendarOn(DateTime day) =>
      _withQuery(calendar, {'date': DateUtilsX.dayKey(day)});

  static const notificationCenter = '/notifications';

  static const newNote = '/notes/new';
  static String note(String id) => '/notes/$id';

  static const newTaskPath = '/tasks/new';
  static String task(String id) => '/tasks/$id';

  static const newReminderPath = '/reminders/new';
  static String reminder(String id) => '/reminders/$id';

  static const newHabitPath = '/habits/new';
  static String habit(String id) => '/habits/$id';
  static String habitEdit(String id) => '/habits/$id/edit';

  static const newVaultItemPath = '/vault/new';
  static String vaultItem(String id) => '/vault/item/$id';
  static String vaultItemEdit(String id) => '/vault/item/$id/edit';

  // ── Settings branch ──
  static const settingsNotifications = '/settings/notifications';
  static const settingsAppearance = '/settings/appearance';
  static const settingsVaultSecurity = '/settings/vault-security';
  static const settingsBackup = '/settings/backup';
  static const settingsBackupRestore = '/settings/backup/restore';
  static const settingsImportExport = '/settings/import-export';
  static const settingsAccount = '/settings/account';
  static const settingsGeneral = '/settings/general';
  static const settingsHomeLayout = '/settings/home-layout';
  static const settingsGestures = '/settings/gestures';
  static const settingsSoundsHaptics = '/settings/sounds-haptics';
  static const settingsAppLock = '/settings/app-lock';
  static const settingsTagsFolders = '/settings/tags-folders';
  static const settingsStorage = '/settings/storage';
  static const settingsAbout = '/settings/about';

  /// Per-module defaults: notes · tasks · reminders · habits.
  static String settingsModule(String module) => '/settings/modules/$module';

  // ── Deep links (notification taps: focusflow://item/{type}/{id}) ──
  static String item(ItemRef ref) => '/item/${ref.type.key}/${ref.id}';

  /// Where an item opens (editor or detail) — used by search, calendar,
  /// archive, notification centre, pinned/favourites lists.
  static String open(ItemRef ref) => switch (ref.type) {
    ItemType.note => note(ref.id),
    ItemType.task => task(ref.id),
    ItemType.reminder => reminder(ref.id),
    ItemType.habit => habit(ref.id),
    ItemType.vault => vaultItem(ref.id),
  };

  /// `/notes/new?text=…&folderId=…`
  static String newNoteWith({String? text, String? folderId, String? tag}) =>
      _withQuery(newNote, {'text': text, 'folderId': folderId, 'tag': tag});

  /// `/tasks/new?title=…&date=yyyy-MM-dd&time=540&priority=3&tag=home`
  static String newTask({
    String? title,
    String? date,
    int? timeMinutes,
    int? priority,
    String? tag,
    String? repeatRule,
  }) => _withQuery(newTaskPath, {
    'title': title,
    'date': date,
    'time': timeMinutes?.toString(),
    'priority': priority?.toString(),
    'tag': tag,
    'rrule': repeatRule,
  });

  /// `/reminders/new?title=…&at=<iso8601>&rrule=…&linkType=task&linkId=…`
  static String newReminder({
    String? title,
    DateTime? at,
    String? repeatRule,
    ItemRef? link,
  }) => _withQuery(newReminderPath, {
    'title': title,
    'at': at?.toIso8601String(),
    'rrule': repeatRule,
    'linkType': link?.type.key,
    'linkId': link?.id,
  });

  /// `/habits/new?name=…`
  static String newHabit({String? name}) =>
      _withQuery(newHabitPath, {'name': name});

  /// `/vault/new?password=…` is NOT allowed (secrets never go in URLs);
  /// the generator hands values back via `context.pop(value)` instead.
  static String newVaultItem({String? type}) =>
      _withQuery(newVaultItemPath, {'type': type});

  static String _withQuery(String path, Map<String, String?> params) {
    final q = {
      for (final e in params.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    if (q.isEmpty) return path;
    return Uri(path: path, queryParameters: q).toString();
  }
}

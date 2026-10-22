/// ============================================================
/// SETTINGS INDEX — every searchable setting, with its deep link
/// ============================================================
///
/// What: the list behind "Search settings…" (screen 30): the root
/// rows plus the rows of every sub-page (31–36, general, app lock, modules,
/// home layout, gestures, sounds, tags & folders, storage, about), each
/// deep-linked to its page (settings_index_test.dart probes them).
/// Why: a sub-page's rows are not built until it is opened, so search
/// can't scan widgets; one table here is the single source of truth.
/// Add a row here when you add one to a settings page.
/// The list is built on every read ([all] is a getter, not a field) so the
/// titles and pages follow the active language; the keywords stay English
/// synonyms.
/// ============================================================
library;

import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';

abstract final class SettingsIndex {
  static String get _root => tr('Settings');
  static String get _notif => tr('Notifications & Reminders');
  static String get _appear => tr('Appearance');
  static String get _vault => tr('Vault security');
  static String get _backup => tr('Backup & Sync');
  static String get _io => tr('Import & Export');
  static String get _account => tr('Account');

  static List<SettingsEntry> get all => [
    // ── Root ──
    SettingsEntry(
      title: tr('Account'),
      page: _root,
      keywords: ['profile', 'name', 'google', 'email', 'sign in'],
      route: AppRoutes.settingsAccount,
    ),
    SettingsEntry(
      title: tr('Language'),
      page: tr('General'),
      keywords: ['english', 'locale'],
      action: SettingsRootAction.language,
    ),
    SettingsEntry(
      title: tr('Start screen'),
      page: tr('General'),
      keywords: ['launch', 'open', 'home', 'default tab'],
      action: SettingsRootAction.startScreen,
    ),
    SettingsEntry(
      title: tr('Week starts on'),
      page: tr('General'),
      keywords: ['monday', 'sunday', 'saturday', 'calendar'],
      action: SettingsRootAction.weekStart,
    ),
    SettingsEntry(
      title: tr('Date & time format'),
      page: tr('General'),
      keywords: ['24-hour', '12-hour', 'clock', 'time'],
      route: AppRoutes.settingsGeneral,
    ),
    SettingsEntry(
      title: tr('Pinned items'),
      page: tr('Preferences'),
      keywords: ['pin', 'favourites'],
      route: AppRoutes.pinned,
    ),
    SettingsEntry(
      title: tr('Home layout & widgets'),
      page: tr('Preferences'),
      keywords: ['sections', 'reorder', 'dashboard'],
      route: AppRoutes.settingsHomeLayout,
    ),
    SettingsEntry(
      title: tr('Gestures & swipe actions'),
      page: tr('Preferences'),
      keywords: ['swipe left', 'swipe right', 'archive', 'complete'],
      route: AppRoutes.settingsGestures,
    ),
    SettingsEntry(
      title: tr('Sounds & haptics'),
      page: tr('Preferences'),
      keywords: ['vibration', 'audio', 'feedback'],
      route: AppRoutes.settingsSoundsHaptics,
    ),
    SettingsEntry(
      title: tr('Notes defaults'),
      page: tr('Modules'),
      keywords: const ['grid', 'list', 'sort', 'colour', 'color'],
      route: AppRoutes.settingsModule('notes'),
    ),
    SettingsEntry(
      title: tr('Tasks defaults'),
      page: tr('Modules'),
      keywords: const ['smart lists', 'show completed', 'default list'],
      route: AppRoutes.settingsModule('tasks'),
    ),
    SettingsEntry(
      title: tr('Reminders defaults'),
      page: tr('Modules'),
      keywords: const ['snooze', 'sound', 'tone'],
      route: AppRoutes.settingsModule('reminders'),
    ),
    SettingsEntry(
      title: tr('Habits defaults'),
      page: tr('Modules'),
      keywords: const ['reset time', 'day starts', 'streak'],
      route: AppRoutes.settingsModule('habits'),
    ),
    SettingsEntry(
      title: tr('Tags & folders'),
      page: tr('Modules'),
      keywords: ['labels', 'organise', 'organize'],
      route: AppRoutes.settingsTagsFolders,
    ),
    SettingsEntry(
      title: tr('App lock'),
      page: tr('Security & privacy'),
      keywords: ['pin', 'passcode', 'face id', 'fingerprint', 'biometric'],
      route: AppRoutes.settingsAppLock,
    ),
    SettingsEntry(
      title: tr('Hide content in app switcher'),
      page: tr('Security & privacy'),
      keywords: ['privacy', 'recents', 'multitasking', 'blur'],
      action: SettingsRootAction.hideInSwitcher,
    ),
    SettingsEntry(
      title: tr('Clear clipboard after'),
      page: tr('Security & privacy'),
      keywords: ['copy', 'paste', 'password'],
      // A vault security setting: changed only on Vault security, which
      // asks for the PIN / biometrics first.
      route: AppRoutes.settingsVaultSecurity,
    ),
    SettingsEntry(
      title: tr('Storage'),
      page: tr('Data & sync'),
      keywords: ['space', 'cache', 'size', 'megabytes'],
      route: AppRoutes.settingsStorage,
    ),
    SettingsEntry(
      title: tr('Archive'),
      page: tr('Data & sync'),
      keywords: ['archived'],
      route: AppRoutes.archive,
    ),
    SettingsEntry(
      title: tr('Recently deleted'),
      page: tr('Data & sync'),
      keywords: ['trash', 'bin', 'restore', 'deleted'],
      route: AppRoutes.trash,
    ),
    SettingsEntry(
      title: tr('Help & Support'),
      page: tr('Support'),
      keywords: ['contact', 'faq', 'email'],
      action: SettingsRootAction.help,
    ),
    SettingsEntry(
      title: tr('Send feedback'),
      page: tr('Support'),
      keywords: ['bug', 'idea', 'suggestion'],
      action: SettingsRootAction.feedback,
    ),
    SettingsEntry(
      title: tr('Rate {name}', {'name': AppInfo.name}),
      page: tr('Support'),
      keywords: ['review', 'store', 'stars'],
      action: SettingsRootAction.rate,
    ),
    SettingsEntry(
      title: tr('About'),
      page: tr('Support'),
      keywords: ['version', 'licenses', 'licences', 'privacy policy', 'terms'],
      route: AppRoutes.settingsAbout,
    ),
    // ── Notifications (31) ──
    for (final (title, keywords) in [
      (tr('Notifications & Reminders'), ['alerts', 'push']),
      (tr('Allow notifications'), ['permission', 'alerts']),
      (tr('Morning briefing'), ['digest', 'daily summary']),
      (tr('Evening review'), ['digest', 'night']),
      (tr('Weekly report'), ['summary', 'stats']),
      (tr('Streak at risk'), ['habits', 'reminder']),
      (tr('Quiet hours'), ['do not disturb', 'silence', 'night']),
      (tr('Default snooze'), ['later', 'minutes']),
      (
        tr('Keep alarms running'),
        ['background service', 'swipe away', 'app closed', 'alarm not ringing'],
      ),
      (tr('Lock screen'), ['preview', 'privacy', 'title only']),
      (tr('App badge'), ['count', 'icon', 'overdue']),
    ])
      SettingsEntry(
        title: title,
        page: _notif,
        keywords: keywords,
        route: AppRoutes.settingsNotifications,
      ),
    // ── Appearance (32) ──
    for (final (title, keywords) in [
      (tr('Appearance'), ['look', 'style']),
      (tr('Theme'), ['dark mode', 'light mode', 'system', 'night']),
      (tr('Accent colour'), ['color', 'tint', 'primary']),
      (tr('Text size'), ['font size', 'bigger', 'smaller', 'accessibility']),
      (tr('App icon'), ['home screen icon']),
      (tr('Notes default view'), ['grid', 'list']),
      (tr('List density'), ['compact', 'comfortable', 'spacing']),
      (tr('Reduce motion'), ['animations', 'accessibility']),
      (tr('Visual effects'), ['performance', 'lag', 'slow', 'blur', 'low end']),
      (tr('Use system font'), ['typeface', 'font']),
    ])
      SettingsEntry(
        title: title,
        page: _appear,
        keywords: keywords,
        route: AppRoutes.settingsAppearance,
      ),
    // ── Vault security (33) ──
    for (final (title, keywords) in [
      (tr('Vault security'), ['passwords', 'vault']),
      (tr('Change vault PIN'), ['passcode', 'password']),
      (tr('Unlock with biometrics'), ['face id', 'fingerprint', 'touch id']),
      (tr('Auto-lock'), ['timeout', 'minutes']),
      (tr('Lock when leaving the app'), ['background']),
      (tr('Block screenshots'), ['screen recording', 'privacy']),
      (tr('Re-authenticate to reveal'), ['show password']),
      (tr('Breach monitoring'), ['pwned', 'leaked', 'hibp']),
      (tr('Erase after failed attempts'), ['wipe', 'self-destruct']),
    ])
      SettingsEntry(
        title: title,
        page: _vault,
        keywords: keywords,
        route: AppRoutes.settingsVaultSecurity,
      ),
    // ── Backup & Sync (34) ──
    for (final (title, keywords) in [
      (tr('Backup & Sync'), ['google drive', 'cloud']),
      (tr('Back up now'), ['sync now', 'drive']),
      (tr('Auto backup to Google Drive'), ['automatic', 'cloud']),
      (tr('Backup frequency'), ['daily', 'weekly']),
      (tr('Sync when app opens'), ['auto sync', 'launch', 'other devices']),
      (tr('Back up on Wi-Fi only'), ['cellular', 'mobile data']),
      (tr('Encrypt backups'), ['password', 'security']),
      (tr('Local backups'), ['device', 'offline']),
    ])
      SettingsEntry(
        title: title,
        page: _backup,
        keywords: keywords,
        route: AppRoutes.settingsBackup,
      ),
    SettingsEntry(
      title: tr('Restore from backup'),
      page: _backup,
      keywords: ['recover', 'import backup'],
      route: AppRoutes.settingsBackupRestore,
    ),
    // ── Import & Export (35) ──
    for (final (title, keywords) in [
      (tr('Import & Export'), ['transfer', 'move data']),
      (tr('Import from file'), ['evernote', 'csv', 'markdown', 'json']),
      (tr('Export all data'), ['download', 'json', 'markdown', 'csv']),
    ])
      SettingsEntry(
        title: title,
        page: _io,
        keywords: keywords,
        route: AppRoutes.settingsImportExport,
      ),
    // ── Account (36) ──
    for (final (title, keywords) in [
      (tr('Display name'), ['profile', 'name']),
      (tr('Daily focus goal'), ['tasks per day', 'target']),
      (tr('Time zone'), ['timezone', 'travel']),
      (tr('Linked devices'), ['phones', 'tablets']),
      (tr('Erase local data'), ['reset', 'factory']),
      (tr('Delete account & Drive data'), ['remove account']),
    ])
      SettingsEntry(
        title: title,
        page: _account,
        keywords: keywords,
        route: AppRoutes.settingsAccount,
      ),
    // ── Sub-pages without a mockup: one entry per row ──
    for (final (title, page, keywords, route) in _subPageRows)
      SettingsEntry(title: title, page: page, keywords: keywords, route: route),
    for (final (title, keywords) in [
      (tr('Default view'), ['grid', 'list', 'notes']),
      (tr('Sort by'), ['order', 'notes', 'edited', 'created']),
      (tr('Colour of new notes'), ['color', 'notes', 'background']),
    ])
      SettingsEntry(
        title: title,
        page: tr('Notes defaults'),
        keywords: keywords,
        route: AppRoutes.settingsModule('notes'),
      ),
    for (final (title, keywords) in [
      (tr('Smart lists'), ['today', 'upcoming', 'overdue', 'tasks']),
      (tr('Show completed'), ['done', 'finished', 'tasks']),
      (tr('Default list'), ['new tasks', 'folder', 'tasks']),
    ])
      SettingsEntry(
        title: title,
        page: tr('Tasks defaults'),
        keywords: keywords,
        route: AppRoutes.settingsModule('tasks'),
      ),
    for (final (title, keywords) in [
      (tr('Reminder sound'), ['tone', 'ringtone', 'alert']),
    ])
      SettingsEntry(
        title: title,
        page: tr('Reminders defaults'),
        keywords: keywords,
        route: AppRoutes.settingsModule('reminders'),
      ),
    for (final (title, keywords) in [
      (tr('Day resets at'), ['midnight', 'reset time', 'habits']),
    ])
      SettingsEntry(
        title: title,
        page: tr('Habits defaults'),
        keywords: keywords,
        route: AppRoutes.settingsModule('habits'),
      ),
  ];

  /// (title, page, keywords, route) of the rows on General, Home layout,
  /// Gestures, Sounds & haptics, App lock, Tags & folders, Storage, About.
  static List<(String, String, List<String>, String)> get _subPageRows => [
    (
      tr('Date format'),
      tr('General'),
      ['day', 'month', 'year', 'pattern', 'dd/mm'],
      AppRoutes.settingsGeneral,
    ),
    (
      tr('Time format'),
      tr('General'),
      ['24-hour', '12-hour', 'clock'],
      AppRoutes.settingsGeneral,
    ),
    (
      tr('Reset settings'),
      tr('General'),
      ['defaults', 'restore', 'factory', 'preferences'],
      AppRoutes.settingsGeneral,
    ),
    (
      tr('Home sections'),
      tr('Home layout'),
      ['reorder', 'hide', 'show', 'dashboard'],
      AppRoutes.settingsHomeLayout,
    ),
    (
      tr('Show item counts'),
      tr('Home layout'),
      ['library', 'numbers', 'badges'],
      AppRoutes.settingsHomeLayout,
    ),
    (
      tr('Swipe right'),
      tr('Gestures'),
      ['swipe actions', 'gesture', 'complete', 'pin'],
      AppRoutes.settingsGestures,
    ),
    (
      tr('Swipe left'),
      tr('Gestures'),
      ['swipe actions', 'gesture', 'archive', 'delete'],
      AppRoutes.settingsGestures,
    ),
    (
      tr('In-app sounds'),
      tr('Sounds & haptics'),
      ['audio', 'click', 'chime'],
      AppRoutes.settingsSoundsHaptics,
    ),
    (
      tr('Haptic feedback'),
      tr('Sounds & haptics'),
      ['vibration', 'vibrate'],
      AppRoutes.settingsSoundsHaptics,
    ),
    (
      tr('Try haptics'),
      tr('Sounds & haptics'),
      ['vibration', 'test'],
      AppRoutes.settingsSoundsHaptics,
    ),
    (
      tr('Lock {name}', {'name': AppInfo.name}),
      tr('App lock'),
      ['face id', 'touch id', 'fingerprint', 'passcode', 'require'],
      AppRoutes.settingsAppLock,
    ),
    (
      tr('Tags'),
      tr('Tags & folders'),
      ['rename tag', 'merge', 'delete tag', 'new tag', 'labels'],
      AppRoutes.settingsTagsFolders,
    ),
    (
      tr('Folders'),
      tr('Tags & folders'),
      ['lists', 'rename folder', 'delete folder', 'new folder'],
      AppRoutes.settingsTagsFolders,
    ),
    (
      tr('Clear cache'),
      tr('Storage'),
      ['free space', 'temporary', 'thumbnails'],
      AppRoutes.settingsStorage,
    ),
    (tr('Version'), tr('About'), ['build', 'release'], AppRoutes.settingsAbout),
    (
      tr('Privacy policy'),
      tr('About'),
      ['data', 'legal'],
      AppRoutes.settingsAbout,
    ),
    (
      tr('Terms of use'),
      tr('About'),
      ['terms', 'legal'],
      AppRoutes.settingsAbout,
    ),
    (
      tr('Open-source licences'),
      tr('About'),
      ['licenses', 'acknowledgements', 'credits', 'fonts'],
      AppRoutes.settingsAbout,
    ),
  ];
}

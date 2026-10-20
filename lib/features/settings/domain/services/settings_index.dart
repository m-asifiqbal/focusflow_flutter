/// ============================================================
/// SETTINGS INDEX — every searchable setting, with its deep link
/// ============================================================
///
/// What: the static list behind "Search settings…" (screen 30): the root
/// rows plus the rows of every sub-page (31–36, general, app lock, modules,
/// home layout, gestures, sounds, tags & folders, storage, about), each
/// deep-linked to its page (settings_index_test.dart probes them).
/// Why: a sub-page's rows are not built until it is opened, so search
/// can't scan widgets; one table here is the single source of truth.
/// Add a row here when you add one to a settings page.
/// ============================================================
library;

import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';

abstract final class SettingsIndex {
  static const _root = 'Settings';
  static const _notif = 'Notifications & Reminders';
  static const _appear = 'Appearance';
  static const _vault = 'Vault security';
  static const _backup = 'Backup & Sync';
  static const _io = 'Import & Export';
  static const _account = 'Account';

  static final List<SettingsEntry> all = [
    // ── Root ──
    const SettingsEntry(
      title: 'Account',
      page: _root,
      keywords: ['profile', 'name', 'google', 'email', 'sign in'],
      route: AppRoutes.settingsAccount,
    ),
    const SettingsEntry(
      title: 'Language',
      page: 'General',
      keywords: ['english', 'locale'],
      action: SettingsRootAction.language,
    ),
    const SettingsEntry(
      title: 'Start screen',
      page: 'General',
      keywords: ['launch', 'open', 'home', 'default tab'],
      action: SettingsRootAction.startScreen,
    ),
    const SettingsEntry(
      title: 'Week starts on',
      page: 'General',
      keywords: ['monday', 'sunday', 'saturday', 'calendar'],
      action: SettingsRootAction.weekStart,
    ),
    const SettingsEntry(
      title: 'Date & time format',
      page: 'General',
      keywords: ['24-hour', '12-hour', 'clock', 'time'],
      route: AppRoutes.settingsGeneral,
    ),
    const SettingsEntry(
      title: 'Pinned items',
      page: 'Preferences',
      keywords: ['pin', 'favourites'],
      route: AppRoutes.pinned,
    ),
    const SettingsEntry(
      title: 'Home layout & widgets',
      page: 'Preferences',
      keywords: ['sections', 'reorder', 'dashboard'],
      route: AppRoutes.settingsHomeLayout,
    ),
    const SettingsEntry(
      title: 'Gestures & swipe actions',
      page: 'Preferences',
      keywords: ['swipe left', 'swipe right', 'archive', 'complete'],
      route: AppRoutes.settingsGestures,
    ),
    const SettingsEntry(
      title: 'Sounds & haptics',
      page: 'Preferences',
      keywords: ['vibration', 'audio', 'feedback'],
      route: AppRoutes.settingsSoundsHaptics,
    ),
    SettingsEntry(
      title: 'Notes defaults',
      page: 'Modules',
      keywords: const ['grid', 'list', 'sort', 'colour', 'color'],
      route: AppRoutes.settingsModule('notes'),
    ),
    SettingsEntry(
      title: 'Tasks defaults',
      page: 'Modules',
      keywords: const ['smart lists', 'show completed', 'default list'],
      route: AppRoutes.settingsModule('tasks'),
    ),
    SettingsEntry(
      title: 'Reminders defaults',
      page: 'Modules',
      keywords: const ['snooze', 'sound', 'tone'],
      route: AppRoutes.settingsModule('reminders'),
    ),
    SettingsEntry(
      title: 'Habits defaults',
      page: 'Modules',
      keywords: const ['reset time', 'day starts', 'streak'],
      route: AppRoutes.settingsModule('habits'),
    ),
    const SettingsEntry(
      title: 'Tags & folders',
      page: 'Modules',
      keywords: ['labels', 'organise', 'organize'],
      route: AppRoutes.settingsTagsFolders,
    ),
    const SettingsEntry(
      title: 'App lock',
      page: 'Security & privacy',
      keywords: ['pin', 'passcode', 'face id', 'fingerprint', 'biometric'],
      route: AppRoutes.settingsAppLock,
    ),
    const SettingsEntry(
      title: 'Hide content in app switcher',
      page: 'Security & privacy',
      keywords: ['privacy', 'recents', 'multitasking', 'blur'],
      action: SettingsRootAction.hideInSwitcher,
    ),
    const SettingsEntry(
      title: 'Clear clipboard after',
      page: 'Security & privacy',
      keywords: ['copy', 'paste', 'password'],
      // A vault security setting: changed only on Vault security, which
      // asks for the PIN / biometrics first.
      route: AppRoutes.settingsVaultSecurity,
    ),
    const SettingsEntry(
      title: 'Storage',
      page: 'Data & sync',
      keywords: ['space', 'cache', 'size', 'megabytes'],
      route: AppRoutes.settingsStorage,
    ),
    const SettingsEntry(
      title: 'Archive',
      page: 'Data & sync',
      keywords: ['archived'],
      route: AppRoutes.archive,
    ),
    const SettingsEntry(
      title: 'Recently deleted',
      page: 'Data & sync',
      keywords: ['trash', 'bin', 'restore', 'deleted'],
      route: AppRoutes.trash,
    ),
    const SettingsEntry(
      title: 'Help & Support',
      page: 'Support',
      keywords: ['contact', 'faq', 'email'],
      action: SettingsRootAction.help,
    ),
    const SettingsEntry(
      title: 'Send feedback',
      page: 'Support',
      keywords: ['bug', 'idea', 'suggestion'],
      action: SettingsRootAction.feedback,
    ),
    const SettingsEntry(
      title: 'Rate ${AppInfo.name}',
      page: 'Support',
      keywords: ['review', 'store', 'stars'],
      action: SettingsRootAction.rate,
    ),
    const SettingsEntry(
      title: 'About',
      page: 'Support',
      keywords: ['version', 'licenses', 'licences', 'privacy policy', 'terms'],
      route: AppRoutes.settingsAbout,
    ),
    // ── Notifications (31) ──
    for (final (title, keywords) in const [
      ('Notifications & Reminders', ['alerts', 'push']),
      ('Allow notifications', ['permission', 'alerts']),
      ('Morning briefing', ['digest', 'daily summary']),
      ('Evening review', ['digest', 'night']),
      ('Weekly report', ['summary', 'stats']),
      ('Streak at risk', ['habits', 'reminder']),
      ('Quiet hours', ['do not disturb', 'silence', 'night']),
      ('Default snooze', ['later', 'minutes']),
      (
        'Keep alarms running',
        ['background service', 'swipe away', 'app closed', 'alarm not ringing'],
      ),
      ('Lock screen', ['preview', 'privacy', 'title only']),
      ('App badge', ['count', 'icon', 'overdue']),
    ])
      SettingsEntry(
        title: title,
        page: _notif,
        keywords: keywords,
        route: AppRoutes.settingsNotifications,
      ),
    // ── Appearance (32) ──
    for (final (title, keywords) in const [
      ('Appearance', ['look', 'style']),
      ('Theme', ['dark mode', 'light mode', 'system', 'night']),
      ('Accent colour', ['color', 'tint', 'primary']),
      ('Text size', ['font size', 'bigger', 'smaller', 'accessibility']),
      ('App icon', ['home screen icon']),
      ('Notes default view', ['grid', 'list']),
      ('List density', ['compact', 'comfortable', 'spacing']),
      ('Reduce motion', ['animations', 'accessibility']),
      ('Visual effects', ['performance', 'lag', 'slow', 'blur', 'low end']),
      ('Use system font', ['typeface', 'font']),
    ])
      SettingsEntry(
        title: title,
        page: _appear,
        keywords: keywords,
        route: AppRoutes.settingsAppearance,
      ),
    // ── Vault security (33) ──
    for (final (title, keywords) in const [
      ('Vault security', ['passwords', 'vault']),
      ('Change vault PIN', ['passcode', 'password']),
      ('Unlock with biometrics', ['face id', 'fingerprint', 'touch id']),
      ('Auto-lock', ['timeout', 'minutes']),
      ('Lock when leaving the app', ['background']),
      ('Block screenshots', ['screen recording', 'privacy']),
      ('Re-authenticate to reveal', ['show password']),
      ('Breach monitoring', ['pwned', 'leaked', 'hibp']),
      ('Erase after failed attempts', ['wipe', 'self-destruct']),
    ])
      SettingsEntry(
        title: title,
        page: _vault,
        keywords: keywords,
        route: AppRoutes.settingsVaultSecurity,
      ),
    // ── Backup & Sync (34) ──
    for (final (title, keywords) in const [
      ('Backup & Sync', ['google drive', 'cloud']),
      ('Back up now', ['sync now', 'drive']),
      ('Auto backup to Google Drive', ['automatic', 'cloud']),
      ('Backup frequency', ['daily', 'weekly']),
      ('Sync when app opens', ['auto sync', 'launch', 'other devices']),
      ('Back up on Wi-Fi only', ['cellular', 'mobile data']),
      ('Encrypt backups', ['password', 'security']),
      ('Local backups', ['device', 'offline']),
    ])
      SettingsEntry(
        title: title,
        page: _backup,
        keywords: keywords,
        route: AppRoutes.settingsBackup,
      ),
    const SettingsEntry(
      title: 'Restore from backup',
      page: _backup,
      keywords: ['recover', 'import backup'],
      route: AppRoutes.settingsBackupRestore,
    ),
    // ── Import & Export (35) ──
    for (final (title, keywords) in const [
      ('Import & Export', ['transfer', 'move data']),
      ('Import from file', ['evernote', 'csv', 'markdown', 'json']),
      ('Export all data', ['download', 'json', 'markdown', 'csv']),
    ])
      SettingsEntry(
        title: title,
        page: _io,
        keywords: keywords,
        route: AppRoutes.settingsImportExport,
      ),
    // ── Account (36) ──
    for (final (title, keywords) in const [
      ('Display name', ['profile', 'name']),
      ('Daily focus goal', ['tasks per day', 'target']),
      ('Time zone', ['timezone', 'travel']),
      ('Linked devices', ['phones', 'tablets']),
      ('Erase local data', ['reset', 'factory']),
      ('Delete account & Drive data', ['remove account']),
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
    for (final (title, keywords) in const [
      ('Default view', ['grid', 'list', 'notes']),
      ('Sort by', ['order', 'notes', 'edited', 'created']),
      ('Colour of new notes', ['color', 'notes', 'background']),
    ])
      SettingsEntry(
        title: title,
        page: 'Notes defaults',
        keywords: keywords,
        route: AppRoutes.settingsModule('notes'),
      ),
    for (final (title, keywords) in const [
      ('Smart lists', ['today', 'upcoming', 'overdue', 'tasks']),
      ('Show completed', ['done', 'finished', 'tasks']),
      ('Default list', ['new tasks', 'folder', 'tasks']),
    ])
      SettingsEntry(
        title: title,
        page: 'Tasks defaults',
        keywords: keywords,
        route: AppRoutes.settingsModule('tasks'),
      ),
    for (final (title, keywords) in const [
      ('Reminder sound', ['tone', 'ringtone', 'alert']),
    ])
      SettingsEntry(
        title: title,
        page: 'Reminders defaults',
        keywords: keywords,
        route: AppRoutes.settingsModule('reminders'),
      ),
    for (final (title, keywords) in const [
      ('Day resets at', ['midnight', 'reset time', 'habits']),
    ])
      SettingsEntry(
        title: title,
        page: 'Habits defaults',
        keywords: keywords,
        route: AppRoutes.settingsModule('habits'),
      ),
  ];

  /// (title, page, keywords, route) of the rows on General, Home layout,
  /// Gestures, Sounds & haptics, App lock, Tags & folders, Storage, About.
  static const _subPageRows = <(String, String, List<String>, String)>[
    (
      'Date format',
      'General',
      ['day', 'month', 'year', 'pattern', 'dd/mm'],
      AppRoutes.settingsGeneral,
    ),
    (
      'Time format',
      'General',
      ['24-hour', '12-hour', 'clock'],
      AppRoutes.settingsGeneral,
    ),
    (
      'Reset settings',
      'General',
      ['defaults', 'restore', 'factory', 'preferences'],
      AppRoutes.settingsGeneral,
    ),
    (
      'Home sections',
      'Home layout',
      ['reorder', 'hide', 'show', 'dashboard'],
      AppRoutes.settingsHomeLayout,
    ),
    (
      'Show item counts',
      'Home layout',
      ['library', 'numbers', 'badges'],
      AppRoutes.settingsHomeLayout,
    ),
    (
      'Swipe right',
      'Gestures',
      ['swipe actions', 'gesture', 'complete', 'pin'],
      AppRoutes.settingsGestures,
    ),
    (
      'Swipe left',
      'Gestures',
      ['swipe actions', 'gesture', 'archive', 'delete'],
      AppRoutes.settingsGestures,
    ),
    (
      'In-app sounds',
      'Sounds & haptics',
      ['audio', 'click', 'chime'],
      AppRoutes.settingsSoundsHaptics,
    ),
    (
      'Haptic feedback',
      'Sounds & haptics',
      ['vibration', 'vibrate'],
      AppRoutes.settingsSoundsHaptics,
    ),
    (
      'Try haptics',
      'Sounds & haptics',
      ['vibration', 'test'],
      AppRoutes.settingsSoundsHaptics,
    ),
    (
      'Lock ${AppInfo.name}',
      'App lock',
      ['face id', 'touch id', 'fingerprint', 'passcode', 'require'],
      AppRoutes.settingsAppLock,
    ),
    (
      'Tags',
      'Tags & folders',
      ['rename tag', 'merge', 'delete tag', 'new tag', 'labels'],
      AppRoutes.settingsTagsFolders,
    ),
    (
      'Folders',
      'Tags & folders',
      ['lists', 'rename folder', 'delete folder', 'new folder'],
      AppRoutes.settingsTagsFolders,
    ),
    (
      'Clear cache',
      'Storage',
      ['free space', 'temporary', 'thumbnails'],
      AppRoutes.settingsStorage,
    ),
    ('Version', 'About', ['build', 'release'], AppRoutes.settingsAbout),
    ('Privacy policy', 'About', ['data', 'legal'], AppRoutes.settingsAbout),
    ('Terms of use', 'About', ['terms', 'legal'], AppRoutes.settingsAbout),
    (
      'Open-source licences',
      'About',
      ['licenses', 'acknowledgements', 'credits', 'fonts'],
      AppRoutes.settingsAbout,
    ),
  ];
}

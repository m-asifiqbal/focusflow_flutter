/// ============================================================
/// APP SETTINGS — every user preference, typed (screens 30–36)
/// ============================================================
///
/// One immutable value persisted as a JSON blob in SharedPreferences by
/// [SettingsController] (shared/providers/settings_provider.dart). Every
/// screen reads `ref.watch(settingsProvider)` so a change takes effect
/// immediately everywhere ("Every setting persists and takes effect
/// immediately" — screen 30 acceptance).
///
/// Adding a setting: add the field (with a default), copyWith, toJson,
/// fromJson. Unknown/missing keys and unknown enum names fall back to
/// defaults, so old blobs load; numbers are clamped to their valid range.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';

enum StartScreen { home, library, insights }

enum NotesView { grid, list }

enum NotesSort { lastEdited, created, titleAz, colour, manual }

enum ListDensity { comfortable, compact }

enum LockScreenVisibility { full, titleOnly, hidden }

enum BadgeMode { overdue, today, none }

enum BackupFrequency { daily, weekly }

enum LocalBackupFrequency { off, daily, weekly }

/// What a swipe does on a list row (Settings › Gestures).
enum SwipeAction { none, archive, delete, complete, pin, favourite, snooze }

/// Home sections (Settings › Home layout: show/hide/reorder).
enum HomeSection { focus, week, upNext, tasks, notes, habits }

/// Sign-in mode chosen on screen 02.
enum AccountMode { none, google, apple, offline }

@immutable
class AppSettings {
  /// Bounds enforced when a stored blob is read ([AppSettings.fromJson]).
  static const int minutesPerDay = 24 * 60;
  static const int maxDailyFocusGoal = 50;
  static const int maxClipboardClearSeconds = 60 * 60;
  static const int maxKeepBackups = 100;

  const AppSettings({
    // ── Onboarding / account ──
    this.onboardingSeen = false,
    this.accountMode = AccountMode.none,
    this.displayName = '',
    this.dailyFocusGoal = 7,
    this.timeZone,
    // ── General ──
    this.languageCode = 'en',
    this.startScreen = StartScreen.home,
    this.weekStartsOn = DateTime.monday,
    this.use24HourTime = false,
    this.dateFormat = 'MMM d, y',
    // ── Appearance ──
    this.themeMode = ThemeMode.system,
    this.accent = AccentColor.emerald,
    this.textScale = 1.0,
    this.appIcon = 'default',
    this.listDensity = ListDensity.comfortable,
    this.reduceMotion = false,
    this.useSystemFont = false,
    // ── Notifications ──
    this.notificationsEnabled = true,
    this.morningBriefing = true,
    this.morningBriefingMinutes = 8 * 60,
    this.eveningReview = true,
    this.eveningReviewMinutes = 21 * 60,
    this.weeklyReport = false,
    this.weeklyReportWeekday = DateTime.sunday,
    this.notifyReminders = true,
    this.notifyTasks = true,
    this.notifyHabits = true,
    this.notifyStreakRisk = true,
    this.notifyVault = true,
    this.notifySync = false,
    this.quietHours = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
    this.defaultSnoozeMinutes = 10,
    this.repeatIntervalMinutes = 0,
    this.repeatCount = 3,
    this.lockScreenVisibility = LockScreenVisibility.titleOnly,
    this.badgeMode = BadgeMode.overdue,
    // ── Modules ──
    this.notesView = NotesView.grid,
    this.notesSort = NotesSort.lastEdited,
    this.notesDefaultColor,
    this.tasksDefaultListId,
    this.tasksShowCompleted = true,
    this.tasksSmartLists = true,
    this.remindersDefaultSound = 'chime',
    this.habitResetMinutes = 0,
    // ── Home & library layout ──
    this.homeSections = HomeSection.values,
    this.hiddenHomeSections = const {},
    this.libraryShowCounts = true,
    this.hiddenLibraryModules = const {},
    this.libraryModuleOrder = const [],
    // ── Gestures, sounds ──
    this.swipeLeft = SwipeAction.archive,
    this.swipeRight = SwipeAction.complete,
    this.soundsEnabled = true,
    this.hapticsEnabled = true,
    // ── Security & privacy ──
    this.appLockEnabled = false,
    this.hideInAppSwitcher = true,
    this.clipboardClearSeconds = 30,
    this.vaultBiometrics = true,
    this.vaultAutoLockMinutes = 5,
    this.vaultLockOnBackground = true,
    this.vaultBlockScreenshots = true,
    this.vaultReauthToReveal = false,
    this.breachMonitoring = false,
    this.wipeAfterFailedAttempts = false,
    // ── Backup & sync ──
    this.autoBackupDrive = true,
    this.backupFrequency = BackupFrequency.daily,
    this.backupMinutes = 21 * 60,
    this.backupWifiOnly = true,
    this.encryptBackups = true,
    this.keepBackups = 10,
    this.localBackupFrequency = LocalBackupFrequency.weekly,
    this.lastSyncAt,
    // ── Search ──
    this.recentSearches = const [],
  });

  final bool onboardingSeen;
  final AccountMode accountMode;
  final String displayName;

  /// Tasks per day that make the Home hero 100%.
  final int dailyFocusGoal;

  /// IANA zone override; null = device zone.
  final String? timeZone;

  final String languageCode;
  final StartScreen startScreen;

  /// DateTime.monday (1) … DateTime.sunday (7).
  final int weekStartsOn;
  final bool use24HourTime;
  final String dateFormat;

  final ThemeMode themeMode;
  final AccentColor accent;

  /// Multiplies the system text scale (0.85–1.3).
  final double textScale;
  final String appIcon;
  final ListDensity listDensity;
  final bool reduceMotion;
  final bool useSystemFont;

  final bool notificationsEnabled;
  final bool morningBriefing;
  final int morningBriefingMinutes;
  final bool eveningReview;
  final int eveningReviewMinutes;
  final bool weeklyReport;
  final int weeklyReportWeekday;
  final bool notifyReminders;
  final bool notifyTasks;
  final bool notifyHabits;
  final bool notifyStreakRisk;
  final bool notifyVault;
  final bool notifySync;
  final bool quietHours;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final int defaultSnoozeMinutes;

  /// "Repeat until done": a reminder / task alert that is not marked done
  /// (or snoozed) is shown again every this many minutes; 0 = off.
  final int repeatIntervalMinutes;

  /// How many repeats at most ([repeatIntervalMinutes] on).
  final int repeatCount;
  final LockScreenVisibility lockScreenVisibility;

  /// Notifications may appear on the lock screen at all.
  bool get showOnLockScreen =>
      lockScreenVisibility != LockScreenVisibility.hidden;

  /// Longest repeat interval and the most repeats a setting may hold.
  static const int maxRepeatIntervalMinutes = 12 * 60;
  static const int maxRepeatCount = 10;
  final BadgeMode badgeMode;

  final NotesView notesView;
  final NotesSort notesSort;
  final String? notesDefaultColor;
  final String? tasksDefaultListId;
  final bool tasksShowCompleted;
  final bool tasksSmartLists;
  final String remindersDefaultSound;

  /// Minutes after midnight when the habit "day" rolls over.
  final int habitResetMinutes;

  final List<HomeSection> homeSections;
  final Set<HomeSection> hiddenHomeSections;
  final bool libraryShowCounts;

  /// `ItemType.key`s hidden from the Library grid.
  final Set<String> hiddenLibraryModules;

  /// `ItemType.key`s in the user's Library card order (empty = default
  /// order; keys missing from it follow in default order).
  final List<String> libraryModuleOrder;

  final SwipeAction swipeLeft;
  final SwipeAction swipeRight;
  final bool soundsEnabled;
  final bool hapticsEnabled;

  final bool appLockEnabled;
  final bool hideInAppSwitcher;

  /// 0 = never.
  final int clipboardClearSeconds;
  final bool vaultBiometrics;

  /// 0 = only on leave.
  final int vaultAutoLockMinutes;
  final bool vaultLockOnBackground;
  final bool vaultBlockScreenshots;
  final bool vaultReauthToReveal;
  final bool breachMonitoring;
  final bool wipeAfterFailedAttempts;

  final bool autoBackupDrive;
  final BackupFrequency backupFrequency;
  final int backupMinutes;
  final bool backupWifiOnly;
  final bool encryptBackups;
  final int keepBackups;
  final LocalBackupFrequency localBackupFrequency;
  final DateTime? lastSyncAt;

  /// Newest first, max 10.
  final List<String> recentSearches;

  /// Home sections in display order, hidden ones removed.
  List<HomeSection> get visibleHomeSections =>
      homeSections.where((s) => !hiddenHomeSections.contains(s)).toList();

  bool get isSignedInWithGoogle => accountMode == AccountMode.google;

  AppSettings copyWith({
    bool? onboardingSeen,
    AccountMode? accountMode,
    String? displayName,
    int? dailyFocusGoal,
    String? Function()? timeZone,
    String? languageCode,
    StartScreen? startScreen,
    int? weekStartsOn,
    bool? use24HourTime,
    String? dateFormat,
    ThemeMode? themeMode,
    AccentColor? accent,
    double? textScale,
    String? appIcon,
    ListDensity? listDensity,
    bool? reduceMotion,
    bool? useSystemFont,
    bool? notificationsEnabled,
    bool? morningBriefing,
    int? morningBriefingMinutes,
    bool? eveningReview,
    int? eveningReviewMinutes,
    bool? weeklyReport,
    int? weeklyReportWeekday,
    bool? notifyReminders,
    bool? notifyTasks,
    bool? notifyHabits,
    bool? notifyStreakRisk,
    bool? notifyVault,
    bool? notifySync,
    bool? quietHours,
    int? quietStartMinutes,
    int? quietEndMinutes,
    int? defaultSnoozeMinutes,
    int? repeatIntervalMinutes,
    int? repeatCount,
    LockScreenVisibility? lockScreenVisibility,
    BadgeMode? badgeMode,
    NotesView? notesView,
    NotesSort? notesSort,
    String? Function()? notesDefaultColor,
    String? Function()? tasksDefaultListId,
    bool? tasksShowCompleted,
    bool? tasksSmartLists,
    String? remindersDefaultSound,
    int? habitResetMinutes,
    List<HomeSection>? homeSections,
    Set<HomeSection>? hiddenHomeSections,
    bool? libraryShowCounts,
    Set<String>? hiddenLibraryModules,
    List<String>? libraryModuleOrder,
    SwipeAction? swipeLeft,
    SwipeAction? swipeRight,
    bool? soundsEnabled,
    bool? hapticsEnabled,
    bool? appLockEnabled,
    bool? hideInAppSwitcher,
    int? clipboardClearSeconds,
    bool? vaultBiometrics,
    int? vaultAutoLockMinutes,
    bool? vaultLockOnBackground,
    bool? vaultBlockScreenshots,
    bool? vaultReauthToReveal,
    bool? breachMonitoring,
    bool? wipeAfterFailedAttempts,
    bool? autoBackupDrive,
    BackupFrequency? backupFrequency,
    int? backupMinutes,
    bool? backupWifiOnly,
    bool? encryptBackups,
    int? keepBackups,
    LocalBackupFrequency? localBackupFrequency,
    DateTime? Function()? lastSyncAt,
    List<String>? recentSearches,
  }) {
    return AppSettings(
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      accountMode: accountMode ?? this.accountMode,
      displayName: displayName ?? this.displayName,
      dailyFocusGoal: dailyFocusGoal ?? this.dailyFocusGoal,
      timeZone: timeZone != null ? timeZone() : this.timeZone,
      languageCode: languageCode ?? this.languageCode,
      startScreen: startScreen ?? this.startScreen,
      weekStartsOn: weekStartsOn ?? this.weekStartsOn,
      use24HourTime: use24HourTime ?? this.use24HourTime,
      dateFormat: dateFormat ?? this.dateFormat,
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      textScale: textScale ?? this.textScale,
      appIcon: appIcon ?? this.appIcon,
      listDensity: listDensity ?? this.listDensity,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      useSystemFont: useSystemFont ?? this.useSystemFont,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      morningBriefing: morningBriefing ?? this.morningBriefing,
      morningBriefingMinutes:
          morningBriefingMinutes ?? this.morningBriefingMinutes,
      eveningReview: eveningReview ?? this.eveningReview,
      eveningReviewMinutes: eveningReviewMinutes ?? this.eveningReviewMinutes,
      weeklyReport: weeklyReport ?? this.weeklyReport,
      weeklyReportWeekday: weeklyReportWeekday ?? this.weeklyReportWeekday,
      notifyReminders: notifyReminders ?? this.notifyReminders,
      notifyTasks: notifyTasks ?? this.notifyTasks,
      notifyHabits: notifyHabits ?? this.notifyHabits,
      notifyStreakRisk: notifyStreakRisk ?? this.notifyStreakRisk,
      notifyVault: notifyVault ?? this.notifyVault,
      notifySync: notifySync ?? this.notifySync,
      quietHours: quietHours ?? this.quietHours,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      repeatIntervalMinutes:
          repeatIntervalMinutes ?? this.repeatIntervalMinutes,
      repeatCount: repeatCount ?? this.repeatCount,
      lockScreenVisibility: lockScreenVisibility ?? this.lockScreenVisibility,
      badgeMode: badgeMode ?? this.badgeMode,
      notesView: notesView ?? this.notesView,
      notesSort: notesSort ?? this.notesSort,
      notesDefaultColor: notesDefaultColor != null
          ? notesDefaultColor()
          : this.notesDefaultColor,
      tasksDefaultListId: tasksDefaultListId != null
          ? tasksDefaultListId()
          : this.tasksDefaultListId,
      tasksShowCompleted: tasksShowCompleted ?? this.tasksShowCompleted,
      tasksSmartLists: tasksSmartLists ?? this.tasksSmartLists,
      remindersDefaultSound:
          remindersDefaultSound ?? this.remindersDefaultSound,
      habitResetMinutes: habitResetMinutes ?? this.habitResetMinutes,
      homeSections: homeSections ?? this.homeSections,
      hiddenHomeSections: hiddenHomeSections ?? this.hiddenHomeSections,
      libraryShowCounts: libraryShowCounts ?? this.libraryShowCounts,
      hiddenLibraryModules: hiddenLibraryModules ?? this.hiddenLibraryModules,
      libraryModuleOrder: libraryModuleOrder ?? this.libraryModuleOrder,
      swipeLeft: swipeLeft ?? this.swipeLeft,
      swipeRight: swipeRight ?? this.swipeRight,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      hideInAppSwitcher: hideInAppSwitcher ?? this.hideInAppSwitcher,
      clipboardClearSeconds:
          clipboardClearSeconds ?? this.clipboardClearSeconds,
      vaultBiometrics: vaultBiometrics ?? this.vaultBiometrics,
      vaultAutoLockMinutes: vaultAutoLockMinutes ?? this.vaultAutoLockMinutes,
      vaultLockOnBackground:
          vaultLockOnBackground ?? this.vaultLockOnBackground,
      vaultBlockScreenshots:
          vaultBlockScreenshots ?? this.vaultBlockScreenshots,
      vaultReauthToReveal: vaultReauthToReveal ?? this.vaultReauthToReveal,
      breachMonitoring: breachMonitoring ?? this.breachMonitoring,
      wipeAfterFailedAttempts:
          wipeAfterFailedAttempts ?? this.wipeAfterFailedAttempts,
      autoBackupDrive: autoBackupDrive ?? this.autoBackupDrive,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      backupMinutes: backupMinutes ?? this.backupMinutes,
      backupWifiOnly: backupWifiOnly ?? this.backupWifiOnly,
      encryptBackups: encryptBackups ?? this.encryptBackups,
      keepBackups: keepBackups ?? this.keepBackups,
      localBackupFrequency: localBackupFrequency ?? this.localBackupFrequency,
      lastSyncAt: lastSyncAt != null ? lastSyncAt() : this.lastSyncAt,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }

  Map<String, Object?> toJson() => {
    'onboardingSeen': onboardingSeen,
    'accountMode': accountMode.name,
    'displayName': displayName,
    'dailyFocusGoal': dailyFocusGoal,
    'timeZone': timeZone,
    'languageCode': languageCode,
    'startScreen': startScreen.name,
    'weekStartsOn': weekStartsOn,
    'use24HourTime': use24HourTime,
    'dateFormat': dateFormat,
    'themeMode': themeMode.name,
    'accent': accent.name,
    'textScale': textScale,
    'appIcon': appIcon,
    'listDensity': listDensity.name,
    'reduceMotion': reduceMotion,
    'useSystemFont': useSystemFont,
    'notificationsEnabled': notificationsEnabled,
    'morningBriefing': morningBriefing,
    'morningBriefingMinutes': morningBriefingMinutes,
    'eveningReview': eveningReview,
    'eveningReviewMinutes': eveningReviewMinutes,
    'weeklyReport': weeklyReport,
    'weeklyReportWeekday': weeklyReportWeekday,
    'notifyReminders': notifyReminders,
    'notifyTasks': notifyTasks,
    'notifyHabits': notifyHabits,
    'notifyStreakRisk': notifyStreakRisk,
    'notifyVault': notifyVault,
    'notifySync': notifySync,
    'quietHours': quietHours,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
    'defaultSnoozeMinutes': defaultSnoozeMinutes,
    'repeatIntervalMinutes': repeatIntervalMinutes,
    'repeatCount': repeatCount,
    'lockScreenVisibility': lockScreenVisibility.name,
    'badgeMode': badgeMode.name,
    'notesView': notesView.name,
    'notesSort': notesSort.name,
    'notesDefaultColor': notesDefaultColor,
    'tasksDefaultListId': tasksDefaultListId,
    'tasksShowCompleted': tasksShowCompleted,
    'tasksSmartLists': tasksSmartLists,
    'remindersDefaultSound': remindersDefaultSound,
    'habitResetMinutes': habitResetMinutes,
    'homeSections': homeSections.map((s) => s.name).toList(),
    'hiddenHomeSections': hiddenHomeSections.map((s) => s.name).toList(),
    'libraryShowCounts': libraryShowCounts,
    'hiddenLibraryModules': hiddenLibraryModules.toList(),
    'libraryModuleOrder': libraryModuleOrder,
    'swipeLeft': swipeLeft.name,
    'swipeRight': swipeRight.name,
    'soundsEnabled': soundsEnabled,
    'hapticsEnabled': hapticsEnabled,
    'appLockEnabled': appLockEnabled,
    'hideInAppSwitcher': hideInAppSwitcher,
    'clipboardClearSeconds': clipboardClearSeconds,
    'vaultBiometrics': vaultBiometrics,
    'vaultAutoLockMinutes': vaultAutoLockMinutes,
    'vaultLockOnBackground': vaultLockOnBackground,
    'vaultBlockScreenshots': vaultBlockScreenshots,
    'vaultReauthToReveal': vaultReauthToReveal,
    'breachMonitoring': breachMonitoring,
    'wipeAfterFailedAttempts': wipeAfterFailedAttempts,
    'autoBackupDrive': autoBackupDrive,
    'backupFrequency': backupFrequency.name,
    'backupMinutes': backupMinutes,
    'backupWifiOnly': backupWifiOnly,
    'encryptBackups': encryptBackups,
    'keepBackups': keepBackups,
    'localBackupFrequency': localBackupFrequency.name,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'recentSearches': recentSearches,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    T e<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.firstWhere((x) => x.name == v, orElse: () => fallback);
    bool b(String k, bool f) => j[k] is bool ? j[k]! as bool : f;
    int i(String k, int f) {
      final v = j[k];
      return v is num && v.isFinite ? v.toInt() : f;
    }

    // Range-checked ints: a hand-edited or corrupted blob can't put an
    // impossible value (weekday 9, minute 2000, keep 0 backups) in effect.
    int r(String k, int f, int min, int max) => i(k, f).clamp(min, max);
    int minute(String k, int f) => r(k, f, 0, minutesPerDay - 1);
    String s(String k, String f) => j[k] is String ? j[k]! as String : f;
    String? sn(String k) => j[k] is String ? j[k]! as String : null;
    List<String> ls(String k) =>
        j[k] is List ? (j[k]! as List).whereType<String>().toList() : const [];

    final sections = ls('homeSections')
        .map((n) => HomeSection.values.where((s) => s.name == n).firstOrNull)
        .whereType<HomeSection>()
        .toList();
    // Keep sections added in newer versions visible at the end.
    for (final s in HomeSection.values) {
      if (!sections.contains(s)) sections.add(s);
    }

    return AppSettings(
      onboardingSeen: b('onboardingSeen', d.onboardingSeen),
      accountMode: e(AccountMode.values, j['accountMode'], d.accountMode),
      displayName: s('displayName', d.displayName),
      dailyFocusGoal: r(
        'dailyFocusGoal',
        d.dailyFocusGoal,
        1,
        maxDailyFocusGoal,
      ),
      timeZone: sn('timeZone'),
      languageCode: s('languageCode', d.languageCode),
      startScreen: e(StartScreen.values, j['startScreen'], d.startScreen),
      weekStartsOn: r('weekStartsOn', d.weekStartsOn, 1, 7),
      use24HourTime: b('use24HourTime', d.use24HourTime),
      dateFormat: s('dateFormat', d.dateFormat),
      themeMode: e(ThemeMode.values, j['themeMode'], d.themeMode),
      accent: AccentColor.fromName(sn('accent')),
      textScale: j['textScale'] is num && (j['textScale']! as num).isFinite
          ? (j['textScale']! as num).toDouble().clamp(0.85, 1.3)
          : d.textScale,
      appIcon: s('appIcon', d.appIcon),
      listDensity: e(ListDensity.values, j['listDensity'], d.listDensity),
      reduceMotion: b('reduceMotion', d.reduceMotion),
      useSystemFont: b('useSystemFont', d.useSystemFont),
      notificationsEnabled: b('notificationsEnabled', d.notificationsEnabled),
      morningBriefing: b('morningBriefing', d.morningBriefing),
      morningBriefingMinutes: minute(
        'morningBriefingMinutes',
        d.morningBriefingMinutes,
      ),
      eveningReview: b('eveningReview', d.eveningReview),
      eveningReviewMinutes: minute(
        'eveningReviewMinutes',
        d.eveningReviewMinutes,
      ),
      weeklyReport: b('weeklyReport', d.weeklyReport),
      weeklyReportWeekday: r(
        'weeklyReportWeekday',
        d.weeklyReportWeekday,
        1,
        7,
      ),
      notifyReminders: b('notifyReminders', d.notifyReminders),
      notifyTasks: b('notifyTasks', d.notifyTasks),
      notifyHabits: b('notifyHabits', d.notifyHabits),
      notifyStreakRisk: b('notifyStreakRisk', d.notifyStreakRisk),
      notifyVault: b('notifyVault', d.notifyVault),
      notifySync: b('notifySync', d.notifySync),
      quietHours: b('quietHours', d.quietHours),
      quietStartMinutes: minute('quietStartMinutes', d.quietStartMinutes),
      quietEndMinutes: minute('quietEndMinutes', d.quietEndMinutes),
      defaultSnoozeMinutes: r(
        'defaultSnoozeMinutes',
        d.defaultSnoozeMinutes,
        1,
        minutesPerDay,
      ),
      repeatIntervalMinutes: r(
        'repeatIntervalMinutes',
        d.repeatIntervalMinutes,
        0,
        maxRepeatIntervalMinutes,
      ),
      repeatCount: r('repeatCount', d.repeatCount, 1, maxRepeatCount),
      lockScreenVisibility: e(
        LockScreenVisibility.values,
        j['lockScreenVisibility'],
        d.lockScreenVisibility,
      ),
      badgeMode: e(BadgeMode.values, j['badgeMode'], d.badgeMode),
      notesView: e(NotesView.values, j['notesView'], d.notesView),
      notesSort: e(NotesSort.values, j['notesSort'], d.notesSort),
      notesDefaultColor: sn('notesDefaultColor'),
      tasksDefaultListId: sn('tasksDefaultListId'),
      tasksShowCompleted: b('tasksShowCompleted', d.tasksShowCompleted),
      tasksSmartLists: b('tasksSmartLists', d.tasksSmartLists),
      remindersDefaultSound: s(
        'remindersDefaultSound',
        d.remindersDefaultSound,
      ),
      habitResetMinutes: minute('habitResetMinutes', d.habitResetMinutes),
      homeSections: sections,
      hiddenHomeSections: ls('hiddenHomeSections')
          .map((n) => HomeSection.values.where((s) => s.name == n).firstOrNull)
          .whereType<HomeSection>()
          .toSet(),
      libraryShowCounts: b('libraryShowCounts', d.libraryShowCounts),
      hiddenLibraryModules: ls('hiddenLibraryModules').toSet(),
      libraryModuleOrder: ls('libraryModuleOrder'),
      swipeLeft: e(SwipeAction.values, j['swipeLeft'], d.swipeLeft),
      swipeRight: e(SwipeAction.values, j['swipeRight'], d.swipeRight),
      soundsEnabled: b('soundsEnabled', d.soundsEnabled),
      hapticsEnabled: b('hapticsEnabled', d.hapticsEnabled),
      appLockEnabled: b('appLockEnabled', d.appLockEnabled),
      hideInAppSwitcher: b('hideInAppSwitcher', d.hideInAppSwitcher),
      clipboardClearSeconds: r(
        'clipboardClearSeconds',
        d.clipboardClearSeconds,
        0,
        maxClipboardClearSeconds,
      ),
      vaultBiometrics: b('vaultBiometrics', d.vaultBiometrics),
      vaultAutoLockMinutes: r(
        'vaultAutoLockMinutes',
        d.vaultAutoLockMinutes,
        0,
        minutesPerDay,
      ),
      vaultLockOnBackground: b(
        'vaultLockOnBackground',
        d.vaultLockOnBackground,
      ),
      vaultBlockScreenshots: b(
        'vaultBlockScreenshots',
        d.vaultBlockScreenshots,
      ),
      vaultReauthToReveal: b('vaultReauthToReveal', d.vaultReauthToReveal),
      breachMonitoring: b('breachMonitoring', d.breachMonitoring),
      wipeAfterFailedAttempts: b(
        'wipeAfterFailedAttempts',
        d.wipeAfterFailedAttempts,
      ),
      autoBackupDrive: b('autoBackupDrive', d.autoBackupDrive),
      backupFrequency: e(
        BackupFrequency.values,
        j['backupFrequency'],
        d.backupFrequency,
      ),
      backupMinutes: minute('backupMinutes', d.backupMinutes),
      backupWifiOnly: b('backupWifiOnly', d.backupWifiOnly),
      encryptBackups: b('encryptBackups', d.encryptBackups),
      keepBackups: r('keepBackups', d.keepBackups, 1, maxKeepBackups),
      localBackupFrequency: e(
        LocalBackupFrequency.values,
        j['localBackupFrequency'],
        d.localBackupFrequency,
      ),
      lastSyncAt: sn('lastSyncAt') == null
          ? null
          : DateTime.tryParse(sn('lastSyncAt')!),
      recentSearches: ls('recentSearches').take(10).toList(),
    );
  }
}

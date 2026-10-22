/// ============================================================
/// APP INFO — the single place to rename the product
/// ============================================================
///
/// "FocusFlow" is a working name (several apps already use it — see
/// docs/kit/README.md for alternatives). Change [name] here and the launcher
/// labels (AndroidManifest `android:label`, iOS `CFBundleDisplayName`); every
/// screen reads the name from this file.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';

abstract final class AppInfo {
  static const String name = 'FocusFlow';

  /// A getter, not a const, so it follows the language.
  static String get tagline => tr('Everything you need, in one calm place.');

  /// Deep-link scheme used by notification taps: `focusflow://item/{type}/{id}`.
  static const String deepLinkScheme = 'focusflow';

  /// Backup file extension (a zip — see core/sync/backup_format.dart).
  static const String backupExtension = 'ffbackup';

  /// Folder name used for local backups / exports.
  static const String localFolderName = 'FocusFlow';

  static const String supportEmail = 'support@focusflow.app';
  static const String termsUrl = 'https://focusflow.app/terms';
  static const String privacyUrl = 'https://focusflow.app/privacy';

  /// SQLite file (encrypted at rest — see core/database/encrypted_database.dart).
  static const String databaseFileName = 'focusflow.db';
}

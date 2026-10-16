/// ============================================================
/// STORAGE REPOSITORY (contract) — measure / clear on-device storage
/// ============================================================
///
/// Implemented over the file system in data/storage_repository_impl.dart;
/// tests use a fake. Clearing is limited to the cache on purpose: user data
/// (database, attachments, backups) is never deleted from Settings.
/// ============================================================
library;

import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';

abstract interface class StorageRepository {
  /// Sizes of every storage bucket right now.
  Future<StorageUsage> measure();

  /// Deletes temporary files only. Returns the number of bytes freed.
  Future<int> clearCache();
}

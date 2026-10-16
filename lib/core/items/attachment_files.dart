/// ============================================================
/// ATTACHMENT FILES — deleting the files behind attachments / covers
/// ============================================================
///
/// Attachment rows and note covers store paths *relative* to the app
/// documents directory (`attachments/<id>.<ext>`). Permanent delete and the
/// 30-day purge remove those files through this interface so repositories
/// stay testable without a real file system.
/// ============================================================
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class AttachmentFileStore {
  /// Deletes the file at [relativePath] (no-op when missing).
  Future<void> delete(String relativePath);
}

/// Production store rooted at the app documents directory.
class LocalAttachmentFileStore implements AttachmentFileStore {
  const LocalAttachmentFileStore();

  @override
  Future<void> delete(String relativePath) async {
    if (relativePath.isEmpty || p.isAbsolute(relativePath)) return;
    final root = await getApplicationDocumentsDirectory();
    final file = File(p.normalize(p.join(root.path, relativePath)));
    // Never escape the documents directory (defensive against `..`).
    if (!p.isWithin(root.path, file.path)) return;
    if (await file.exists()) await file.delete();
  }
}

/// Does nothing — for tests and contexts without files.
class NoopAttachmentFileStore implements AttachmentFileStore {
  const NoopAttachmentFileStore();

  @override
  Future<void> delete(String relativePath) async {}
}

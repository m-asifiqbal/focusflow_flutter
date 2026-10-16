/// ============================================================
/// NOTE FILE STORE — images inside the app documents directory
/// ============================================================
///
/// Images picked in the note editor are copied to
/// `<documents>/attachments/<uuid>.<ext>` and referenced by that
/// *relative* path everywhere (Delta embeds, `attachments.local_path`,
/// `notes.cover_image_path`), so backups and restores to another device
/// keep working. The root is injected so widget tests can use a temp dir.
/// ============================================================
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// A file copied into the store.
class StoredNoteFile {
  const StoredNoteFile({
    required this.relativePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String relativePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
}

class NoteFileStore {
  NoteFileStore(this.root);

  /// Absolute app documents directory.
  final Directory root;

  static const String folder = 'attachments';

  /// The absolute file for [relativePath], or null when it would escape
  /// the documents directory.
  File? resolve(String relativePath) {
    if (relativePath.isEmpty || p.isAbsolute(relativePath)) return null;
    final full = p.normalize(p.join(root.path, relativePath));
    if (!p.isWithin(root.path, full)) return null;
    return File(full);
  }

  /// Copies [sourcePath] into the store as `attachments/<id>.<ext>`.
  Future<StoredNoteFile> importImage(String sourcePath, String id) async {
    final source = File(sourcePath);
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = ext.isEmpty || ext.length > 6 ? '.jpg' : ext;
    final relative = p.join(folder, '$id$safeExt');
    final target = File(p.join(root.path, relative));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return StoredNoteFile(
      relativePath: relative,
      fileName: p.basename(sourcePath),
      mimeType: _mimeFor(safeExt),
      sizeBytes: await target.length(),
    );
  }

  /// Deletes [relativePath] if it exists (no-op otherwise).
  Future<void> delete(String relativePath) async {
    final file = resolve(relativePath);
    if (file != null && await file.exists()) await file.delete();
  }

  static String _mimeFor(String ext) => switch (ext) {
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}

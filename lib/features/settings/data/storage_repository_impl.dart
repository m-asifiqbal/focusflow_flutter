/// ============================================================
/// STORAGE REPOSITORY — measures FocusFlow's on-device footprint
/// ============================================================
///
/// What: sums the encrypted database (+ WAL/SHM), attachment and cover
/// files, local backups and the temp/cache directory.
/// Why: the Settings "Storage" row and the Storage page show real numbers;
/// clearing is limited to the cache so user data is never lost from here.
/// Directories are injectable so tests can point at a temp folder.
/// ============================================================
library;

import 'dart:io';

import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';
import 'package:focusflow/features/settings/domain/repository/storage_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileStorageRepository implements StorageRepository {
  FileStorageRepository({
    Future<Directory> Function()? supportDir,
    Future<Directory> Function()? documentsDir,
    Future<Directory> Function()? cacheDir,
  }) : _support = supportDir ?? getApplicationSupportDirectory,
       _documents = documentsDir ?? getApplicationDocumentsDirectory,
       _cache = cacheDir ?? getTemporaryDirectory;

  final Future<Directory> Function() _support;
  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _cache;

  @override
  Future<StorageUsage> measure() async {
    final support = (await _support()).path;
    final docs = (await _documents()).path;
    var db = 0;
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      db += await _fileSize(
        File(p.join(support, '${AppInfo.databaseFileName}$suffix')),
      );
    }
    final attachments =
        await _dirSize(Directory(p.join(docs, 'attachments'))) +
        await _dirSize(Directory(p.join(docs, 'covers')));
    final backups = await _dirSize(
      Directory(p.join(docs, AppInfo.localFolderName, 'backups')),
    );
    final cache = await _dirSize(await _cache());
    return StorageUsage(
      databaseBytes: db,
      attachmentsBytes: attachments,
      backupsBytes: backups,
      cacheBytes: cache,
    );
  }

  @override
  Future<int> clearCache() async {
    final dir = await _cache();
    final before = await _dirSize(dir);
    if (await dir.exists()) {
      await for (final e in dir.list(followLinks: false)) {
        try {
          await e.delete(recursive: true);
        } on FileSystemException {
          // In use by the OS / another plugin — leave it.
        }
      }
    }
    return before - await _dirSize(dir);
  }

  static Future<int> _fileSize(File f) async {
    try {
      return await f.exists() ? await f.length() : 0;
    } on FileSystemException {
      return 0;
    }
  }

  static Future<int> _dirSize(Directory d) async {
    if (!await d.exists()) return 0;
    var total = 0;
    try {
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File) total += await _fileSize(e);
      }
    } on FileSystemException {
      // Unreadable sub-folder — count what we could.
    }
    return total;
  }
}

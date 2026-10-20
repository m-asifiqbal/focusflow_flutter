/// ============================================================
/// BACKUP FILES — attachment / cover files and the local backup folder
/// ============================================================
///
/// [AppFiles] reads and writes files *relative to the app documents
/// directory* (attachments/…, covers/…, FocusFlow/backups/…). Paths can
/// never escape that root. Tests use [AppFiles.at] with a temp directory.
/// ============================================================
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppFiles {
  AppFiles([Future<Directory> Function()? root])
    : _root = root ?? getApplicationDocumentsDirectory;

  /// A store rooted at [dir] (tests, background isolate).
  AppFiles.at(Directory dir) : _root = (() async => dir);

  final Future<Directory> Function() _root;

  /// The local profile picture (Account & profile). Full backups carry it
  /// next to the settings (backup_engine.dart).
  static const String profilePhotoPath = 'profile/avatar.jpg';

  Future<Directory> root() => _root();

  /// Absolute file for [relative] or null when it would escape the root.
  Future<File?> file(String relative) async {
    if (relative.isEmpty || p.isAbsolute(relative)) return null;
    final root = (await _root()).path;
    final path = p.normalize(p.join(root, relative));
    if (!p.isWithin(root, path)) return null;
    return File(path);
  }

  Future<Uint8List?> read(String relative) async {
    final f = await file(relative);
    if (f == null || !await f.exists()) return null;
    return f.readAsBytes();
  }

  Future<bool> exists(String relative) async {
    final f = await file(relative);
    return f != null && await f.exists();
  }

  Future<File?> write(String relative, List<int> bytes) async {
    final f = await file(relative);
    if (f == null) return null;
    await f.parent.create(recursive: true);
    return f.writeAsBytes(bytes, flush: true);
  }

  Future<void> delete(String relative) async {
    final f = await file(relative);
    if (f != null && await f.exists()) await f.delete();
  }

  /// Files directly inside the relative [dir] (newest first).
  Future<List<File>> list(String dir) async {
    final root = (await _root()).path;
    final d = Directory(p.join(root, dir));
    if (!await d.exists()) return const [];
    final files = await d.list().where((e) => e is File).cast<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// [absolute] as a path relative to the root (for records / display).
  Future<String> relativeOf(String absolute) async =>
      p.relative(absolute, from: (await _root()).path);
}

/// ============================================================
/// IMPORT FILE SOURCE — the system file picker for Import / Restore
/// ============================================================
///
/// What: lets the user pick one file and returns its name + bytes, plus a
/// `discard()` that deletes the picker's temporary copy.
/// Why: password CSVs are plaintext; once parsed (and encrypted by the
/// vault) the copy the picker left in the app's cache must go at once.
/// Tests override [importFileSourceProvider] with in-memory files.
/// ============================================================
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class PickedImportFile {
  PickedImportFile({required this.name, required this.bytes, this.onDiscard});

  final String name;
  final Uint8List bytes;

  /// Deletes the temporary copy (called by [discard]).
  final Future<void> Function()? onDiscard;

  /// Deletes the temporary copy (best effort; never throws).
  Future<void> discard() async {
    try {
      await onDiscard?.call();
    } on Object {
      // The OS clears the cache eventually.
    }
  }
}

abstract interface class ImportFileSource {
  /// Null when the user cancelled.
  Future<PickedImportFile?> pick();
}

class PlatformImportFileSource implements ImportFileSource {
  const PlatformImportFileSource();

  @override
  Future<PickedImportFile?> pick() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    final f = files.first;
    final bytes = await f.readAsBytes();
    final path = f.path;
    return PickedImportFile(
      name: f.name,
      bytes: bytes,
      onDiscard: () async {
        if (path == null) return;
        final tmp = (await getTemporaryDirectory()).path;
        // Only ever delete the picker's own cached copy, not the original.
        if (path.startsWith(tmp) || path.contains('/file_picker/')) {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        }
      },
    );
  }
}

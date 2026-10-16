/// ============================================================
/// NOTE SHARE SERVICE — export a note as PDF / TXT / MD and share it
/// ============================================================
///
/// Writes the export into the temporary directory and hands it to the
/// platform share sheet (share_plus). Nothing leaves the device unless the
/// user picks a share target. Content is never logged.
///
/// The export is plaintext (even for a locked note once the Vault PIN was
/// entered), so it must not outlive the share: the file is deleted as soon
/// as the share sheet returns. Android hands the receiving app a content URI
/// it may read *after* the chooser returns (e.g. Gmail attaching on send), so
/// there the file is kept until the next export, which purges the folder
/// first ([NoteShareService.purgeExports] can also be called on start-up).
/// ============================================================
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:focusflow/features/notes/data/export/note_pdf_builder.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/services/note_export.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the platform share sheet for [files]; returns false when dismissed.
typedef ShareFiles = Future<bool> Function(List<XFile> files, String subject);

class NoteShareService {
  NoteShareService({
    required this.pdf,
    ShareFiles? shareFiles,
    Future<Directory> Function()? tempDir,
    bool? keepUntilNextExport,
  }) : _shareFiles = shareFiles ?? _platformShare,
       _tempDir = tempDir ?? getTemporaryDirectory,
       _keepUntilNextExport = keepUntilNextExport ?? Platform.isAndroid;

  final NotePdfBuilder pdf;
  final ShareFiles _shareFiles;
  final Future<Directory> Function() _tempDir;
  final bool _keepUntilNextExport;

  static Future<bool> _platformShare(List<XFile> files, String subject) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: files, subject: subject),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  Future<Directory> _exportDir() async =>
      Directory(p.join((await _tempDir()).path, 'exports', 'notes'));

  /// Deletes every note export left in the temporary folder.
  Future<void> purgeExports() async {
    final dir = await _exportDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// The exported bytes of [note] in [format].
  Future<Uint8List> render(
    Note note,
    NoteExportFormat format, {
    String? subtitle,
  }) async => switch (format) {
    NoteExportFormat.pdf => pdf.build(note, subtitle: subtitle),
    NoteExportFormat.text => Uint8List.fromList(
      utf8.encode(NoteExport.toText(note)),
    ),
    NoteExportFormat.markdown => Uint8List.fromList(
      utf8.encode(NoteExport.toMarkdown(note)),
    ),
  };

  /// Renders [note] and opens the share sheet. Returns false when the user
  /// dismissed it. The plaintext file is removed afterwards (see header).
  Future<bool> share(
    Note note,
    NoteExportFormat format, {
    String? subtitle,
  }) async {
    final bytes = await render(note, format, subtitle: subtitle);
    await purgeExports();
    final exportDir = await _exportDir();
    await exportDir.create(recursive: true);
    final file = File(
      p.join(
        exportDir.path,
        '${NoteExport.fileStem(note)}.${format.extension}',
      ),
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      return await _shareFiles([
        XFile(file.path, mimeType: format.mimeType),
      ], note.displayTitle);
    } finally {
      if (!_keepUntilNextExport && await file.exists()) await file.delete();
    }
  }
}

/// ============================================================
/// RECOVERY KIT PDF — Settings › Vault security › Recovery kit (screen 33)
/// ============================================================
///
/// [RecoveryKitPdf.build] lays out a one-page A4 PDF (pdf package, built-in
/// Helvetica / Courier, so no font files and no network): what the kit is,
/// the recovery code in large monospace groups, when it was made, and how
/// to use it ("Forgot PIN?" on the vault lock screen). [RecoveryKitShare]
/// writes it to the temporary directory, hands it to the share sheet
/// (share_plus: print, save to Files, AirDrop…) and deletes the file right
/// after so the code does not linger on disk. The code is never logged.
/// ============================================================
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:focusflow/core/constants/app_info.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

abstract final class RecoveryKitPdf {
  /// File name of the shared kit.
  static String fileName(DateTime createdAt) =>
      '${AppInfo.name}-Recovery-Kit-'
      '${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)}.pdf';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// The PDF bytes for [code] (formatted `ABCD-EFGH-…`).
  static Future<Uint8List> build({
    required String code,
    required DateTime createdAt,
  }) {
    // PDF ink: fixed print colours (paper is always white).
    const ink = PdfColor.fromInt(0xFF064E3B);
    const muted = PdfColor.fromInt(0xFF475569);
    const accent = PdfColor.fromInt(0xFF10B981);
    const panel = PdfColor.fromInt(0xFFECFDF5);
    final groups = code.split('-');
    final lines = <String>[
      for (var i = 0; i < groups.length; i += 4)
        groups.skip(i).take(4).join('  '),
    ];
    final made =
        '${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)} '
        '${_two(createdAt.hour)}:${_two(createdAt.minute)}';
    final doc = pw.Document(
      title: '${AppInfo.name} Recovery Kit',
      author: AppInfo.name,
      creator: AppInfo.name,
    );
    pw.Widget para(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 11, color: muted, lineSpacing: 3),
      ),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 40, height: 4, color: accent),
            pw.SizedBox(height: 16),
            pw.Text(
              '${AppInfo.name} Vault Recovery Kit',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Created $made',
              style: const pw.TextStyle(fontSize: 11, color: muted),
            ),
            pw.SizedBox(height: 28),
            para(
              'If you forget your master PIN, this code is the only way to '
              'open your vault. Your passwords are encrypted on your device '
              '(AES-256-GCM, key derived with Argon2id); nobody, including '
              'us, can reset the PIN for you.',
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              decoration: const pw.BoxDecoration(
                color: panel,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RECOVERY CODE',
                    style: pw.TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: pw.FontWeight.bold,
                      color: muted,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  for (final l in lines)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        l,
                        style: pw.TextStyle(
                          font: pw.Font.courierBold(),
                          fontSize: 20,
                          color: ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'How to use it',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.SizedBox(height: 8),
            para('1. Open the Vault and tap "Forgot PIN?" on the lock screen.'),
            para('2. Enter this code, then choose a new master PIN.'),
            para(
              '3. Make a new Recovery Kit afterwards. Creating a kit '
              'replaces the previous code, so older kits stop working.',
            ),
            pw.Spacer(),
            pw.Divider(color: muted, thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Text(
              'Print this page or store it somewhere safe and offline. '
              'Anyone with this code and your device can open your vault.',
              style: const pw.TextStyle(fontSize: 9, color: muted),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}

/// Writes the kit to a temporary file and opens the share sheet. The file
/// is NOT deleted as soon as the sheet returns on Android: the receiving
/// app (Drive, mail …) may read the content URI later. It is deleted after
/// [keepFor] while the app runs, and stale kits are removed on the next
/// launch ([cleanUpStale]). iOS copies the file during the share, so it is
/// deleted right away there.
class RecoveryKitShare {
  const RecoveryKitShare();

  static const Duration keepFor = Duration(minutes: 10);

  static Future<Directory> _dir() async =>
      Directory(p.join((await getTemporaryDirectory()).path, 'recovery'));

  /// Deletes kits older than [maxAge] (all of them with [Duration.zero]).
  /// Never throws.
  static Future<void> cleanUpStale({Duration maxAge = keepFor}) async {
    try {
      final dir = await _dir();
      if (!dir.existsSync()) return;
      final cutoff = DateTime.now().subtract(maxAge);
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.lastModifiedSync().isAfter(cutoff)) await f.delete();
      }
    } on Object {
      // No temp dir (tests) / already gone: the OS clears it eventually.
    }
  }

  /// False when the user dismissed the share sheet.
  Future<bool> share(Uint8List pdf, {required String fileName}) async {
    await cleanUpStale();
    final dir = await _dir();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    try {
      await file.writeAsBytes(pdf, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: '${AppInfo.name} Recovery Kit',
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    } finally {
      if (Platform.isIOS) {
        await _delete(file);
      } else {
        Timer(keepFor, () => unawaited(_delete(file)));
      }
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Best effort: the OS clears the temporary directory eventually.
    }
  }
}

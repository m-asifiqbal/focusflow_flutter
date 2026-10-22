/// ============================================================
/// PASSWORD IMPORTERS — Bitwarden CSV, 1Password CSV
/// ============================================================
///
/// What: password-manager CSV exports → [ImportedLogin]s.
/// * Bitwarden: folder, favorite, type, name, notes, login_uri,
///   login_username, login_password, login_totp (only `login` rows;
///   secure notes / cards / identities are reported as skipped).
/// * 1Password (8 and 7): Title, Url/Website, Username, Password,
///   OTPAuth, Favorite, Archived, Tags, Notes.
/// Why: the logins are plaintext only in memory; the writer hands them
/// straight to the vault bridge, which encrypts each one with the
/// unlocked vault session (never stored or logged in the clear). The
/// picked file is a temporary copy that the caller deletes afterwards.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/csv_codec.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_parsing.dart';

abstract final class PasswordImporters {
  static bool isBitwarden(Set<String> h) =>
      h.contains('login_password') && h.contains('name');

  static bool isOnePassword(Set<String> h) =>
      h.contains('password') &&
      h.contains('title') &&
      (h.contains('url') || h.contains('website') || h.contains('otpauth'));

  static ImportBundle bitwarden(String text) {
    final rows = CsvCodec.decodeMaps(text);
    if (rows.isEmpty || !isBitwarden(rows.first.keys.toSet())) {
      throw ImportFormatException(tr('This is not a Bitwarden CSV export.'));
    }
    final logins = <ImportedLogin>[];
    var skipped = 0;
    for (final r in rows) {
      final type = (r['type'] ?? 'login').trim().toLowerCase();
      final name = (r['name'] ?? '').trim();
      if (type != 'login' || name.isEmpty) {
        skipped++;
        continue;
      }
      logins.add(
        ImportedLogin(
          title: name,
          username: r['login_username'] ?? '',
          password: r['login_password'] ?? '',
          url: (r['login_uri'] ?? '').split(',').first.trim(),
          notes: r['notes'] ?? '',
          totpSecret: _blankToNull(r['login_totp']),
          folder: _blankToNull(r['folder']),
          isFavorite: ImportParsing.boolean(r['favorite']),
        ),
      );
    }
    return ImportBundle(
      source: ImportSource.bitwarden,
      logins: logins,
      problems: [
        if (skipped > 0)
          ImportProblem(
            tr('{count} non-login entries left out', {'count': skipped}),
          ),
      ],
    );
  }

  static ImportBundle onePassword(String text) {
    final rows = CsvCodec.decodeMaps(text);
    if (rows.isEmpty || !isOnePassword(rows.first.keys.toSet())) {
      throw ImportFormatException(tr('This is not a 1Password CSV export.'));
    }
    final logins = <ImportedLogin>[];
    var skipped = 0;
    for (final r in rows) {
      final title = (r['title'] ?? '').trim();
      if (title.isEmpty || ImportParsing.boolean(r['archived'])) {
        skipped++;
        continue;
      }
      logins.add(
        ImportedLogin(
          title: title,
          username: r['username'] ?? '',
          password: r['password'] ?? '',
          url: (r['url'] ?? r['website'] ?? '').trim(),
          notes: r['notes'] ?? r['notesplain'] ?? '',
          totpSecret: _blankToNull(r['otpauth']),
          folder: ImportParsing.tags(r['tags']).firstOrNull,
          isFavorite: ImportParsing.boolean(r['favorite']),
        ),
      );
    }
    return ImportBundle(
      source: ImportSource.onePassword,
      logins: logins,
      problems: [
        if (skipped > 0)
          ImportProblem(
            tr('{count} archived or empty entries', {'count': skipped}),
          ),
      ],
    );
  }

  static String? _blankToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}

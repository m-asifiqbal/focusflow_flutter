/// ============================================================
/// tr() — translate a user-facing string
/// ============================================================
///
/// ```dart
/// Text(tr('Archive'))
/// Text(tr('{n} tasks overdue', {'n': count}))
/// Text(tr('{count, plural, one {# note} other {# notes}}', {'count': n}))
/// ```
/// The English text *is* the key and the fallback; the first argument must
/// be a string literal so `tool/l10n` can find it for the packs (a label held
/// in a const list is registered in static_keys.dart and translated where it
/// is shown: `tr(entry.label)`). Works anywhere — widgets, notifications,
/// domain code — see l10n.dart.
/// ============================================================
library;

import 'package:focusflow/core/l10n/l10n.dart';

export 'package:focusflow/core/l10n/l10n.dart' show L10n;

/// [key] (the English text) in the active language, with [args] filled in.
String tr(String key, [Map<String, Object?>? args]) =>
    L10n.translate(key, args);

/// [tr] for text printed into a PDF with Latin-only fonts: English when the
/// active language's script cannot be drawn (see AppLanguage.printable). The
/// catalogue treats it exactly like `tr`.
String trPrint(String key, [Map<String, Object?>? args]) =>
    L10n.translatePrint(key, args);

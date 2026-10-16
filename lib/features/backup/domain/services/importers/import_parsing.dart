/// ============================================================
/// IMPORT PARSING — small shared helpers for the importers
/// ============================================================
///
/// What: lenient date / day / bool / tag-list parsing used by every
/// importer.
/// Why: other apps write dates many ways (ISO, `yyyy-MM-dd`, Evernote's
/// `20200101T120000Z`, microsecond epochs); one helper keeps the parsers
/// short and consistent.
/// ============================================================
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:focusflow/core/utils/date_utils.dart';

abstract final class ImportParsing {
  static final _compact = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$',
  );
  static final _day = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');

  /// A date/time in local time, or null.
  static DateTime? dateTime(Object? v) {
    if (v == null) return null;
    if (v is int) {
      // Seconds, milliseconds or microseconds since the epoch.
      if (v > 100000000000000) {
        return DateTime.fromMicrosecondsSinceEpoch(v);
      }
      if (v > 100000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    final s = '$v'.trim();
    if (s.isEmpty) return null;
    final c = _compact.firstMatch(s);
    if (c != null) {
      final g = [for (var i = 1; i <= 6; i++) int.parse(c.group(i)!)];
      return DateTime.utc(g[0], g[1], g[2], g[3], g[4], g[5]).toLocal();
    }
    final asInt = int.tryParse(s);
    if (asInt != null) return dateTime(asInt);
    final d = _day.firstMatch(s);
    if (d != null) {
      return DateTime(
        int.parse(d.group(1)!),
        int.parse(d.group(2)!),
        int.parse(d.group(3)!),
      );
    }
    return DateTime.tryParse(s)?.toLocal();
  }

  /// The calendar day of [v] (local midnight), or null.
  static DateTime? day(Object? v) {
    final s = '${v ?? ''}'.trim();
    final d = _day.firstMatch(s.length >= 10 ? s.substring(0, 10) : s);
    if (d != null) {
      return DateTime(
        int.parse(d.group(1)!),
        int.parse(d.group(2)!),
        int.parse(d.group(3)!),
      );
    }
    final t = dateTime(v);
    return t == null ? null : DateUtilsX.dateOnly(t);
  }

  /// `HH:mm` → minutes after midnight.
  static int? minutes(Object? v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${v ?? ''}'.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  static bool boolean(Object? v) {
    final s = '${v ?? ''}'.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'y';
  }

  /// "a; b, c" → [a, b, c].
  static List<String> tags(Object? v) {
    if (v is List) {
      return [
        for (final t in v)
          if ('$t'.trim().isNotEmpty) '$t'.trim(),
      ];
    }
    return '${v ?? ''}'
        .split(RegExp('[;,]'))
        .map((t) => t.trim().replaceFirst(RegExp('^#'), ''))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// UTF-8 text of [bytes] (malformed sequences replaced).
  static String text(List<int> bytes) =>
      utf8.decode(bytes, allowMalformed: true);

  /// The zip in [bytes], or null when it isn't one.
  static Archive? zip(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      return null;
    }
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return null;
    }
  }
}

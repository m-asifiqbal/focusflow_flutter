/// ============================================================
/// MEDICINE IMPORTER — medicines of a FocusFlow JSON / CSV export
/// ============================================================
///
/// What: turns one exported medicine (a JSON object, or a CSV row whose
/// keys were mapped back to the JSON names) into an [ImportedMedicine]:
/// dose times from `times` ("08:00×1; 20:00×0.5"), logged doses from the
/// JSON `doses` list or the CSV `takenDoses` column ("2026-10-23 08:00;
/// 2026-10-23 20:00").
/// Why: exports must round-trip; everything is parsed leniently (a hand-
/// edited file never crashes the import — bad pieces are just dropped).
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_parsing.dart';

abstract final class MedicineImporter {
  static ImportedMedicine fromMap(Map r) {
    int n(String k, int d) => int.tryParse('${r[k] ?? ''}') ?? d;
    double? real(String k) => double.tryParse('${r[k] ?? ''}');
    String s(String k, String d) {
      final v = '${r[k] ?? ''}'.trim();
      return v.isEmpty || v == 'null' ? d : v;
    }

    return ImportedMedicine(
      name: s('name', ''),
      strength: s('strength', ''),
      form: s('form', 'tablet'),
      food: s('food', 'any'),
      schedule: s('schedule', 'everyDay'),
      weekdaysMask: n('weekdaysMask', 127),
      everyNDays: n('everyNDays', 2),
      times: times('${r['times'] ?? ''}'),
      startDate: ImportParsing.day(r['startDate']),
      endDate: ImportParsing.day(r['endDate']),
      stockLeft: real('stockLeft'),
      refillAt: real('refillAt'),
      note: s('note', ''),
      paused: r['paused'] == true || ImportParsing.boolean(r['paused']),
      doses: r['doses'] is List
          ? _jsonDoses(r['doses'] as List)
          : _csvDoses('${r['takenDoses'] ?? ''}'),
      createdAt: ImportParsing.dateTime(r['created']),
    );
  }

  /// `08:00×1; 20:00×0.5` (also `08:00x1`, or plain `08:00, 20:00`).
  static List<(int, double)> times(String s) {
    final out = <(int, double)>[];
    for (final part in s.split(RegExp(r'[;,]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final bits = p.split(RegExp(r'[×xX*]'));
      final m = ImportParsing.minutes(bits.first.trim());
      if (m == null) continue;
      final q = bits.length > 1 ? double.tryParse(bits[1].trim()) : null;
      out.add((m, q != null && q > 0 ? q : 1));
    }
    return out;
  }

  static List<
    ({String day, int minutes, bool taken, double quantity, DateTime? at})
  >
  _jsonDoses(List list) => [
    for (final d in list.whereType<Map>())
      if (ImportParsing.day(d['date']) != null &&
          ImportParsing.minutes(d['time']) != null)
        (
          day: DateUtilsX.dayKey(ImportParsing.day(d['date'])!),
          minutes: ImportParsing.minutes(d['time'])!,
          taken: d['status'] != 'skipped',
          quantity: d['quantity'] is num
              ? (d['quantity'] as num).toDouble()
              : 1,
          at: ImportParsing.dateTime(d['at']),
        ),
  ];

  static List<
    ({String day, int minutes, bool taken, double quantity, DateTime? at})
  >
  _csvDoses(String s) => [
    for (final part in s.split(';'))
      if (part.trim().split(' ') case [final day, final time]
          when ImportParsing.day(day) != null &&
              ImportParsing.minutes(time) != null)
        (
          day: DateUtilsX.dayKey(ImportParsing.day(day)!),
          minutes: ImportParsing.minutes(time)!,
          taken: true,
          quantity: 1,
          at: null,
        ),
  ];
}

/// ============================================================
/// MAINTENANCE — housekeeping (trash purge, abandoned blank notes)
/// ============================================================
///
/// Recently Deleted keeps items for 30 days, then they are removed for good
/// (screen 24). Runs at most once per day: on launch/resume here, and from
/// the background maintenance job (core/sync/background_tasks.dart).
///
/// Blank notes: `/notes/new` inserts the row immediately; if the app is
/// killed before the editor discards an untouched note, an empty "Untitled"
/// note would stay forever. The first run of each process (= app launch,
/// before any editor can have been open for an hour) removes blank notes
/// untouched for [blankNoteAge] — see ItemsRepository.purgeBlankNotes for
/// the (deliberately strict) definition of "blank".
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Maintenance {
  Maintenance(this._items, this._prefs, this._clock);

  final ItemsRepository _items;
  final SharedPreferences _prefs;
  final Clock _clock;

  static const String _lastRunKey = 'maintenance_last_run';

  /// How long a blank note must be untouched before it is swept.
  static const Duration blankNoteAge = Duration(hours: 1);

  bool _sweptBlankNotes = false;

  Future<void> runIfDue() async {
    if (!_sweptBlankNotes) {
      _sweptBlankNotes = true;
      try {
        final blank = await _items.purgeBlankNotes(olderThan: blankNoteAge);
        if (blank > 0) AppLogger.i('Maintenance: removed $blank blank notes');
      } catch (e) {
        // Never block the trash purge below.
        AppLogger.w('Maintenance: blank-note sweep failed: ${e.runtimeType}');
      }
    }
    final now = _clock.now();
    final last = DateTime.tryParse(_prefs.getString(_lastRunKey) ?? '');
    if (last != null && now.difference(last) < const Duration(hours: 20)) {
      return;
    }
    final purged = await _items.purgeExpired();
    if (purged > 0) AppLogger.i('Maintenance: purged $purged expired items');
    await _prefs.setString(_lastRunKey, now.toIso8601String());
  }
}

final maintenanceProvider = Provider<Maintenance>(
  (ref) => Maintenance(
    ref.watch(itemsRepositoryProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(clockProvider),
  ),
);

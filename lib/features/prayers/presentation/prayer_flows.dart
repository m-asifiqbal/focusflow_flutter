/// ============================================================
/// PRAYER FLOWS — what the Prayer screens do when tapped
/// ============================================================
///
/// What: mark a prayer (on time inside its window, late after it) with an
/// Undo snackbar; set any status / place / congregation; count dhikr;
/// save the setup picker's prayers; and the location flows — explain then
/// ask for the precise location, fall back to a city, and the "you moved"
/// check.
/// Why: widgets stay layout-only (CLAUDE.md rule 5); every write goes
/// through the repository / settings, and the live streams redraw.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/prayer_prefs.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/data/location/prayer_locator.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/domain/services/world_cities.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_log_sheet.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Tap on a prayer (Prayer page or Home): the log sheet — status, place,
/// congregation — then saves, clears or opens the editor.
Future<void> openPrayerLog(
  BuildContext context,
  WidgetRef ref,
  PrayerSlot slot,
) async {
  final now = ref.read(clockProvider).now();
  final use24h = ref.read(settingsProvider).use24HourTime;
  final choice = await showPrayerLogSheet(
    context,
    slot: slot,
    now: now,
    use24h: use24h,
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case PrayerLogSave(:final status, :final place, :final congregation):
      await markPrayer(
        context,
        ref,
        slot,
        status: status,
        place: place,
        congregation: congregation,
      );
    case PrayerLogClear():
      await clearPrayerMark(context, ref, slot);
    case PrayerLogEdit():
      unawaited(context.push(AppRoutes.prayerEdit(slot.prayer.id)));
  }
}

/// Moving this far from the saved location offers new prayer times.
const double kPrayerTravelKm = 25;

/// Marks [slot] (default: on time inside its window, late after it) and
/// offers Undo.
Future<void> markPrayer(
  BuildContext context,
  WidgetRef ref,
  PrayerSlot slot, {
  PrayerStatus? status,
  String? place,
  bool? congregation,
}) async {
  final repo = ref.read(prayersRepositoryProvider);
  final now = ref.read(clockProvider).now();
  final previous = slot.log;
  final value = status ?? slot.markAt(now);
  await repo.mark(
    slot.prayer.id,
    slot.day,
    value,
    place: place,
    congregation: congregation,
  );
  if (ref.read(settingsProvider).hapticsEnabled) {
    unawaited(HapticFeedback.lightImpact());
  }
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('{name}: {status}', {
      'name': slot.prayer.displayName,
      'status': value.labelFor(slot.prayer.kind),
    }),
    icon: FontAwesomeIcons.solidCircleCheck,
    onUndo: () =>
        unawaited(repo.restoreLog(slot.prayer.id, slot.day, previous)),
  );
}

/// Back to "not marked", with Undo.
Future<void> clearPrayerMark(
  BuildContext context,
  WidgetRef ref,
  PrayerSlot slot,
) async {
  final repo = ref.read(prayersRepositoryProvider);
  final previous = slot.log;
  if (previous == null) return;
  await repo.restoreLog(slot.prayer.id, slot.day, null);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('{name}: mark cleared', {'name': slot.prayer.displayName}),
    icon: FontAwesomeIcons.rotateLeft,
    onUndo: () =>
        unawaited(repo.restoreLog(slot.prayer.id, slot.day, previous)),
  );
}

/// One tap of a counting practice (+1, or −1 to correct).
Future<void> countPrayer(WidgetRef ref, PrayerSlot slot, int delta) async {
  final count = await ref
      .read(prayersRepositoryProvider)
      .addCount(
        slot.prayer.id,
        slot.day,
        delta,
        target: slot.prayer.targetCount,
      );
  final target = slot.prayer.targetCount;
  if (!ref.read(settingsProvider).hapticsEnabled) return;
  // A firmer tick when the goal is reached.
  unawaited(
    target != null && count == target
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.selectionClick(),
  );
}

/// Saves the setup picker: the ticked [drafts] (fixed times when [manual]),
/// and the tradition.
Future<void> savePrayerSetup(
  WidgetRef ref,
  PrayerTradition tradition,
  List<Prayer> drafts, {
  required bool manual,
  PrayerSchool? school,
}) async {
  final prayers = manual ? PrayerPresets.manual(drafts) : drafts;
  if (prayers.isNotEmpty) {
    await ref.read(prayersRepositoryProvider).addAll(prayers);
  }
  await ref
      .read(settingsProvider.notifier)
      .update(
        (s) => s.copyWith(
          prayer: _withSchool(
            s.prayer.copyWith(tradition: tradition.key),
            tradition,
            school,
          ),
        ),
      );
}

/// Remembers the school chosen for [tradition] (null = skipped / cleared).
/// A Muslim's choice also sets the Asr time: the Hanafi shadow, or the
/// standard one for every other school.
Future<void> savePrayerSchool(
  WidgetRef ref,
  PrayerTradition tradition,
  PrayerSchool? school,
) => ref
    .read(settingsProvider.notifier)
    .update(
      (s) => s.copyWith(prayer: _withSchool(s.prayer, tradition, school)),
    );

PrayerPrefs _withSchool(
  PrayerPrefs prefs,
  PrayerTradition tradition,
  PrayerSchool? school,
) {
  final schools = {...prefs.schools};
  if (school == null) {
    schools.remove(tradition.key);
  } else {
    schools[tradition.key] = school.key;
  }
  final asr = tradition == PrayerTradition.islam && school != null
      ? (school == PrayerSchool.hanafi ? 'hanafi' : 'standard')
      : null;
  return prefs.copyWith(schools: schools, asrSchool: asr);
}

/// A label for coordinates: "Near Dhaka" (nearest bundled city), else the
/// rounded coordinates. Offline — no geocoder.
String prayerPlaceLabel(GeoPoint p) {
  final near = WorldCities.nearest(p);
  if (near != null) {
    return tr('Near {city}', {'city': near.city.name});
  }
  final lat = p.latitude.abs().toStringAsFixed(2);
  final lng = p.longitude.abs().toStringAsFixed(2);
  return '$lat° ${p.latitude >= 0 ? 'N' : 'S'}, '
      '$lng° ${p.longitude >= 0 ? 'E' : 'W'}';
}

/// Saves [point] as the prayer location.
Future<void> savePrayerLocation(
  WidgetRef ref,
  GeoPoint point, {
  required String label,
  required bool precise,
}) => ref
    .read(settingsProvider.notifier)
    .update(
      (s) => s.copyWith(
        prayer: s.prayer.copyWith(
          latitude: point.latitude,
          longitude: point.longitude,
          placeLabel: label,
          precise: precise,
          locatedAt: ref.read(clockProvider).now(),
        ),
      ),
    );

/// Reads the device location (after the explanation sheet said why) and
/// saves it. Returns the outcome so the caller can offer the city search
/// or the settings page.
Future<LocateOutcome> locatePrayerPlace(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await ref.read(prayerLocatorProvider).locate();
  final point = result.point;
  if (result.outcome == LocateOutcome.ok && point != null) {
    await savePrayerLocation(
      ref,
      point,
      label: prayerPlaceLabel(point),
      precise: result.precise,
    );
    if (context.mounted) {
      showFFToast(
        context,
        tr('Prayer times set for {place}', {'place': prayerPlaceLabel(point)}),
        icon: FontAwesomeIcons.locationCrosshairs,
      );
    }
  }
  return result.outcome;
}

/// "You seem to be in a new place": the current position when it is more
/// than [kPrayerTravelKm] from the saved one (never prompts; null when
/// permission is off, no fix, or not moved).
Future<GeoPoint?> prayerTravelCheck(WidgetRef ref) async {
  final prefs = ref.read(settingsProvider).prayer;
  final lat = prefs.latitude;
  final lng = prefs.longitude;
  if (lat == null || lng == null) return null;
  final here = await ref.read(prayerLocatorProvider).peek();
  if (here == null) return null;
  return here.distanceKm(GeoPoint(lat, lng)) > kPrayerTravelKm ? here : null;
}

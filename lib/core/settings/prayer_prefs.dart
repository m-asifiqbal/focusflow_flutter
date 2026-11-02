/// ============================================================
/// PRAYER PREFS — location and calculation choices of the Prayer module
/// ============================================================
///
/// What: where the user is (for sun-based prayer windows), how the times are
/// calculated (method, Asr school, high-latitude rule), the Hijri date
/// correction, whether Prayer has its own tab, the tradition chosen in
/// the first-run picker (null = Prayer not set up yet) and the school /
/// denomination picked for each tradition (all optional).
/// Why: one value object inside [AppSettings] (key `prayer`), so it is saved,
/// backed up and synced with the rest of the settings. Enum choices are kept
/// as their names (the calculation enums live in the prayers feature,
/// `prayer_times.dart`) — an unknown name falls back to the default there.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

@immutable
class PrayerPrefs {
  const PrayerPrefs({
    this.latitude,
    this.longitude,
    this.placeLabel = '',
    this.precise = false,
    this.locatedAt,
    this.method,
    this.asrSchool = 'standard',
    this.highLatitudeRule = 'angleBased',
    this.hijriAdjust = 0,
    this.tradition,
    this.schools = const {},
    this.notify = true,
    this.discreet = true,
    this.shabbatQuiet = false,
    this.inIsrael = false,
  });

  /// Saved location; both null = none yet (sun-based times then use each
  /// rule's fallback time).
  final double? latitude;
  final double? longitude;

  /// "Near Dhaka" / "Dhaka, Bangladesh" — shown, never used for maths.
  final String placeLabel;

  /// The location came from the device's precise (fine) location.
  final bool precise;
  final DateTime? locatedAt;

  /// PrayerCalcMethod name; null = suggested for the location.
  final String? method;

  /// AsrSchool name (`standard` / `hanafi`).
  final String asrSchool;

  /// HighLatitudeRule name.
  final String highLatitudeRule;

  /// Hijri date correction in days (−2…2) for local moon sighting.
  final int hijriAdjust;

  /// PrayerTradition key picked at setup; null = not set up.
  final String? tradition;

  /// The school / denomination / movement chosen per tradition (tradition
  /// key → PrayerSchool key); a tradition without an entry was skipped.
  final Map<String, String> schools;

  /// Prayer reminders on (Settings › Notifications).
  final bool notify;

  /// Lock-screen / notification text names the prayer only, without the
  /// tradition's words ("Prayer time" instead of "Time for Asr").
  final bool discreet;

  /// Judaism: no Prayer notifications on Shabbat and Yom Tov.
  final bool shabbatQuiet;

  /// Yom Tov is kept one day (Israel) rather than two (elsewhere).
  final bool inIsrael;

  bool get hasLocation => latitude != null && longitude != null;
  bool get isSetUp => tradition != null;

  /// The PrayerSchool key chosen for the tradition [key] (null = skipped).
  String? schoolOf(String key) => schools[key];

  PrayerPrefs copyWith({
    double? latitude,
    double? longitude,
    String? placeLabel,
    bool? precise,
    DateTime? locatedAt,
    String? method,
    bool clearMethod = false,
    String? asrSchool,
    String? highLatitudeRule,
    int? hijriAdjust,
    String? tradition,
    Map<String, String>? schools,
    bool? notify,
    bool? discreet,
    bool? shabbatQuiet,
    bool? inIsrael,
  }) => PrayerPrefs(
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    placeLabel: placeLabel ?? this.placeLabel,
    precise: precise ?? this.precise,
    locatedAt: locatedAt ?? this.locatedAt,
    method: clearMethod ? null : (method ?? this.method),
    asrSchool: asrSchool ?? this.asrSchool,
    highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
    hijriAdjust: hijriAdjust ?? this.hijriAdjust,
    tradition: tradition ?? this.tradition,
    schools: schools ?? this.schools,
    notify: notify ?? this.notify,
    discreet: discreet ?? this.discreet,
    shabbatQuiet: shabbatQuiet ?? this.shabbatQuiet,
    inIsrael: inIsrael ?? this.inIsrael,
  );

  Map<String, Object?> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'label': placeLabel,
    'precise': precise,
    'locatedAt': locatedAt?.toUtc().toIso8601String(),
    'method': method,
    'asr': asrSchool,
    'highLat': highLatitudeRule,
    'hijri': hijriAdjust,
    'tradition': tradition,
    if (schools.isNotEmpty) 'schools': schools,
    'notify': notify,
    'discreet': discreet,
    if (shabbatQuiet) 'shabbatQuiet': true,
    if (inIsrael) 'inIsrael': true,
  };

  /// Lenient: wrong or missing values take their defaults.
  factory PrayerPrefs.fromJson(Object? raw) {
    if (raw is! Map) return const PrayerPrefs();
    double? d(String k) {
      final v = raw[k];
      return v is num && v.isFinite ? v.toDouble() : null;
    }

    String? s(String k) => raw[k] is String ? raw[k] as String : null;
    bool b(String k, bool f) => raw[k] is bool ? raw[k] as bool : f;
    final lat = d('lat');
    final lng = d('lng');
    final valid =
        lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
    final hijri = raw['hijri'];
    final rawSchools = raw['schools'];
    return PrayerPrefs(
      latitude: valid ? lat : null,
      longitude: valid ? lng : null,
      placeLabel: s('label') ?? '',
      precise: b('precise', false),
      locatedAt: s('locatedAt') == null
          ? null
          : DateTime.tryParse(s('locatedAt')!)?.toLocal(),
      method: s('method'),
      asrSchool: s('asr') ?? 'standard',
      highLatitudeRule: s('highLat') ?? 'angleBased',
      hijriAdjust: hijri is num ? hijri.toInt().clamp(-2, 2) : 0,
      tradition: s('tradition'),
      schools: rawSchools is Map
          ? {
              for (final e in rawSchools.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
      notify: b('notify', true),
      discreet: b('discreet', true),
      shabbatQuiet: b('shabbatQuiet', false),
      inIsrael: b('inIsrael', false),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerPrefs &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.placeLabel == placeLabel &&
      other.precise == precise &&
      other.locatedAt == locatedAt &&
      other.method == method &&
      other.asrSchool == asrSchool &&
      other.highLatitudeRule == highLatitudeRule &&
      other.hijriAdjust == hijriAdjust &&
      other.tradition == tradition &&
      mapEquals(other.schools, schools) &&
      other.notify == notify &&
      other.discreet == discreet &&
      other.shabbatQuiet == shabbatQuiet &&
      other.inIsrael == inIsrael;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    placeLabel,
    precise,
    locatedAt,
    method,
    asrSchool,
    highLatitudeRule,
    hijriAdjust,
    tradition,
    Object.hashAll(schools.entries.map((e) => (e.key, e.value))),
    notify,
    discreet,
    shabbatQuiet,
    inIsrael,
  );
}

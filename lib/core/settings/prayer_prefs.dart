/// ============================================================
/// PRAYER PREFS — location and calculation choices of the Prayer module
/// ============================================================
///
/// What: where the user is (for sun-based prayer windows), how the times are
/// calculated (method, Asr school, high-latitude rule), the Hijri date
/// correction, whether Prayer has its own tab, and the tradition chosen in
/// the first-run picker (null = Prayer not set up yet).
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
    this.showTab = false,
    this.tradition,
    this.notify = true,
    this.discreet = true,
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

  /// Prayer is a tab of the bottom bar (else it lives in Library).
  final bool showTab;

  /// PrayerTradition key picked at setup; null = not set up.
  final String? tradition;

  /// Prayer reminders on (Settings › Notifications).
  final bool notify;

  /// Lock-screen / notification text names the prayer only, without the
  /// tradition's words ("Prayer time" instead of "Time for Asr").
  final bool discreet;

  bool get hasLocation => latitude != null && longitude != null;
  bool get isSetUp => tradition != null;

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
    bool? showTab,
    String? tradition,
    bool? notify,
    bool? discreet,
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
    showTab: showTab ?? this.showTab,
    tradition: tradition ?? this.tradition,
    notify: notify ?? this.notify,
    discreet: discreet ?? this.discreet,
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
    'tab': showTab,
    'tradition': tradition,
    'notify': notify,
    'discreet': discreet,
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
      showTab: b('tab', false),
      tradition: s('tradition'),
      notify: b('notify', true),
      discreet: b('discreet', true),
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
      other.showTab == showTab &&
      other.tradition == tradition &&
      other.notify == notify &&
      other.discreet == discreet;

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
    showTab,
    tradition,
    notify,
    discreet,
  );
}

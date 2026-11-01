/// ============================================================
/// PRAYER LOCATOR — the device's position, once, when the user asks
/// ============================================================
///
/// What: [PrayerLocator.locate] asks for "while using the app" location
/// (precise preferred — Android 12+ / iOS 14+ may grant approximate only),
/// reads one position and reports whether it was precise; [peek] reads one
/// position only when permission was already given (the "you moved" check
/// — never a prompt); [openAppSettings] / [openLocationSettings] for the
/// "Don't ask again" and "location off" cases.
/// Why: the only location code of the app, behind an interface so tests
/// and the UI never touch the platform. No background location, no
/// position stream, nothing stored here or sent anywhere — the caller keeps
/// the coordinates in the settings and computes prayer times on the phone.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:geolocator/geolocator.dart';

/// How a location request ended.
enum LocateOutcome {
  ok,

  /// The user said no (ask again next time).
  denied,

  /// "Don't ask again": only the app's settings page can change it.
  deniedForever,

  /// Location services are switched off on the phone.
  serviceOff,

  /// No position in time (indoors, no fix) or a platform error.
  failed,
}

/// The result of [PrayerLocator.locate].
typedef LocateResult = ({LocateOutcome outcome, GeoPoint? point, bool precise});

abstract interface class PrayerLocator {
  /// Asks for permission when needed and reads one position.
  Future<LocateResult> locate();

  /// One position without any prompt (null when not allowed or no fix).
  Future<GeoPoint?> peek();

  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// The geolocator implementation.
class DevicePrayerLocator implements PrayerLocator {
  const DevicePrayerLocator();

  static const Duration _timeout = Duration(seconds: 20);

  static GeoPoint _point(Position p) => GeoPoint(p.latitude, p.longitude);

  @override
  Future<LocateResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (outcome: LocateOutcome.serviceOff, point: null, precise: false);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return (outcome: LocateOutcome.denied, point: null, precise: false);
        case LocationPermission.deniedForever:
          return (
            outcome: LocateOutcome.deniedForever,
            point: null,
            precise: false,
          );
        case LocationPermission.whileInUse ||
            LocationPermission.always ||
            LocationPermission.unableToDetermine:
          break;
      }
      final precise = await _isPrecise();
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: _timeout,
          ),
        );
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        return (outcome: LocateOutcome.failed, point: null, precise: false);
      }
      return (
        outcome: LocateOutcome.ok,
        point: _point(position),
        precise: precise,
      );
    } catch (e) {
      // Never the coordinates in a log line — only what went wrong.
      AppLogger.w('Location request failed: ${e.runtimeType}');
      return (outcome: LocateOutcome.failed, point: null, precise: false);
    }
  }

  static Future<bool> _isPrecise() async {
    try {
      return await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.precise;
    } catch (_) {
      // Older platforms have no "approximate" mode: always precise.
      return true;
    }
  }

  @override
  Future<GeoPoint?> peek() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return _point(last);
      final now = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _timeout,
        ),
      );
      return _point(now);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

final prayerLocatorProvider = Provider<PrayerLocator>(
  (ref) => const DevicePrayerLocator(),
);

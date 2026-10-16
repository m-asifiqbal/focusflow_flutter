/// ============================================================
/// ACCOUNT PROVIDERS — read models for Account & profile (screen 36)
/// ============================================================
///
/// * [accountStatsProvider] — live "Items · Best streak · Days active";
/// * [linkedDevicesProvider] — this device + the Drive manifest's devices
///   (Google accounts only); a Drive failure keeps this device and carries
///   a message so the screen can offer Retry;
/// * [deviceTimeZoneProvider] — the device's IANA zone (shown when the
///   Time zone setting follows the device);
/// * [profilePhotoProvider] — the optional local avatar picture.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/device_profile.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/auth/data/repository/account_activity_repository_impl.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The three numbers of the stats card.
@immutable
class AccountStats {
  const AccountStats({
    required this.items,
    required this.bestStreak,
    required this.daysActive,
  });

  final int items;
  final int bestStreak;
  final int daysActive;
}

/// Active items across the five spaces + library counts' best habit streak.
final _libraryCountsProvider = StreamProvider.autoDispose<LibraryCounts>(
  (ref) => ref.watch(itemsRepositoryProvider).watchLibraryCounts(),
);

final _daysActiveProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(accountActivityRepositoryProvider).watchDaysActive(),
);

/// Live stats; loading until both streams have emitted.
final accountStatsProvider = Provider.autoDispose<AsyncValue<AccountStats>>((
  ref,
) {
  final counts = ref.watch(_libraryCountsProvider);
  final days = ref.watch(_daysActiveProvider);
  if (counts.hasError) return AsyncError(counts.error!, counts.stackTrace!);
  if (days.hasError) return AsyncError(days.error!, days.stackTrace!);
  final c = counts.valueOrNull;
  final d = days.valueOrNull;
  if (c == null || d == null) return const AsyncLoading();
  return AsyncData(
    AccountStats(
      items: c.totalItems,
      bestStreak: c.habitsBestStreak,
      daysActive: d,
    ),
  );
});

/// One row of LINKED DEVICES.
@immutable
class DeviceEntry {
  const DeviceEntry({
    required this.deviceId,
    required this.name,
    required this.platform,
    this.lastSyncAt,
    this.isThisDevice = false,
  });

  final String deviceId;
  final String name;

  /// "Android 15", "iOS 18" (may be empty off-device).
  final String platform;
  final DateTime? lastSyncAt;
  final bool isThisDevice;

  bool get isIos => platform.toLowerCase().startsWith('ios');
}

@immutable
class LinkedDevices {
  const LinkedDevices(this.devices, {this.cloudError});

  /// This device first, then the others by last sync (newest first).
  final List<DeviceEntry> devices;

  /// Why the Drive device list could not be read (offline, …), or null.
  final String? cloudError;
}

final linkedDevicesProvider = FutureProvider.autoDispose<LinkedDevices>((
  ref,
) async {
  final account = ref.watch(cloudAccountProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final me = await ref
      .watch(deviceProfileProvider.future)
      .catchError((Object _) => DeviceProfile.fallback);
  final self = DeviceEntry(
    deviceId: deviceId,
    name: me.name,
    platform: me.platform,
    isThisDevice: true,
  );
  if (account == null || !account.hasDrive) return LinkedDevices([self]);
  try {
    final remote = await ref.watch(driveSyncProvider).manifest();
    final others =
        [
          for (final d in remote.devices)
            if (d.deviceId != deviceId)
              DeviceEntry(
                deviceId: d.deviceId,
                name: d.name,
                platform: d.platform,
                lastSyncAt: d.lastSyncAt,
              ),
        ]..sort(
          (a, b) => (b.lastSyncAt ?? DateTime(0)).compareTo(
            a.lastSyncAt ?? DateTime(0),
          ),
        );
    return LinkedDevices([self, ...others]);
  } on DriveFailure catch (e) {
    return LinkedDevices([self], cloudError: _driveMessage(e.kind));
  } on Object {
    return LinkedDevices([self], cloudError: "Couldn't load your devices.");
  }
});

String _driveMessage(DriveFailureKind kind) => switch (kind) {
  DriveFailureKind.offline => "You're offline — other devices will show here.",
  DriveFailureKind.authExpired ||
  DriveFailureKind.notSignedIn => 'Sign in again to see your other devices.',
  _ => "Couldn't load your devices.",
};

/// The device's IANA time zone, e.g. "Asia/Dhaka".
final deviceTimeZoneProvider = FutureProvider<String>((ref) async {
  try {
    final zone = await ref.read(notificationGatewayProvider).deviceTimeZone();
    if (zone != null && zone.isNotEmpty) return zone;
  } on Object {
    // Fall through to the abbreviation.
  }
  return DateTime.now().timeZoneName;
});

/// Relative path of the local profile picture (never synced).
const String profilePhotoPath = 'profile/avatar.jpg';

/// The profile picture bytes, or null for the initial-letter avatar.
final profilePhotoProvider = FutureProvider.autoDispose<Uint8List?>((
  ref,
) async {
  try {
    return await ref.watch(appFilesProvider).read(profilePhotoPath);
  } on Object {
    return null;
  }
});

/// Every IANA zone name (sorted), for the Time zone picker.
final timeZoneNamesProvider = Provider<List<String>>((ref) {
  tzdata.initializeTimeZones();
  return tz.timeZoneDatabase.locations.keys
      .where((z) => z.contains('/') && !z.startsWith('Etc/'))
      .toList()
    ..sort();
});

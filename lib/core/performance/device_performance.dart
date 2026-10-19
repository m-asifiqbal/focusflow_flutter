/// ============================================================
/// DEVICE PERFORMANCE — is this a phone that needs lighter visuals?
/// ============================================================
///
/// What: a one-time read of what the phone can render smoothly (Android:
/// the "low RAM" flag, installed memory, OS version). It decides the
/// *Automatic* choice of Settings › Appearance › Visual effects: on a weak
/// phone the app drops the effects that cost the GPU the most (the frosted
/// blur behind the tab bar, the card-grows-into-page transition, animated
/// skeletons) and keeps everything else.
/// Why: the same screens run on a flagship and on a 2 GB budget phone;
/// real-time blur and full-page transitions are fine on the former and are
/// what drops frames on the latter. Read once at start-up (in parallel with
/// the other reads, never blocking it) so the first frame already has the
/// right look. iOS devices are all fast enough: never low-end there.
/// ============================================================
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/app_logger.dart';

@immutable
class DevicePerformance {
  const DevicePerformance({this.lowEnd = false});

  /// A weak phone: Automatic visual effects are reduced.
  final bool lowEnd;

  /// At or below this much installed memory (MB) a phone counts as low-end.
  /// Android reports a little less than the marketed size (a 3 GB phone
  /// shows ~2.7–2.9 GB), so 3072 catches the 3 GB class and below.
  static const int lowEndMemoryMb = 3072;

  /// Oldest Android release that still counts as capable (API 26, 8.0):
  /// below it the system compositor and drivers are the bottleneck.
  static const int minCapableSdk = 26;

  /// The rule, separate from the platform read so it is testable.
  static bool classify({
    required bool isLowRamDevice,
    required int physicalRamMb,
    required int sdkInt,
  }) =>
      isLowRamDevice ||
      sdkInt < minCapableSdk ||
      (physicalRamMb > 0 && physicalRamMb <= lowEndMemoryMb);

  /// Reads this device. Never throws and never waits long: anything unknown
  /// counts as capable (full effects), the setting can always override.
  static Future<DevicePerformance> detect({
    Duration timeout = const Duration(milliseconds: 400),
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const DevicePerformance();
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo.timeout(timeout);
      return DevicePerformance(
        lowEnd: classify(
          isLowRamDevice: info.isLowRamDevice,
          physicalRamMb: info.physicalRamSize,
          sdkInt: info.version.sdkInt,
        ),
      );
    } catch (e) {
      AppLogger.w('Device performance unknown: ${e.runtimeType}');
      return const DevicePerformance();
    }
  }
}

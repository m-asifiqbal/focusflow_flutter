/// ============================================================
/// DEVICE PROFILE — this device's name / OS for manifests (screen 36)
/// ============================================================
///
/// "Pixel 8 Pro · Android 15", "iPhone 15 · iOS 18". Resolved once via
/// device_info_plus / package_info_plus; every failure falls back to a
/// generic label (tests, desktop) instead of throwing.
/// ============================================================
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

@immutable
class DeviceProfile {
  const DeviceProfile({
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  /// Generic fallback used before / without device_info.
  static const fallback = DeviceProfile(
    name: 'This device',
    platform: '',
    appVersion: '',
  );

  final String name;
  final String platform;
  final String appVersion;

  bool get isIos => platform.toLowerCase().startsWith('ios');

  static Future<DeviceProfile> load() async {
    var name = 'This device';
    var platform = Platform.operatingSystem;
    var version = '';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        name = a.model;
        platform = 'Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        name = i.modelName.isNotEmpty ? i.modelName : i.model;
        platform = 'iOS ${i.systemVersion.split('.').first}';
      }
    } catch (_) {
      // Keep the fallback labels.
    }
    try {
      final pkg = await PackageInfo.fromPlatform();
      version = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {}
    return DeviceProfile(name: name, platform: platform, appVersion: version);
  }
}

/// Resolved lazily; screens show [DeviceProfile.fallback] while loading.
final deviceProfileProvider = FutureProvider<DeviceProfile>(
  (ref) => DeviceProfile.load(),
);

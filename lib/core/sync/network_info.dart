/// ============================================================
/// NETWORK INFO — online? on Wi-Fi? (connectivity_plus, no requests)
/// ============================================================
///
/// Used to fail fast with "You're offline" before touching Drive and to
/// honour "Wi-Fi only" for automatic Drive backups. Reads the OS's network
/// state only — it never contacts a server. Errors count as "online,
/// unknown type" so a plugin hiccup never blocks a manual sync.
/// ============================================================
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkInfo {
  const NetworkInfo();

  Future<List<ConnectivityResult>> _results() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (_) {
      return const [ConnectivityResult.other];
    }
  }

  Future<bool> isOnline() async =>
      (await _results()).any((r) => r != ConnectivityResult.none);

  /// Unmetered: Wi-Fi or Ethernet.
  Future<bool> isOnWifi() async => (await _results()).any(
    (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
  );
}

final networkInfoProvider = Provider<NetworkInfo>((ref) => const NetworkInfo());

/// ============================================================
/// BOOTSTRAP — everything that must be ready before the first frame
/// ============================================================
///
/// Resolves the few async singletons (prefs, DB key, device id, time zone)
/// once, then injects them into Riverpod with overrides — the Fresh LPG
/// pattern, so no provider ever has to be async just to read a preference.
/// Each step is defensive: a keystore or plugin hiccup must never leave the
/// user stuck on the native splash.
/// ============================================================
library;

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/app.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Extra overrides contributed by features that need async setup
/// (e.g. the notification service). Registered before [bootstrap] runs.
typedef BootstrapStep = Future<Override?> Function();

Future<void> bootstrap({List<BootstrapStep> steps = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.e(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    defaultOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Uncaught async error', error: error, stackTrace: stack);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  final secure = SecureStore();
  final dbKey = await secure.getOrCreateDatabaseKey();
  final deviceId = await _deviceId(prefs);

  final extra = <Override>[];
  for (final step in steps) {
    try {
      final o = await step();
      if (o != null) extra.add(o);
    } catch (e, st) {
      AppLogger.e('Bootstrap step failed', error: e, stackTrace: st);
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(secure),
        databaseKeyProvider.overrideWithValue(dbKey),
        deviceIdProvider.overrideWithValue(deviceId),
        ...extra,
      ],
      child: const FocusFlowApp(),
    ),
  );
}

/// Stable per-install id (rows' `deviceId`, backup manifests, linked devices).
Future<String> _deviceId(SharedPreferences prefs) async {
  const key = 'device_id';
  final existing = prefs.getString(key);
  if (existing != null) return existing;
  final id = const Uuid().v4();
  await prefs.setString(key, id);
  return id;
}

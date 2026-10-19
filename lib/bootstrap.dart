/// ============================================================
/// BOOTSTRAP — everything that must be ready before the first frame
/// ============================================================
///
/// Resolves the few async singletons (prefs, DB key, device id, time zone)
/// once, then injects them into Riverpod with overrides — the Fresh LPG
/// pattern, so no provider ever has to be async just to read a preference.
/// Each step is defensive: a keystore or plugin hiccup must never leave the
/// user stuck on the native splash. If the database key itself can't be
/// read, [StartupErrorApp] explains it and offers "Try again" — a new key
/// is only ever made when none exists (SecureStore.getOrCreateDatabaseKey).
/// ============================================================
library;

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/app.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/performance/device_performance.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/performance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Extra overrides contributed by features that need async setup
/// (e.g. the notification service). Registered before [bootstrap] runs.
typedef BootstrapStep = Future<Override?> Function();

bool _handlersInstalled = false;

Future<void> bootstrap({List<BootstrapStep> steps = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  runApp(
    await buildRoot(
      steps: steps,
      onRetry: () => bootstrap(steps: steps),
    ),
  );
}

void _installErrorHandlers() {
  if (_handlersInstalled) return;
  _handlersInstalled = true;
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
}

/// The app's root widget: the app inside its ProviderScope, or — when the
/// database key can't be read from the keychain — [StartupErrorApp]
/// (never a stuck splash, and never a new key that would orphan the data).
@visibleForTesting
Future<Widget> buildRoot({
  required Future<void> Function() onRetry,
  List<BootstrapStep> steps = const [],
  SecureStore? secureStore,
  Future<SharedPreferences> Function()? loadPrefs,
}) async {
  final secure = secureStore ?? SecureStore();
  final SharedPreferences prefs;
  final String dbKey;
  final DevicePerformance device;
  try {
    // Independent reads (disk, keychain, device info): run them together.
    // The device read never throws and gives up quickly: it only picks the
    // Automatic look of Settings › Appearance › Visual effects.
    (prefs, dbKey, device) = await (
      (loadPrefs ?? SharedPreferences.getInstance)(),
      secure.getOrCreateDatabaseKey(),
      DevicePerformance.detect(),
    ).wait;
  } on Object catch (e) {
    // The type is enough to triage; never log key material.
    AppLogger.w('Startup blocked: ${_errorTypes(e)}');
    return StartupErrorApp(onRetry: onRetry);
  }
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

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(secure),
      databaseKeyProvider.overrideWithValue(dbKey),
      deviceIdProvider.overrideWithValue(deviceId),
      devicePerformanceProvider.overrideWithValue(device),
      ...extra,
    ],
    child: const FocusFlowApp(),
  );
}

/// Error type(s) behind a failed startup read — unwraps the record `.wait`'s
/// [ParallelWaitError] so the log names the real failure.
String _errorTypes(Object e) {
  if (e is ParallelWaitError) {
    final errors = e.errors;
    if (errors is (AsyncError?, AsyncError?, AsyncError?)) {
      return [
        errors.$1,
        errors.$2,
        errors.$3,
      ].whereType<AsyncError>().map((a) => a.error.runtimeType).join(', ');
    }
  }
  return e.runtimeType.toString();
}

/// Minimal recovery screen shown when the data can't be unlocked (the
/// keychain is unavailable — e.g. right after a restart, before the first
/// unlock). Nothing is changed; "Try again" re-runs the startup.
class StartupErrorApp extends StatefulWidget {
  const StartupErrorApp({required this.onRetry, super.key});

  final Future<void> Function() onRetry;

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.screen),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    "Can't unlock your data",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    "${AppInfo.name} couldn't read its encryption key from "
                    "this device's secure storage. Your data hasn't been "
                    'changed. Try again, or restart the device and unlock '
                    'it before opening the app.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FilledButton(
                    onPressed: _busy ? null : _retry,
                    child: Text(_busy ? 'Trying…' : 'Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

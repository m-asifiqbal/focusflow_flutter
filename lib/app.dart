/// ============================================================
/// FOCUSFLOW APP — MaterialApp.router + theme + global wrappers
/// ============================================================
///
/// Applies the live appearance settings (theme mode, accent, text size,
/// reduce motion, system font) and the haptics switch to the whole
/// navigator, so dialogs, sheets and snackbars follow them too.
///
/// Performance: the app watches only the appearance slice of the settings
/// ([AppAppearance], a record with value equality), so writing an
/// unrelated setting (last sync time, a notification toggle…) rebuilds
/// nothing here. Themes come from [AppTheme]'s cache, so the same inputs
/// give the identical ThemeData and MaterialApp never re-animates it.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/startup/app_startup.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_text_scaler.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/features/settings/presentation/widgets/app_lock_gate.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The settings the app shell applies globally.
typedef AppAppearance = ({
  ThemeMode themeMode,
  AccentColor accent,
  bool useSystemFont,
  double textScale,
  bool reduceMotion,
  bool hapticsEnabled,
});

/// Extracts [AppAppearance] from the settings (used with `select`).
AppAppearance appearanceOf(AppSettings s) => (
  themeMode: s.themeMode,
  accent: s.accent,
  useSystemFont: s.useSystemFont,
  textScale: s.textScale,
  reduceMotion: s.reduceMotion,
  hapticsEnabled: s.hapticsEnabled,
);

class FocusFlowApp extends ConsumerWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final a = ref.watch(settingsProvider.select(appearanceOf));

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(a.accent, systemFont: a.useSystemFont),
      darkTheme: AppTheme.dark(a.accent, systemFont: a.useSystemFont),
      themeMode: a.themeMode,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => AppAppearanceScope(
        textScale: a.textScale,
        reduceMotion: a.reduceMotion,
        hapticsEnabled: a.hapticsEnabled,
        child: AppStartupHost(
          child: AppLockGate(
            child: GestureDetector(
              // Tap outside a field dismisses the keyboard (iOS has no back
              // key and several keyboards have no Done key) — Fresh LPG
              // convention.
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Applies Settings › Appearance text size + reduce motion on top of the
/// device accessibility settings, and provides the haptics switch to the
/// design system ([FFHaptics]).
///
/// Text size composes with the system [TextScaler] ([AppTextScaler]) so
/// Android's non-linear scaling survives and the OS scale is never capped.
/// Reduce motion is on when either the OS or the app asks for it.
class AppAppearanceScope extends StatelessWidget {
  const AppAppearanceScope({
    required this.textScale,
    required this.reduceMotion,
    required this.child,
    this.hapticsEnabled = true,
    super.key,
  });

  /// Settings › Appearance multiplier (0.85–1.3).
  final double textScale;
  final bool reduceMotion;
  final bool hapticsEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: AppTextScaler.compose(mq.textScaler, textScale),
        disableAnimations: mq.disableAnimations || reduceMotion,
      ),
      child: FFHaptics(enabled: hapticsEnabled, child: child),
    );
  }
}

/// ============================================================
/// FOCUSFLOW APP — MaterialApp.router + theme + global wrappers
/// ============================================================
///
/// Applies the live appearance settings (theme mode, accent, text size,
/// reduce motion) to the whole navigator, so dialogs, sheets and
/// snackbars follow them too.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class FocusFlowApp extends ConsumerWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.accent),
      darkTheme: AppTheme.dark(settings.accent),
      themeMode: settings.themeMode,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => _AppearanceScope(
        settings: settings,
        child: GestureDetector(
          // Tap outside a field dismisses the keyboard (iOS has no back key
          // and several keyboards have no Done key) — Fresh LPG convention.
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Applies Settings › Appearance text size + reduce motion on top of the
/// device accessibility settings.
class _AppearanceScope extends StatelessWidget {
  const _AppearanceScope({required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final systemScale = mq.textScaler.scale(1);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(
          (systemScale * settings.textScale).clamp(0.8, 2.0),
        ),
        disableAnimations: mq.disableAnimations || settings.reduceMotion,
      ),
      child: child,
    );
  }
}

/// ============================================================
/// APP THEME — ThemeData (light + dark) built from the tokens
/// ============================================================
///
/// `AppTheme.light(accent)` / `AppTheme.dark(accent)` attach the
/// [FFColors] and [FFTextStyles] extensions. Themes are cached per
/// (accent, brightness, system font), so asking again is free and returns
/// the identical instance. Widgets read them through the
/// [BuildContext] shortcuts at the bottom of this file:
///
/// ```dart
/// Container(color: context.ff.surface, child: Text('Hi', style: context.text.cardTitle));
/// ```
///
/// The vault screens are always dark ("secure mode"): wrap them in
/// [VaultTheme] so stock widgets inside pick up dark defaults too.
/// ============================================================
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusflow/core/router/page_transitions.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_typography.dart';

abstract final class AppTheme {
  /// Built themes, keyed by (accent, brightness, system font, vault).
  /// ThemeData is immutable, so returning the *same* instance for the same
  /// inputs lets MaterialApp skip its theme animation and lets
  /// `Theme.of` dependents skip rebuilds when an unrelated setting changes.
  static final Map<(AccentColor, Brightness, bool, bool), ThemeData> _cache =
      {};

  /// Light theme. [systemFont]: Settings › Appearance › "Use system font".
  static ThemeData light(AccentColor accent, {bool systemFont = false}) =>
      _cache.putIfAbsent(
        (accent, Brightness.light, systemFont, false),
        () => _build(
          FFColors.light(accent),
          Brightness.light,
          systemFont: systemFont,
        ),
      );

  static ThemeData dark(AccentColor accent, {bool systemFont = false}) =>
      _cache.putIfAbsent(
        (accent, Brightness.dark, systemFont, false),
        () => _build(
          FFColors.dark(accent),
          Brightness.dark,
          systemFont: systemFont,
        ),
      );

  /// Theme for the always-dark vault screens.
  static ThemeData vault(AccentColor accent, {bool systemFont = false}) =>
      _cache.putIfAbsent((accent, Brightness.dark, systemFont, true), () {
        final base = FFColors.dark(accent);
        final c = base.copyWith(
          canvas: AppPalette.vaultCanvas,
          surface: Colors.white.withValues(alpha: 0.05),
        );
        return _build(c, Brightness.dark, systemFont: systemFont);
      });

  static ThemeData _build(
    FFColors c,
    Brightness brightness, {
    required bool systemFont,
  }) {
    final text = FFTextStyles.from(c, systemFont: systemFont);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primaryStrong,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: c.danger,
      onError: Colors.white,
      surface: brightness == Brightness.light ? c.surface : c.canvas,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      outline: c.chipBorder,
      outlineVariant: c.divider,
      surfaceTint: Colors.transparent,
    );
    final roundedInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      // Null = the platform family from Material's typography.
      fontFamily: systemFont ? null : AppFonts.body,
      textTheme: FFTextStyles.materialTextTheme(c, systemFont: systemFont),
      extensions: [c, text],
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.ink, size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.navTitle,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: text.body.copyWith(color: c.inkFaint),
        border: roundedInput,
        enabledBorder: roundedInput,
        focusedBorder: roundedInput.copyWith(
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.highlight,
        selectionHandleColor: c.primary,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.primary),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.primary
              : c.ink.withValues(alpha: 0.12),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.primarySoft,
        thumbColor: Colors.white,
        overlayColor: c.primary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.primarySoft,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: c.inkFaint, width: 1.6),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheet,
        modalBackgroundColor: c.sheet,
        modalBarrierColor: c.scrim,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF0C2F26),
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
        titleTextStyle: text.title,
        contentTextStyle: text.body,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.snackbar,
        contentTextStyle: text.rowTitle.copyWith(color: c.onSnackbar),
        actionTextColor: c.snackbarAction,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF0C2F26),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: text.rowTitle,
      ),
      // One motion language for every push (core/router/page_transitions.dart).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FFPageTransitionsBuilder(),
          TargetPlatform.iOS: FFPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Wraps vault screens in the always-dark secure theme.
class VaultTheme extends StatelessWidget {
  const VaultTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Secure mode is always the emerald family, whatever the app accent;
    // "Use system font" carries over (the app theme drops the families).
    final systemFont =
        Theme.of(context).extension<FFTextStyles>()?.body.fontFamily == null;
    return Theme(
      data: AppTheme.vault(AccentColor.emerald, systemFont: systemFont),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: child,
      ),
    );
  }
}

extension FFThemeContext on BuildContext {
  /// Semantic colour tokens for the current theme.
  FFColors get ff => Theme.of(this).extension<FFColors>()!;

  /// Typography tokens (already coloured for the current theme).
  FFTextStyles get text => Theme.of(this).extension<FFTextStyles>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Bottom padding for a scroll view on a tab screen: lets the last item
  /// scroll clear of the floating nav bar (MediaQuery bottom = bar height).
  double get barClearance =>
      MediaQuery.paddingOf(this).bottom + AppSpacing.bottomBarClearance;
}

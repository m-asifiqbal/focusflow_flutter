/// ============================================================
/// SIGN IN BUTTON — the three stacked buttons of screen 02
/// ============================================================
///
/// What: 56-pt full-width buttons in three looks — Google (surface + 1.5
/// border + the "G"), Apple (dark, inverted in dark mode) and Use offline
/// (emerald-50 soft). Each can show a spinner in place of its label.
/// Why: the shared FF buttons can't carry a brand logo and a spinner in
/// the same slot, and the sign-in screen disables the other buttons while
/// one is busy.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/widgets/google_logo.dart';

enum SignInButtonKind { google, apple, offline }

class SignInButton extends StatelessWidget {
  const SignInButton({
    required this.kind,
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final SignInButtonKind kind;
  final String label;

  /// Null disables (dims) the button.
  final VoidCallback? onPressed;

  /// Shows a spinner instead of the label and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final radius = BorderRadius.circular(AppRadii.button);
    final (decoration, fg) = switch (kind) {
      SignInButtonKind.google => (
        BoxDecoration(
          color: ff.surface,
          borderRadius: radius,
          border: Border.all(color: ff.ink.withValues(alpha: 0.12)),
        ),
        ff.ink,
      ),
      SignInButtonKind.apple => (
        BoxDecoration(color: ff.snackbar, borderRadius: radius),
        ff.onSnackbar,
      ),
      SignInButtonKind.offline => (
        BoxDecoration(
          color: ff.isDark
              ? ff.primarySoft
              : Color.alphaBlend(
                  ff.primarySoft.withValues(alpha: 0.5),
                  ff.surface,
                ),
          borderRadius: radius,
        ),
        ff.primaryStrong,
      ),
    };
    final Widget leading = switch (kind) {
      SignInButtonKind.google => const GoogleLogo(size: 20),
      SignInButtonKind.apple => Icon(
        FontAwesomeIcons.apple,
        size: 21,
        color: fg,
      ),
      SignInButtonKind.offline => Icon(
        FontAwesomeIcons.solidHardDrive,
        size: 17,
        color: fg,
      ),
    };
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          opacity: onPressed == null && !loading ? 0.45 : 1,
          duration: context.motion(AppMotion.fast),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: AppSizes.primaryButton,
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            alignment: Alignment.center,
            decoration: decoration,
            child: loading
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      leading,
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: context.text.button.copyWith(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

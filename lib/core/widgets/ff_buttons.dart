/// ============================================================
/// FF BUTTONS — primary (gradient), secondary, danger, soft danger, text
/// ============================================================
///
/// | Button              | Height | Look                                   |
/// |---------------------|--------|----------------------------------------|
/// | FFPrimaryButton     | 56     | primary gradient, hero shadow, white   |
/// | FFSecondaryButton   | 52     | soft (emerald-50) / outlined / surface |
/// | FFDangerButton      | 52     | rose solid + rose glow                 |
/// | FFSoftDangerButton  | 52     | rose-50 fill, rose-600 text            |
/// | FFTextButton        | ≥44    | primary text only                      |
///
/// All share [_FFButtonFrame]: press-scale, disabled opacity, Semantics,
/// min 44 tap target, label ellipsis (safe at text scale 1.3 / 360 pt).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

/// Gradient call-to-action ("Add a reminder", "Unlock with Face ID").
class FFPrimaryButton extends StatelessWidget {
  const FFPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = AppSizes.primaryButton,
    this.semanticLabel,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner and ignores taps.
  final bool loading;

  /// Fill the available width.
  final bool expand;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final enabled = onPressed != null && !loading;
    return _FFButtonFrame(
      label: label,
      semanticLabel: semanticLabel,
      onPressed: enabled ? onPressed : null,
      dimmed: onPressed == null,
      expand: expand,
      height: height,
      decoration: BoxDecoration(
        gradient: ff.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadii.button),
        boxShadow: onPressed == null ? null : ff.heroShadow,
      ),
      child: loading
          ? SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: ff.onGradient,
              ),
            )
          : _FFButtonLabel(
              label: label,
              icon: icon,
              style: context.text.button.copyWith(
                fontSize: 17,
                color: ff.onGradient,
              ),
            ),
    );
  }
}

enum FFSecondaryVariant {
  /// emerald-50 fill + primary text ("Archive instead").
  soft,

  /// Surface fill + 1px chipBorder.
  outlined,

  /// Surface fill + card shadow ("Sign out", "Restore all").
  surface,
}

class FFSecondaryButton extends StatelessWidget {
  const FFSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = FFSecondaryVariant.soft,
    this.foreground,
    this.background,
    this.expand = true,
    this.height = AppSizes.secondaryButton,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final FFSecondaryVariant variant;

  /// Text/icon colour override (defaults to primaryStrong).
  final Color? foreground;

  /// Fill override (e.g. `ff.surfaceMuted` for a neutral "Archive").
  final Color? background;
  final bool expand;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final radius = BorderRadius.circular(AppRadii.button);
    final decoration = switch (variant) {
      FFSecondaryVariant.soft => BoxDecoration(
        color: background ?? ff.primaryFaint,
        borderRadius: radius,
      ),
      FFSecondaryVariant.outlined => BoxDecoration(
        color: background ?? ff.surface,
        borderRadius: radius,
        border: Border.all(color: ff.chipBorder, width: 1.5),
      ),
      FFSecondaryVariant.surface => BoxDecoration(
        color: background ?? ff.surface,
        borderRadius: radius,
        border: Border.all(color: ff.surfaceBorder),
        boxShadow: ff.cardShadow,
      ),
    };
    return _FFButtonFrame(
      label: label,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      dimmed: onPressed == null,
      expand: expand,
      height: height,
      decoration: decoration,
      child: _FFButtonLabel(
        label: label,
        icon: icon,
        style: context.text.button.copyWith(
          fontSize: 17,
          color: foreground ?? ff.primaryStrong,
        ),
      ),
    );
  }
}

/// Solid rose destructive button ("Delete").
class FFDangerButton extends StatelessWidget {
  const FFDangerButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = AppSizes.secondaryButton,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return _FFButtonFrame(
      label: label,
      semanticLabel: semanticLabel,
      onPressed: loading ? null : onPressed,
      dimmed: onPressed == null,
      expand: expand,
      height: height,
      decoration: BoxDecoration(
        color: ff.dangerSolid,
        borderRadius: BorderRadius.circular(AppRadii.button),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  offset: const Offset(0, 12),
                  blurRadius: 28,
                  spreadRadius: -12,
                  color: ff.dangerSolid.withValues(alpha: 0.6),
                ),
              ],
      ),
      child: loading
          ? SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: ff.onGradient,
              ),
            )
          : _FFButtonLabel(
              label: label,
              icon: icon,
              style: context.text.button.copyWith(
                fontSize: 17,
                color: ff.onGradient,
              ),
            ),
    );
  }
}

/// rose-50 fill + rose-600 text ("Delete all", sheet "Delete").
class FFSoftDangerButton extends StatelessWidget {
  const FFSoftDangerButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.height = AppSizes.secondaryButton,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return _FFButtonFrame(
      label: label,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      dimmed: onPressed == null,
      expand: expand,
      height: height,
      decoration: BoxDecoration(
        color: ff.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: _FFButtonLabel(
        label: label,
        icon: icon,
        style: context.text.button.copyWith(
          fontSize: 17,
          color: ff.dangerStrong,
        ),
      ),
    );
  }
}

/// Text-only action ("View Monthly", "Cancel", "Reschedule all").
class FFTextButton extends StatelessWidget {
  const FFTextButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.style,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.xs,
    ),
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Defaults to primary.
  final Color? color;

  /// Defaults to Lexend 15 w600.
  final TextStyle? style;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.text.buttonSmall.copyWith(fontSize: 15);
    final c = color ?? style?.color ?? context.ff.primary;
    final resolved = base.copyWith(
      color: onPressed == null ? c.withValues(alpha: 0.4) : c,
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onPressed,
        scale: 0.96,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTap,
            minWidth: AppSizes.minTap,
          ),
          child: Padding(
            padding: padding,
            child: Center(
              widthFactor: 1,
              child: _FFButtonLabel(
                label: label,
                icon: icon,
                style: resolved,
                iconGap: 6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FFButtonLabel extends StatelessWidget {
  const _FFButtonLabel({
    required this.label,
    required this.style,
    this.icon,
    this.iconGap = 10,
  });

  final String label;
  final IconData? icon;
  final TextStyle style;
  final double iconGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: (style.fontSize ?? 16) * 1.05, color: style.color),
          SizedBox(width: iconGap),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _FFButtonFrame extends StatelessWidget {
  const _FFButtonFrame({
    required this.label,
    required this.onPressed,
    required this.dimmed,
    required this.expand,
    required this.height,
    required this.decoration,
    required this.child,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool dimmed;
  final bool expand;
  final double height;
  final BoxDecoration decoration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: dimmed ? 0.45 : 1,
          duration: context.motion(AppMotion.fast),
          child: Container(
            width: expand ? double.infinity : null,
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            alignment: expand ? Alignment.center : null,
            decoration: decoration,
            child: expand ? child : Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// VAULT PRIMARY BUTTON — "Unlock with Face ID" (screen 17)
/// ============================================================
///
/// The vault's own CTA: emerald-500 → emerald-600 gradient with a soft
/// emerald glow, as in the mockup. The app-wide FFPrimaryButton follows the
/// accent gradient and a shadow tuned for the light canvas, which reads as
/// a dark band on the always-dark vault canvas.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultPrimaryButton extends StatelessWidget {
  const VaultPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fontSize = 15.5,
    super.key,
  });

  final String label;

  /// Null disables (dimmed, no glow).
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner instead of the label and ignores taps.
  final bool loading;

  /// Label size (the Generator's "Save to new vault item" is 17.5).
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final enabled = onPressed != null && !loading;
    final ink = ff.vaultInk;
    final style = context.text.button.copyWith(fontSize: fontSize, color: ink);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: enabled ? onPressed : null,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: Container(
            height: AppSizes.primaryButton,
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              gradient: ff.vaultButtonGradient,
              borderRadius: BorderRadius.circular(AppRadii.button),
              boxShadow: onPressed == null ? null : ff.vaultButtonGlow,
            ),
            child: loading
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: ink,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: VaultSizes.iconButton, color: ink),
                        const SizedBox(width: VaultSizes.gapSm),
                      ],
                      // Shrinks rather than truncating ("Unlock with
                      // Face …") at 360 pt / large text.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label, maxLines: 1, style: style),
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

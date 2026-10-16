/// ============================================================
/// VAULT PASSWORD WIDGETS — the password row's controls (screen 20)
/// ============================================================
///
/// * [VaultIconButton]    — emerald glyph (eye, QR scan) with a 44-pt target
///   whose glyph sits on the value line.
/// * [VaultGeneratePill]  — emerald-tint "Generate" pill with a wand.
/// * [VaultStrengthMeter] — 4 segments + "Very strong · would take …".
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/crypto/password_strength.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Emerald icon button without a disc (eye, scan) — 44 pt target.
class VaultIconButton extends StatelessWidget {
  const VaultIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.size = 17,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: FFPressable(
      onTap: onTap,
      scale: 0.9,
      child: SizedBox.square(
        dimension: AppSizes.minTap,
        // Glyph on the value line, target covering the label too.
        child: Align(
          alignment: AlignmentDirectional.bottomCenter,
          child: SizedBox(
            height: VaultSizes.eyeSlot,
            child: Icon(icon, size: size, color: context.ff.vaultAccent),
          ),
        ),
      ),
    ),
  );
}

/// Emerald-tint pill with a wand: "Generate".
class VaultGeneratePill extends StatelessWidget {
  const VaultGeneratePill({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: 'Generate password',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.minTap,
          child: Align(
            alignment: AlignmentDirectional.bottomCenter,
            // Centred on the value line (the 44-pt target stays put).
            child: Container(
              height: VaultSizes.pill,
              transform: Matrix4.translationValues(0, AppSpacing.xs, 0),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm + 1,
              ),
              decoration: BoxDecoration(
                color: ff.vaultAccentTint,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FontAwesomeIcons.wandMagicSparkles,
                    size: VaultSizes.iconXs,
                    color: ff.vaultAccent,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    'Generate',
                    style: context.text.rowTitle.copyWith(
                      fontSize: VaultType.subtitle,
                      fontWeight: FontWeight.w600,
                      color: ff.vaultAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VaultStrengthMeter extends StatelessWidget {
  const VaultStrengthMeter({required this.strength, super.key});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final score = strength.score;
    final color = switch (score) {
      0 || 1 => ff.vaultDanger.fg,
      2 => ff.vaultFair.fg,
      _ => ff.vaultAccent,
    };
    final filled = strength.length == 0 ? 0 : score.clamp(1, 4);
    final crack = strength.crackTimeLabel;
    final text = strength.length == 0
        ? 'Add a password or generate one'
        : crack == 'instantly'
        ? '${strength.label} · could be cracked instantly'
        : '${strength.label} · would take $crack to crack';
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg + 2),
      child: Semantics(
        label: 'Password strength: $text',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Container(
                      height: VaultSizes.strengthBar,
                      decoration: BoxDecoration(
                        color: i < filled ? color : ff.vaultTrack,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 1),
            Text(
              text,
              style: context.text.caption.copyWith(
                fontSize: VaultType.secondary,
                fontWeight: FontWeight.w600,
                color: strength.length == 0 ? ff.vaultFieldLabel : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

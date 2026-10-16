/// ============================================================
/// VAULT GENERATOR RESULT — the emerald glass card of screen 21
/// ============================================================
///
/// The generated value (mono 25, digits sky / symbols amber), a 4-bar
/// meter, "VERY STRONG · 98 bits entropy" and Regenerate / Copy. Pure
/// view: the caller passes the value and the two callbacks. Sizes are
/// measured from the 1170-px mockup (÷ 3).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/state/vault_generator_state.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Emerald glass of the result card (emerald-500 18 % → 6 %).
extension VaultGeneratorColors on FFColors {
  LinearGradient get vaultGlassGradient => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [
      AppPalette.emerald500.withValues(alpha: 0.20),
      AppPalette.emerald500.withValues(alpha: 0.07),
    ],
  );

  Color get vaultGlassBorder => AppPalette.emerald400.withValues(alpha: 0.28);

  /// Secondary glass button (Regenerate, issue actions): white 12 %.
  Color get vaultGlassButton => vaultInk.withValues(alpha: 0.12);
}

class VaultGeneratorResult extends StatelessWidget {
  const VaultGeneratorResult({
    required this.value,
    required this.onRegenerate,
    required this.onCopy,
    super.key,
  });

  /// Null while the passphrase wordlist loads.
  final GeneratedValue? value;
  final VoidCallback onRegenerate;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final v = value;
    final strength = v == null ? null : GeneratorStrength.of(v.entropyBits);
    final color = switch (strength) {
      GeneratorStrength.weak => ff.vaultDanger.fg,
      GeneratorStrength.fair => ff.vaultFair.fg,
      _ => ff.vaultAccentBright,
    };
    final caption = v == null
        ? ''
        : '${strength!.label.toUpperCase()} · '
              '${v.entropyBits.round()} bits entropy';
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxl,
        AppSpacing.xl + 2,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        gradient: ff.vaultGlassGradient,
        borderRadius: BorderRadius.circular(AppRadii.hero - 2),
        border: Border.all(
          color: ff.vaultGlassBorder,
          width: AppSizes.hairline,
        ),
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: VaultSizes.chipRow),
            child: v == null
                ? const FFSkeleton(
                    width: VaultSizes.entropyBarWidth,
                    height: VaultType.title,
                  )
                : Semantics(
                    label: 'Generated ${v.mode.name}',
                    value: v.value,
                    child: ExcludeSemantics(
                      child: VaultSecretText(
                        v.value,
                        colour: true,
                        style: context.vaultMonoStyle.copyWith(
                          fontSize: VaultType.titleLg,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl + 2),
          Semantics(
            label: caption,
            excludeSemantics: true,
            child: Column(
              children: [
                SizedBox(
                  width: VaultSizes.entropyBarWidth,
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: VaultSizes.gapXs),
                        Expanded(
                          child: AnimatedContainer(
                            duration: context.motion(AppMotion.fast),
                            height: VaultSizes.entropyBar,
                            decoration: BoxDecoration(
                              color: i < (strength?.bars ?? 0)
                                  ? color
                                  : ff.vaultTrack,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: context.text.caption.copyWith(
                    fontSize: VaultType.small,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: 'Regenerate',
                  icon: FontAwesomeIcons.arrowsRotate,
                  onTap: onRegenerate,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _CardButton(
                  label: 'Copy',
                  icon: FontAwesomeIcons.solidCopy,
                  onTap: onCopy,
                  primary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final ink = primary ? ff.vaultOnAccentInk : ff.vaultInk;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: VaultSizes.actionButton),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? ff.vaultAccent : ff.vaultGlassButton,
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: VaultSizes.iconButton, color: ink),
              const SizedBox(width: AppSpacing.sm + 2),
              // Scales down rather than truncating at 360 pt / large text.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: context.text.body.copyWith(
                      fontSize: VaultType.row,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

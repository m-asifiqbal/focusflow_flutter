/// ============================================================
/// SIGN IN BENEFITS CARD — the white card on screen 02
/// ============================================================
///
/// Three rows (soft emerald 34-pt tile + text) explaining what an account
/// adds: encrypted Drive backup, cross-platform sync, E2E vault.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class SignInBenefitsCard extends StatelessWidget {
  const SignInBenefitsCard({super.key});

  static const _rows = [
    (FontAwesomeIcons.cloudArrowUp, 'Encrypted backup to your Google Drive'),
    (FontAwesomeIcons.mobileScreenButton, 'Sync across Android & iOS devices'),
    (FontAwesomeIcons.lock, 'Vault data is end-to-end encrypted'),
  ];

  @override
  Widget build(BuildContext context) {
    final style = context.text.body.copyWith(
      fontSize: 14.5,
      color: context.ff.ink.withValues(alpha: 0.8),
      height: 1.45,
    );
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 26,
      ),
      child: Column(
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                FFIconTile.soft(
                  icon: _rows[i].$1,
                  colors: ModuleStyle.notes.colors,
                  size: 34,
                  iconSize: 16,
                  radius: AppRadii.tile,
                ),
                const SizedBox(width: AppSpacing.rowLeadingGap),
                Expanded(child: Text(_rows[i].$2, style: style)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ============================================================
/// SETTINGS HERO — the dark summary card at the top of a sub-page
/// ============================================================
///
/// What: deep-emerald card with an accent icon tile, a title and a muted
/// explanation (App lock, Storage, About). Same proportions as the
/// "Zero-knowledge encryption" card of mockup 33.
/// Why: gives the security / data sub-pages the same first impression as
/// Vault security without depending on the vault feature's widgets.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class SettingsHero extends StatelessWidget {
  const SettingsHero({
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Optional widget under the text (e.g. a storage bar).
  final Widget? trailing;

  /// Icon tile, measured from mockup 33 (56 pt, radius ≈ 30 %).
  static const double _tile = 56;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: ff.vaultCanvas,
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: _tile,
              height: _tile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ff.vaultAccent,
                borderRadius: BorderRadius.circular(_tile * 0.3),
              ),
              child: Icon(icon, size: 24, color: ff.vaultCanvas),
            ),
            const SizedBox(width: AppSpacing.lg + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.title.copyWith(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: ff.vaultInk,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    body,
                    style: context.text.meta.copyWith(
                      fontSize: 13,
                      height: 1.4,
                      color: ff.vaultInk.withValues(alpha: 0.6),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

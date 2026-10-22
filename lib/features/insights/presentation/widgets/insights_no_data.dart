/// ============================================================
/// INSIGHTS NO DATA — the "Not enough data" state inside a chart card
/// ============================================================
///
/// A small, centred icon + title + hint shown in place of a chart whose
/// range has too little to plot (the card and its title stay, so the
/// layout doesn't jump when data arrives).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';

class InsightsNoData extends StatelessWidget {
  const InsightsNoData({
    required this.message,
    this.icon = FontAwesomeIcons.chartLine,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;

  /// Optional CTA (e.g. "Start a focus session").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: InsightsDimens.noDataIcon, color: ff.inkFaint),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr('Not enough data'),
            textAlign: TextAlign.center,
            style: context.text.cardTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

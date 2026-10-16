/// ============================================================
/// INBOX ACTION BUTTON — the small inline "Done" / "Snooze 10m" pills
/// ============================================================
///
/// What: compact 32-pt buttons under a notification row: filled primary
/// for the first action, outlined for the rest (design/27). The tap area is
/// padded to the 44-pt minimum without changing the drawn size.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class InboxActionButton extends StatelessWidget {
  const InboxActionButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    super.key,
  });

  /// Drawn height of the pill (the hit area stays 44 pt).
  static const double height = 32;

  /// Label size on design/27 (`buttonSmall` is 13.5).
  static const double labelSize = 14;

  final String label;
  final VoidCallback onPressed;

  /// Primary fill (first action) vs. outlined.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final fg = filled ? ff.onPrimary : ff.primaryStrong;
    const outset = (AppSizes.minTap - height) / 2;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: outset),
          child: Container(
            constraints: const BoxConstraints(minHeight: height),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? ff.primary : ff.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: filled ? ff.primary : ff.chipBorder,
                width: AppSizes.hairline,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: context.text.buttonSmall.copyWith(
                fontSize: labelSize,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

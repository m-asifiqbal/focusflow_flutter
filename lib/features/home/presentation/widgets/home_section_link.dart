/// ============================================================
/// HOME SECTION LINK — "View Monthly" / "All Reminders" / "See All"
/// ============================================================
///
/// What: the trailing link of a Home section header: Lexend 15 w500 in the
/// accent colour, with the shared 44-pt tap height.
/// Why: Home's links are a step lighter than the shared FFTextButton
/// default (mockup 03), so every section uses this one widget.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';

class HomeSectionLink extends StatelessWidget {
  const HomeSectionLink(this.label, {required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FFTextButton(
      label: label,
      onPressed: onPressed,
      padding: EdgeInsetsDirectional.zero,
      color: context.ff.primary,
      style: context.text.buttonSmall.copyWith(
        fontSize: HomeDimens.link,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

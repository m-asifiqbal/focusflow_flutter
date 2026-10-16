/// ============================================================
/// FF HEADERS — large title, 3-column nav bar, section headers & labels
/// ============================================================
///
/// * [FFLargeHeader]   — "Notes / 48 notes · 3 pinned" + round buttons.
/// * [FFNavHeader]     — back · centred title (+ "AUTO-SAVED" overline) · actions.
/// * [FFBackButton] / [FFNavAction] — the nav header's leading/trailing items.
/// * [FFSectionHeader] — "Up Next … All Reminders" (section title + link).
/// * [FFSectionLabel]  — "COLLECTIONS" (11.5 w800 uppercase, faint).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_buttons.dart';
import 'package:focusflow/core/widgets/ff_round_icon_button.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

/// List-screen header: 30 pt title, primary @70% subtitle, round actions.
class FFLargeHeader extends StatelessWidget {
  const FFLargeHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.fitTitle = false,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.screen,
      AppSpacing.lg,
      AppSpacing.screen,
      AppSpacing.sm,
    ),
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Usually [FFRoundIconButton]s; spaced 10 pt apart.
  final List<Widget> actions;

  /// Optional leading widget (vault shield tile, avatar).
  final Widget? leading;

  /// Scale a fixed title (e.g. "Reminders") down to fit instead of
  /// ellipsizing it at large text scales / narrow widths. Leave false for
  /// user-provided titles (folder names), which should ellipsize.
  final bool fitTitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final titleText = fitTitle
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(title, maxLines: 1, style: context.text.largeTitle),
          )
        : Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.largeTitle,
          );
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(header: true, child: titleText),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // 13 pt — measured against design/07 ("48 notes · 3 pinned").
                    style: context.text.meta.copyWith(
                      fontSize: 13,
                      color: ff.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(width: i == 0 ? AppSpacing.md : 10),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// 3-column navigation bar with a centred title.
class FFNavHeader extends StatelessWidget {
  const FFNavHeader({
    this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleIcon,
    this.leading,
    this.trailing = const [],
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.xl,
    ),
    super.key,
  });

  final String? title;

  /// Replaces [title] (e.g. a tappable month picker).
  final Widget? titleWidget;

  /// Small uppercase overline under the title ("AUTO-SAVED").
  final String? subtitle;
  final IconData? subtitleIcon;

  /// Usually [FFBackButton] or [FFNavAction] ("Cancel").
  final Widget? leading;

  /// Usually [FFRoundIconButton]s or an [FFNavAction] ("Save").
  final List<Widget> trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    Widget? middle = titleWidget;
    if (middle == null && (title != null || subtitle != null)) {
      middle = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Semantics(
              header: true,
              child: Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.navTitle.copyWith(fontSize: 17),
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitleIcon != null) ...[
                  Icon(subtitleIcon, size: 11, color: ff.success),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    subtitle!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.sectionLabel.copyWith(
                      fontSize: 10.5,
                      color: ff.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }
    return Padding(
      padding: padding,
      child: SizedBox(
        height: subtitle == null ? 56 : 64,
        child: NavigationToolbar(
          leading: leading,
          middle: middle,
          trailing: trailing.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < trailing.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      trailing[i],
                    ],
                  ],
                ),
          middleSpacing: AppSpacing.md,
        ),
      ),
    );
  }
}

/// Back affordance: round chevron button, or "‹ Settings" text style when
/// [label] is given. Defaults to `Navigator.maybePop`.
class FFBackButton extends StatelessWidget {
  const FFBackButton({
    this.onPressed,
    this.label,
    this.semanticLabel = 'Back',
    this.dark = false,
    super.key,
  });

  final VoidCallback? onPressed;

  /// Previous screen's title ("Settings"); null = round chevron button.
  final String? label;
  final String semanticLabel;

  /// Vault glass variant of the round button.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final chevron = rtl
        ? FontAwesomeIcons.chevronRight
        : FontAwesomeIcons.chevronLeft;
    final tap = onPressed ?? () => Navigator.maybePop(context);
    if (label == null) {
      return FFRoundIconButton(
        icon: chevron,
        semanticLabel: semanticLabel,
        onPressed: tap,
        variant: dark
            ? FFRoundIconButtonVariant.dark
            : FFRoundIconButtonVariant.surface,
      );
    }
    return FFTextButton(
      label: label!,
      icon: chevron,
      onPressed: tap,
      semanticLabel: '$semanticLabel to $label',
      padding: EdgeInsetsDirectional.zero,
      style: context.text.buttonSmall.copyWith(
        fontSize: 17,
        color: context.ff.primary,
      ),
    );
  }
}

/// "Cancel" / "Save" nav-bar text action (primary, 17 w600). [enabled]
/// false dims it (e.g. Save before anything changed).
class FFNavAction extends StatelessWidget {
  const FFNavAction({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.emphasized = false,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Bold (w700) — the confirming action.
  final bool emphasized;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFTextButton(
      label: label,
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsetsDirectional.zero,
      style: context.text.buttonSmall.copyWith(
        fontSize: 17,
        fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
        color: destructive ? ff.danger : ff.primary,
      ),
    );
  }
}

/// "Up Next ……… All Reminders" — section title + optional link/trailing.
class FFSectionHeader extends StatelessWidget {
  const FFSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = EdgeInsetsDirectional.zero,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Replaces the action link (e.g. an [FFBadge] "3 LEFT").
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.sectionTitle,
                ),
              ),
            ),
            if (trailing != null || actionLabel != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.5,
                ),
                child:
                    trailing ??
                    FFTextButton(
                      label: actionLabel!,
                      onPressed: onAction,
                      padding: EdgeInsetsDirectional.zero,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "COLLECTIONS" — 11.5 w800 uppercase label above a group or list, with an
/// optional trailing action ("Reschedule all").
class FFSectionLabel extends StatelessWidget {
  const FFSectionLabel(
    this.text, {
    this.actionLabel,
    this.onAction,
    this.actionColor,
    this.trailing,
    this.color,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xs,
      0,
      AppSpacing.xs,
      10,
    ),
    super.key,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Action colour (defaults to primary; use danger for "Reschedule all").
  final Color? actionColor;
  final Widget? trailing;

  /// Label colour override (defaults to inkFaint).
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.sectionLabel.copyWith(color: color),
    );
    final hasAction = trailing != null || actionLabel != null;
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: hasAction
            ? LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(child: label),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.5,
                      ),
                      child:
                          trailing ??
                          FFTextButton(
                            label: actionLabel!,
                            onPressed: onAction,
                            color: actionColor,
                            padding: EdgeInsetsDirectional.zero,
                          ),
                    ),
                  ],
                ),
              )
            : Align(alignment: AlignmentDirectional.centerStart, child: label),
      ),
    );
  }
}

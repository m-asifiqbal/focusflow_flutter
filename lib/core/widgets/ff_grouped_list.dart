/// ============================================================
/// FF GROUPED LIST — iOS-style grouped settings card + rows (screen 30)
/// ============================================================
///
/// [FFGroupedList]: optional [FFSectionLabel] above a surface card (radius
/// 22, card shadow) whose rows are separated by 1 px dividers inset 60 pt.
/// [FFListRow]: min 60 pt — leading tile (32) · title/subtitle · muted
/// value · chevron | switch | custom trailing. Rows ripple inside the card.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_headers.dart';
import 'package:focusflow/core/widgets/ff_switch.dart';
import 'package:focusflow/core/widgets/ff_tag.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

class FFGroupedList extends StatelessWidget {
  const FFGroupedList({
    required this.children,
    this.label,
    this.labelAction,
    this.footer,
    this.dividerIndent = AppSpacing.dividerInset,
    this.color,
    super.key,
  });

  final List<Widget> children;

  /// Section label above the card ("GENERAL").
  final String? label;

  /// Trailing widget for the label row.
  final Widget? labelAction;

  /// Small muted note under the card.
  final String? footer;

  /// Divider start inset (60 with leading tiles, 16 without).
  final double dividerIndent;

  /// Card colour override (defaults to surface).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final radius = BorderRadius.circular(AppRadii.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) FFSectionLabel(label!, trailing: labelAction),
        DecoratedBox(
          decoration: BoxDecoration(
            color: color ?? ff.surface,
            borderRadius: radius,
            border: Border.all(color: ff.surfaceBorder),
            boxShadow: ff.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) FFDividerInset(indent: dividerIndent),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Text(footer!, style: context.text.meta),
          ),
      ],
    );
  }
}

class FFListRow extends StatelessWidget {
  const FFListRow({
    required this.title,
    this.leading,
    this.subtitle,
    this.value,
    this.valueColor,
    this.trailing,
    this.chevron,
    this.onTap,
    this.onLongPress,
    this.destructive = false,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  }) : switchValue = null,
       onSwitchChanged = null;

  /// A row whose trailing is an [FFSwitch]; tapping the row toggles it.
  const FFListRow.toggle({
    required this.title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.leading,
    this.subtitle,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  }) : switchValue = value,
       onSwitchChanged = onChanged,
       value = null,
       valueColor = null,
       trailing = null,
       chevron = false,
       onTap = null,
       onLongPress = null,
       destructive = false;

  final String title;

  /// Usually an [FFIconTile] of size 32.
  final Widget? leading;
  final String? subtitle;

  /// Muted right-aligned value before the chevron ("English").
  final String? value;
  final Color? valueColor;

  /// Custom trailing widget (replaces the chevron).
  final Widget? trailing;

  /// Show the chevron; defaults to true when tappable without [trailing].
  final bool? chevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Rose title ("Delete account").
  final bool destructive;
  final bool enabled;
  final String? semanticLabel;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  bool get _isToggle => switchValue != null;

  /// Title (+ subtitle) and the value. The value sits beside the title
  /// (≤ 42 % of the row) while both fit; when the title would be cut or
  /// the value ellipsized (narrow screens, large text) it moves under the
  /// title instead, so neither is truncated.
  Widget _texts(
    BuildContext context, {
    required double width,
    required double valueCap,
    required TextStyle titleStyle,
  }) {
    final ff = context.ff;
    final valueStyle = context.text.body.copyWith(
      height: 1.3,
      color: valueColor ?? ff.inkMuted,
      fontWeight: valueColor == null ? FontWeight.w400 : FontWeight.w700,
    );
    Widget titleBlock({Widget? below}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (below != null) ...[const SizedBox(height: AppSpacing.xxs), below],
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.meta.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 13.5,
            ),
          ),
        ],
      ],
    );
    final v = value;
    if (v == null) return titleBlock();

    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    final valuePainter = TextPainter(
      text: TextSpan(text: v, style: base.merge(valueStyle)),
      maxLines: 1,
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final valueWidth = math.min(valuePainter.width, valueCap);
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: base.merge(titleStyle)),
      maxLines: 2,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: math.max(0, width - AppSpacing.sm - valueWidth));
    final beside =
        valuePainter.width <= valueCap && !titlePainter.didExceedMaxLines;
    valuePainter.dispose();
    titlePainter.dispose();

    if (!beside) {
      return titleBlock(
        below: Text(
          v,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: valueStyle,
        ),
      );
    }
    return Row(
      children: [
        Expanded(child: titleBlock()),
        const SizedBox(width: AppSpacing.sm),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: valueCap),
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: valueStyle,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tap = !enabled
        ? null
        : _isToggle
        ? (onSwitchChanged == null
              ? null
              : () => onSwitchChanged!(!switchValue!))
        : onTap;
    final showChevron = chevron ?? (onTap != null && trailing == null);
    final titleStyle = context.text.rowTitle.copyWith(
      color: destructive ? ff.danger : null,
    );

    final row = LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.rowVertical,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.rowLeadingGap),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, inner) => _texts(
                    context,
                    width: inner.maxWidth,
                    valueCap: constraints.maxWidth * 0.42,
                    titleStyle: titleStyle,
                  ),
                ),
              ),
              if (_isToggle) ...[
                const SizedBox(width: AppSpacing.sm),
                ExcludeSemantics(
                  child: FFSwitch(
                    value: switchValue!,
                    onChanged: enabled ? onSwitchChanged : null,
                  ),
                ),
              ] else if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ] else if (showChevron) ...[
                const SizedBox(width: 10),
                Icon(
                  rtl
                      ? FontAwesomeIcons.chevronLeft
                      : FontAwesomeIcons.chevronRight,
                  size: 13,
                  color: ff.inkFaint,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: !_isToggle && tap != null,
      toggled: switchValue,
      enabled: enabled,
      label: semanticLabel,
      child: InkWell(
        onTap: tap,
        onLongPress: enabled ? onLongPress : null,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: row),
      ),
    );
  }
}

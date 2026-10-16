/// ============================================================
/// SEARCH SECTIONS — section label, recent-search pills, filter pills
/// ============================================================
///
/// Pieces of Global search (screen 06) below the results card:
/// "RECENT SEARCHES" history pills (surface + border, clock icon) and the
/// "SEARCH FILTERS" pills (soft primary fill; solid primary when active).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';

/// Uppercase section label with an optional trailing text action.
class SearchSectionLabel extends StatelessWidget {
  const SearchSectionLabel(
    this.label, {
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        // An action row is already 44 pt tall (tap target).
        actionLabel == null ? AppSpacing.md : 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.sectionLabel,
              ),
            ),
          ),
          if (actionLabel != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _actionMaxWidth),
              child: Semantics(
                button: true,
                label: actionLabel,
                excludeSemantics: true,
                child: FFPressable(
                  onTap: onAction,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.minTap,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      widthFactor: 1,
                      child: Text(
                        actionLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.body.copyWith(
                          fontSize: _actionSize,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: context.ff.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const double _actionMaxWidth = 180;

  /// "Clear" — Nunito 13.5 w700 on design/06 (`buttonSmall` is Lexend).
  static const double _actionSize = 13.5;
}

/// Pill used by both sections.
class SearchPill extends StatelessWidget {
  const SearchPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.recent = false,
    this.active = false,
    this.semanticLabel,
    super.key,
  });

  /// A recent search (outlined, clock icon) …
  const SearchPill.recent({
    required String term,
    required VoidCallback onTap,
    Key? key,
  }) : this(
         label: term,
         icon: FontAwesomeIcons.clockRotateLeft,
         onTap: onTap,
         recent: true,
         semanticLabel: 'Search again for $term',
         key: key,
       );

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool recent;

  /// … or a filter (soft fill; solid primary when [active]).
  final bool active;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final Color bg = recent
        ? ff.surface
        : active
        ? ff.primary
        : ff.primarySoft;
    final Color fg = active ? ff.onPrimary : ff.primaryStrong;
    final Color iconColor = recent ? ff.primary : fg;
    final Color textColor = recent ? ff.inkMuted : fg;
    return Semantics(
      button: true,
      selected: recent ? null : active,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: context.motion(AppMotion.fast),
          curve: AppMotion.curve,
          constraints: BoxConstraints(
            minHeight: recent ? _recentHeight : _filterHeight,
            maxWidth: _pillMaxWidth,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.pillVertical,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: recent
                ? Border.all(color: ff.chipBorder, width: AppSizes.hairline)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: _iconSize, color: iconColor),
              const SizedBox(width: _iconGap),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.body.copyWith(
                    fontSize: _labelSize,
                    height: 1.3,
                    fontWeight: recent ? FontWeight.w500 : FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Measured on design/06.
  static const double _recentHeight = 36;
  static const double _filterHeight = 34;
  static const double _iconSize = 13;
  static const double _iconGap = 7;
  static const double _labelSize = 13;
  static const double _pillMaxWidth = 300;
}

/// Wrap of pills with the screen gutters.
class SearchPillWrap extends StatelessWidget {
  const SearchPillWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: children,
      ),
    );
  }
}

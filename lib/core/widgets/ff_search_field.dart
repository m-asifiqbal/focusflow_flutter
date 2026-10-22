/// ============================================================
/// FF SEARCH FIELD — 52 pt rounded search input (screens 06/07/10/18)
/// ============================================================
///
/// Primary-tinted magnifier · placeholder · clear button (when non-empty) ·
/// optional filter button (sliders icon) or custom [trailing]. Focus draws a
/// 2 px emerald-400 ring. [readOnly] + [onTap] renders a non-editable
/// button that opens global search. [vault] = dark glass variant.
/// ============================================================
library;

// A nullable preset label resolves to tr() when read (it must follow the
// language), and a private field cannot be a named initializing formal.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

class FFSearchField extends StatefulWidget {
  const FFSearchField({
    this.controller,
    this.focusNode,
    String? hint,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onFilter,
    this.filterActive = false,
    String? filterSemanticLabel,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.vault = false,
    this.trailing,
    this.textInputAction = TextInputAction.search,
    super.key,
  }) : _hint = hint,
       _filterSemanticLabel = filterSemanticLabel;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? _hint;

  /// The given hint, else "Search" in the active language.
  String get hint => _hint ?? tr('Search');
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  /// Shows the sliders filter button when non-null.
  final VoidCallback? onFilter;

  /// Adds a dot to the filter button (filters applied).
  final bool filterActive;
  final String? _filterSemanticLabel;

  /// The given label, else "Filters" in the active language.
  String get filterSemanticLabel => _filterSemanticLabel ?? tr('Filters');
  final bool autofocus;

  /// Non-editable: the whole field becomes a button calling [onTap].
  final bool readOnly;
  final VoidCallback? onTap;

  /// Dark glass vault variant.
  final bool vault;

  /// Extra trailing widget (e.g. vault lock icon).
  final Widget? trailing;
  final TextInputAction textInputAction;

  @override
  State<FFSearchField> createState() => _FFSearchFieldState();
}

class _FFSearchFieldState extends State<FFSearchField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(FFSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_rebuild);
      _focus.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focus.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final vault = widget.vault;
    final focused = !widget.readOnly && _focus.hasFocus;
    final ink = vault ? ff.vaultInk : ff.ink;
    final hintColor = vault ? ff.vaultInkMuted : ff.inkFaint;
    final iconColor = vault ? ff.vaultInkMuted : ff.focusRing;
    final accent = vault ? ff.vaultAccent : ff.primary;
    final Color border = focused
        ? (vault ? ff.vaultAccent : ff.focusRing)
        : (vault ? ff.vaultBorder : ff.surfaceBorder);
    final textStyle = context.text.body.copyWith(
      fontSize: 16,
      height: 1.3,
      color: ink,
    );

    final Widget field = widget.readOnly
        ? Text(
            widget.hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(color: hintColor),
          )
        : TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: widget.textInputAction,
            style: textStyle,
            cursorColor: accent,
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.hint,
              hintMaxLines: 1,
              hintStyle: textStyle.copyWith(color: hintColor),
            ),
          );

    final box = AnimatedContainer(
      duration: context.motion(AppMotion.fast),
      curve: AppMotion.curve,
      constraints: const BoxConstraints(minHeight: AppSizes.search),
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.lg, end: 4),
      decoration: BoxDecoration(
        color: vault ? ff.vaultSurface : ff.surface,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: border, width: focused ? 2 : 1),
        boxShadow: vault ? null : ff.cardShadow,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              FontAwesomeIcons.magnifyingGlass,
              size: 17,
              color: iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: field),
          if (!widget.readOnly && _controller.text.isNotEmpty)
            _IconAction(
              icon: FontAwesomeIcons.solidCircleXmark,
              color: hintColor,
              semanticLabel: tr('Clear search'),
              onTap: _clear,
            )
          else if (widget.trailing == null && widget.onFilter == null)
            const SizedBox(width: AppSpacing.md),
          if (widget.onFilter != null)
            _IconAction(
              icon: FontAwesomeIcons.sliders,
              color: accent,
              semanticLabel: widget.filterSemanticLabel,
              onTap: widget.onFilter!,
              dot: widget.filterActive ? ff.dangerSolid : null,
            ),
          if (widget.trailing != null) ...[
            widget.trailing!,
            const SizedBox(width: AppSpacing.md),
          ],
        ],
      ),
    );

    if (widget.readOnly) {
      return Semantics(
        button: true,
        label: widget.hint,
        excludeSemantics: true,
        child: FFPressable(onTap: widget.onTap, child: box),
      );
    }
    return box;
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
    this.dot,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              if (dot != null)
                PositionedDirectional(
                  top: 10,
                  end: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
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

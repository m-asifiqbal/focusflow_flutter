/// ============================================================
/// THEME PICKER — Light / Dark / System phone previews (screen 32)
/// ============================================================
///
/// Three mini phone screens drawn from the real light/dark token sets
/// (so they follow the chosen accent), a label and a radio. The selected
/// card gets a primary ring, primary label and a filled check. System is
/// half light, half dark.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';

class ThemePicker extends StatelessWidget {
  const ThemePicker({
    required this.selected,
    required this.accent,
    required this.onSelected,
    super.key,
  });

  final ThemeMode selected;
  final AccentColor accent;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return FFCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md + AppSpacing.xxs,
        AppSpacing.md + AppSpacing.xxs,
        AppSpacing.md + AppSpacing.xxs,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, mode) in const [
            ThemeMode.light,
            ThemeMode.dark,
            ThemeMode.system,
          ].indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md - 2),
            Expanded(
              child: _ThemeOption(
                mode: mode,
                accent: accent,
                selected: mode == selected,
                onTap: () => onSelected(mode),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final AccentColor accent;
  final bool selected;
  final VoidCallback onTap;

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final light = FFColors.light(accent);
    final dark = FFColors.dark(accent);
    final label = SettingsLabels.theme(mode);
    final preview = switch (mode) {
      ThemeMode.light => _PhonePreview(colors: light),
      ThemeMode.dark => _PhonePreview(colors: dark),
      ThemeMode.system => Stack(
        fit: StackFit.passthrough,
        children: [
          _PhonePreview(colors: light),
          Positioned.fill(
            child: ClipRect(
              clipper: const _EndHalf(),
              child: _PhonePreview(colors: dark),
            ),
          ),
        ],
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 100 / 152,
              child: Container(
                padding: EdgeInsets.all(selected ? AppSpacing.xxs : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius + 2),
                  border: Border.all(
                    color: selected ? ff.primary : ff.divider,
                    width: selected ? 2.5 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    selected ? _radius - 3 : _radius,
                  ),
                  child: preview,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.cardTitle.copyWith(
                fontWeight: FontWeight.w500,
                color: selected ? ff.primary : ff.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FFCheckCircle(
              checked: selected,
              onChanged: null,
              size: 20,
              tapTarget: 20,
              color: selected ? ff.primary : ff.ink,
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the end half (the right half in LTR) of the child.
class _EndHalf extends CustomClipper<Rect> {
  const _EndHalf();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_EndHalf oldClipper) => false;
}

/// A tiny home screen: title bar · hero card · two rows.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.colors});

  final FFColors colors;

  @override
  Widget build(BuildContext context) {
    final row = colors.isDark ? colors.surfaceMuted : colors.surface;
    return ColoredBox(
      color: colors.canvas,
      child: LayoutBuilder(
        builder: (context, c) {
          final u = c.maxWidth / 100; // 1 unit ≈ 1 pt at the mockup size
          return Padding(
            padding: EdgeInsets.fromLTRB(11 * u, 11 * u, 11 * u, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40 * u,
                  height: 7 * u,
                  decoration: BoxDecoration(
                    color: colors.ink,
                    borderRadius: BorderRadius.circular(4 * u),
                  ),
                ),
                SizedBox(height: 10 * u),
                Container(
                  height: 40 * u,
                  decoration: BoxDecoration(
                    gradient: colors.primaryGradient,
                    borderRadius: BorderRadius.circular(10 * u),
                  ),
                ),
                for (var i = 0; i < 2; i++) ...[
                  SizedBox(height: 7 * u),
                  Container(
                    height: 23 * u,
                    decoration: BoxDecoration(
                      color: row,
                      borderRadius: BorderRadius.circular(8 * u),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

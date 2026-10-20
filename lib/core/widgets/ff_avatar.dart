/// ============================================================
/// FF AVATAR · COLOUR SWATCHES — profile circle and colour pickers
/// ============================================================
///
/// * [FFAvatar] — gradient circle with a white initial (or an image), 2 pt
///   white ring and soft shadow (home header, settings profile card); a
///   rounded square instead when given a [FFAvatar.radius].
/// * [FFColorSwatchRow] — wrapping row of round swatches; the selected one
///   gets a primary ring + tick (note colours, habit colours, accents).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

class FFAvatar extends StatelessWidget {
  const FFAvatar({
    this.initial,
    this.image,
    this.size = 44,
    this.border = true,
    this.radius,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  /// First letter shown when there's no [image].
  final String? initial;
  final ImageProvider? image;
  final double size;

  /// 2 pt white ring + soft shadow.
  final bool border;

  /// Corner radius of a rounded-square avatar; null = a circle.
  final double? radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final g = ff.primaryGradient.colors;
    // Decode the picture at the size it is shown, not at its own resolution.
    final photo = image == null
        ? null
        : ResizeImage.resizeIfNeeded(
            (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            null,
            image!,
          );
    final hasInitial = initial != null && initial!.trim().isNotEmpty;
    final letter = hasInitial
        ? initial!.trim().characters.first.toUpperCase()
        : '';
    final shape = radius == null ? BoxShape.circle : BoxShape.rectangle;
    final corners = radius == null ? null : BorderRadius.circular(radius!);
    final avatar = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: corners,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(g.first, ff.onGradient, 0.35)!,
              Color.lerp(g.last, g.first, 0.4)!,
            ],
          ),
          boxShadow: border ? ff.cardShadow : null,
        ),
        position: DecorationPosition.background,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: corners,
            border: border ? Border.all(color: ff.onGradient, width: 2) : null,
          ),
          child: _clip(
            child: photo != null
                ? Image(image: photo, fit: BoxFit.cover)
                : Center(
                    // No name yet: a person glyph instead of a "?".
                    child: hasInitial
                        ? MediaQuery.withNoTextScaling(
                            child: Text(
                              letter,
                              style: context.text.stat.copyWith(
                                fontSize: size * 0.4,
                                color: ff.onGradient,
                              ),
                            ),
                          )
                        : Icon(
                            FontAwesomeIcons.solidUser,
                            size: size * 0.38,
                            color: ff.onGradient,
                          ),
                  ),
          ),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: onTap == null ? avatar : FFPressable(onTap: onTap, child: avatar),
    );
  }

  /// Clips the picture / initial to the avatar's shape.
  Widget _clip({required Widget child}) => radius == null
      ? ClipOval(child: child)
      : ClipRRect(borderRadius: BorderRadius.circular(radius!), child: child);
}

class FFColorSwatchRow extends StatelessWidget {
  const FFColorSwatchRow({
    required this.colors,
    required this.selected,
    required this.onSelected,
    this.size = 36,
    this.labels,
    super.key,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelected;
  final double size;

  /// Screen-reader names, parallel to [colors] ("Mint", "Amber"…).
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (var i = 0; i < colors.length; i++)
          _Swatch(
            color: colors[i],
            selected: colors[i] == selected,
            size: size,
            ring: ff.primary,
            outline: ff.divider,
            label: labels != null && i < labels!.length
                ? labels![i]
                : 'Colour ${i + 1}',
            onTap: () => onSelected(colors[i]),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.size,
    required this.ring,
    required this.outline,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final double size;
  final Color ring;
  final Color outline;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final hit = size + 8 < AppSizes.minTap ? AppSizes.minTap : size + 8;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.92,
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(AppMotion.fast),
              width: size + 8,
              height: size + 8,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? ring : const Color(0x00000000),
                  width: 2.5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: outline),
                ),
                child: selected
                    ? Icon(
                        FontAwesomeIcons.check,
                        size: size * 0.38,
                        color: dark ? ff.onGradient : ff.ink,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

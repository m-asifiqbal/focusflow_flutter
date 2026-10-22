/// ============================================================
/// NOTE PIN KEYPAD — dots + number pad of the note-lock sheet
/// ============================================================
///
/// What: [NotePinDots] (six slots, filled as digits arrive, shakes on a
/// wrong PIN) and [NotePinKeypad] (3 × 4: digits, ✓ to confirm a 4–5 digit
/// PIN, backspace). Plain views over callbacks — the sheet owns the state.
/// Why: themed with the app's tokens (not the always-dark Vault pad), keys
/// are 56 pt tall (≥ 44 pt tap target) with a Semantics label each.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/services/note_pin.dart';

/// Six PIN slots; [shake] (0 → 1) wobbles them for a wrong PIN.
class NotePinDots extends StatelessWidget {
  const NotePinDots({required this.length, required this.shake, super.key});

  final int length;
  final Animation<double> shake;

  static const double _dot = 14;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      label: tr('PIN, {length} digits entered', {'length': length}),
      liveRegion: true,
      child: AnimatedBuilder(
        animation: shake,
        builder: (context, child) {
          final t = shake.value;
          final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < NotePinService.maxLength; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              AnimatedContainer(
                duration: context.motion(AppMotion.fast),
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < length ? ff.primary : null,
                  border: i < length
                      ? null
                      : Border.all(
                          color: i < NotePinService.minLength
                              ? ff.inkFaint
                              : ff.divider,
                          width: 1.6,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NotePinKeypad extends StatelessWidget {
  const NotePinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onConfirm,
    required this.canConfirm,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// The ✓ key (a PIN of 4–5 digits is confirmed by hand).
  final VoidCallback onConfirm;
  final bool canConfirm;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _Key(label: d, onTap: () => onDigit(d));
    Widget row(List<Widget> keys) => Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(child: keys[i]),
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          row([for (final d in r) digit(d)]),
          const SizedBox(height: _gap),
        ],
        row([
          _Key(
            semanticLabel: tr('Submit PIN'),
            icon: FontAwesomeIcons.check,
            emphasized: true,
            onTap: canConfirm ? onConfirm : null,
          ),
          digit('0'),
          _Key(
            semanticLabel: tr('Delete last digit'),
            icon: FontAwesomeIcons.deleteLeft,
            onTap: onBackspace,
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.onTap,
    this.label,
    this.icon,
    this.semanticLabel,
    this.emphasized = false,
  });

  final VoidCallback? onTap;
  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final enabled = onTap != null;
    final isDigit = label != null;
    final fg = emphasized ? (enabled ? ff.onPrimary : ff.inkFaint) : ff.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.94,
        child: Container(
          height: AppSizes.primaryButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: emphasized
                ? (enabled ? ff.primary : ff.surfaceMuted)
                : (isDigit ? ff.surfaceMuted : null),
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          child: isDigit
              ? Text(label!, style: context.text.stat.copyWith(color: fg))
              : Icon(icon, size: AppSizes.tileGlyph, color: fg),
        ),
      ),
    );
  }
}

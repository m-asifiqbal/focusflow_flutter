/// ============================================================
/// VAULT GENERATOR OPTIONS — the OPTIONS card of screen 21
/// ============================================================
///
/// Per mode: Password = length 8–64 + character sets + avoid ambiguous;
/// Passphrase = words 3–10, separator, capitalise, add number; PIN =
/// digits 4–12. Every change regenerates (controller). [VaultLengthSlider]
/// is the mockup's slider (8-pt emerald track, 24-pt white thumb, min/max
/// under the ends); [VaultOptionSwitch] a 60-pt label + switch row.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_generator_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_generator_state.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Inner horizontal padding of the option rows.
const double _inset = AppSpacing.lg + 1;

class VaultGeneratorOptions extends ConsumerWidget {
  const VaultGeneratorOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(generatorControllerProvider);
    final c = ref.read(generatorControllerProvider.notifier);
    final rows = switch (s.mode) {
      GeneratorMode.password => _password(s.password, c),
      GeneratorMode.passphrase => _passphrase(s.passphrase, c),
      GeneratorMode.pin => [
        VaultLengthSlider(
          label: 'Digits',
          value: s.pinLength,
          min: VaultGeneratorState.minPin,
          max: VaultGeneratorState.maxPin,
          onChanged: c.setPinLength,
        ),
      ],
    };
    return VaultCard(children: rows);
  }

  List<Widget> _password(PasswordOptions o, VaultGeneratorController c) {
    Widget sw(String label, bool v, PasswordOptions Function(bool) f) =>
        VaultOptionSwitch(
          label: label,
          value: v,
          onChanged: (x) => c.setPasswordOptions(f(x)),
        );
    return [
      VaultLengthSlider(
        label: 'Length',
        value: o.length,
        min: PasswordOptions.minLength,
        max: PasswordOptions.maxLength,
        // 16 sits near the middle of the track (mockup 21); long lengths
        // share the last fifth.
        stops: const [(16, 0.45), (32, 0.8)],
        onChanged: (v) => c.setPasswordOptions(o.copyWith(length: v)),
      ),
      sw('Uppercase (A–Z)', o.upper, (v) => o.copyWith(upper: v)),
      sw('Lowercase (a–z)', o.lower, (v) => o.copyWith(lower: v)),
      sw('Numbers (0–9)', o.digits, (v) => o.copyWith(digits: v)),
      sw(r'Symbols (!@#$)', o.symbols, (v) => o.copyWith(symbols: v)),
      sw(
        'Avoid ambiguous (l, 1, O, 0)',
        o.avoidAmbiguous,
        (v) => o.copyWith(avoidAmbiguous: v),
      ),
    ];
  }

  List<Widget> _passphrase(PassphraseOptions o, VaultGeneratorController c) {
    return [
      VaultLengthSlider(
        label: 'Words',
        value: o.words,
        min: PassphraseOptions.minWords,
        max: PassphraseOptions.maxWords,
        onChanged: (v) => c.setPassphraseOptions(o.copyWith(words: v)),
      ),
      _SeparatorRow(
        value: o.separator,
        onChanged: (v) => c.setPassphraseOptions(o.copyWith(separator: v)),
      ),
      VaultOptionSwitch(
        label: 'Capitalise words',
        value: o.capitalize,
        onChanged: (v) => c.setPassphraseOptions(o.copyWith(capitalize: v)),
      ),
      VaultOptionSwitch(
        label: 'Add a number',
        value: o.includeNumber,
        onChanged: (v) => c.setPassphraseOptions(o.copyWith(includeNumber: v)),
      ),
    ];
  }
}

/// "Length ··· 16" + slider + min / max labels.
class VaultLengthSlider extends StatelessWidget {
  const VaultLengthSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.stops = const [],
    super.key,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// Optional inner (value, track position 0–1) breakpoints for a
  /// piecewise-linear track; empty = linear from [min] to [max].
  final List<(int, double)> stops;

  List<(int, double)> get _points => [(min, 0.0), ...stops, (max, 1.0)];

  /// Track position (0–1) of [v].
  @visibleForTesting
  double positionOf(int v) {
    final p = _points;
    for (var i = 1; i < p.length; i++) {
      if (v <= p[i].$1 || i == p.length - 1) {
        final (v0, t0) = p[i - 1];
        final (v1, t1) = p[i];
        final f = ((v - v0) / (v1 - v0)).clamp(0.0, 1.0);
        return t0 + (t1 - t0) * f;
      }
    }
    return 0;
  }

  /// Value at track position [t] (rounded to a whole length).
  @visibleForTesting
  int valueAt(double t) {
    final p = _points;
    for (var i = 1; i < p.length; i++) {
      if (t <= p[i].$2 || i == p.length - 1) {
        final (v0, t0) = p[i - 1];
        final (v1, t1) = p[i];
        final f = t1 == t0 ? 0.0 : ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
        return (v0 + (v1 - v0) * f).round().clamp(min, max);
      }
    }
    return min;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final small = context.text.caption.copyWith(
      fontSize: VaultType.caption,
      fontWeight: FontWeight.w600,
      color: ff.vaultFieldLabel,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        _inset,
        VaultSizes.gapMd,
        _inset,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.vaultValueStyle.copyWith(
                    fontSize: VaultType.row,
                  ),
                ),
              ),
              Text(
                '$value',
                style: context.text.title.copyWith(
                  fontSize: VaultType.value,
                  fontWeight: FontWeight.w700,
                  color: ff.vaultAccentBright,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: VaultSizes.sliderTrack,
              activeTrackColor: ff.vaultAccent,
              inactiveTrackColor: ff.vaultTrack,
              thumbColor: ff.vaultInk,
              overlayColor: ff.vaultAccent.withValues(alpha: 0.12),
              trackShape: const _FullWidthTrack(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: VaultSizes.sliderThumb,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: VaultSizes.sliderOverlay,
              ),
              padding: EdgeInsets.zero,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: SizedBox(
              height: AppSizes.minTap,
              child: Semantics(
                label: label,
                child: stops.isEmpty
                    ? Slider(
                        value: value.toDouble(),
                        min: min.toDouble(),
                        max: max.toDouble(),
                        divisions: max - min,
                        semanticFormatterCallback: (v) => '${v.round()}',
                        onChanged: (v) {
                          if (v.round() != value) onChanged(v.round());
                        },
                      )
                    : Slider(
                        value: positionOf(value),
                        semanticFormatterCallback: (t) => '${valueAt(t)}',
                        onChanged: (t) {
                          final v = valueAt(t);
                          if (v != value) onChanged(v);
                        },
                      ),
              ),
            ),
          ),
          // The min / max labels tuck under the 44-pt slider target.
          Transform.translate(
            offset: const Offset(0, -AppSpacing.sm),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$min', style: small),
                  Text('$max', style: small),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The slider track spans the whole width (the thumb may overhang).
class _FullWidthTrack extends RoundedRectSliderTrackShape {
  const _FullWidthTrack();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 8;
    final top = offset.dy + (parentBox.size.height - h) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, h);
  }
}

/// 60-pt row: label + vault switch (the whole row toggles).
class VaultOptionSwitch extends StatelessWidget {
  const VaultOptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: FFPressable(
        onTap: () => onChanged(!value),
        scale: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: _inset,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.vaultValueStyle.copyWith(
                      fontSize: VaultType.row,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FFSwitch(
                  value: value,
                  vault: true,
                  semanticLabel: label,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Separator choice for passphrases.
class _SeparatorRow extends StatelessWidget {
  const _SeparatorRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _choices = {'-': 'Dash', '.': 'Dot', ' ': 'Space'};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: _inset,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Separator',
            style: context.vaultValueStyle.copyWith(fontSize: VaultType.row),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          FFSegmented<String>(
            vault: true,
            height: VaultSizes.segmented,
            value: value,
            onChanged: onChanged,
            segments: [
              for (final e in _choices.entries)
                FFSegment(value: e.key, label: e.value),
            ],
          ),
        ],
      ),
    );
  }
}

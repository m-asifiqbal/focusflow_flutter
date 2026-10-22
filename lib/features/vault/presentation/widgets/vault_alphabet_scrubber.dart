/// ============================================================
/// VAULT ALPHABET SCRUBBER — the A–Z index on the end edge of long vault
/// lists (screen 18: "Alphabet scrubber on right for long lists")
/// ============================================================
///
/// Shows only the letters present. Tap or drag over it to jump to the
/// first row of that letter; the list owns the scrolling ([onLetter]).
/// Screen-reader users scroll the list normally, so the strip is a single
/// labelled node.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Lists at least this long (A–Z order, no search) get the scrubber.
const int kVaultScrubberMinRows = 30;

/// Index letter of a vault title: A–Z, or '#' for digits / symbols / other
/// scripts.
String vaultIndexLetter(String title) {
  final t = title.trim();
  if (t.isEmpty) return '#';
  final c = t[0].toUpperCase();
  final code = c.codeUnitAt(0);
  return code >= 0x41 && code <= 0x5A ? c : '#';
}

class VaultAlphabetScrubber extends StatefulWidget {
  const VaultAlphabetScrubber({
    required this.letters,
    required this.onLetter,
    this.haptics = true,
    super.key,
  });

  /// Letters in list order (distinct).
  final List<String> letters;
  final ValueChanged<String> onLetter;
  final bool haptics;

  @override
  State<VaultAlphabetScrubber> createState() => _VaultAlphabetScrubberState();
}

class _VaultAlphabetScrubberState extends State<VaultAlphabetScrubber> {
  String? _active;

  void _hit(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    final letters = widget.letters;
    if (box == null || !box.hasSize || letters.isEmpty) return;
    final i = (local.dy / box.size.height * letters.length).floor().clamp(
      0,
      letters.length - 1,
    );
    final letter = letters[i];
    if (letter == _active) return;
    setState(() => _active = letter);
    if (widget.haptics) unawaited(HapticFeedback.selectionClick());
    widget.onLetter(letter);
  }

  void _end() => setState(() => _active = null);

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = context.text.caption.copyWith(
      fontSize: VaultType.micro,
      height: 1.4,
      fontWeight: FontWeight.w800,
    );
    return Semantics(
      container: true,
      label: tr('Alphabet index'),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _hit(d.localPosition),
        onTapUp: (_) => _end(),
        onTapCancel: _end,
        onVerticalDragStart: (d) => _hit(d.localPosition),
        onVerticalDragUpdate: (d) => _hit(d.localPosition),
        onVerticalDragEnd: (_) => _end(),
        onVerticalDragCancel: _end,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final l in widget.letters)
                Text(
                  l,
                  textScaler: TextScaler.noScaling,
                  style: style.copyWith(
                    color: l == _active
                        ? ff.vaultInk
                        : ff.vaultAccent.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

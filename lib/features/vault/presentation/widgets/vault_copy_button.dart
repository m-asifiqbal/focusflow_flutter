/// ============================================================
/// VAULT COPY BUTTON — copy, then a tick that says "done"
/// ============================================================
///
/// What: the vault's copy buttons (list row tile, detail round button). A tap
/// runs [VaultCopyButton.onCopy]; when it really copied, the copy glyph pops
/// into a tick on a green fill with one soft ring pulse, holds for
/// [VaultCopyButton.hold] and turns back into the copy glyph. A refused copy
/// (locked, nothing saved) shows no tick — the toast explains it.
/// Why: the toast alone sits far from the finger; the tick answers right
/// where the user tapped. One controller per button, idle when not copying;
/// reduce motion swaps the glyphs without the pop and the ring.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// The two shapes the vault uses for its copy action.
enum VaultCopyLook {
  /// Round, soft accent fill (detail screen fields).
  round,

  /// Rounded square key-coloured tile (list rows).
  tile,
}

class VaultCopyButton extends StatefulWidget {
  const VaultCopyButton({
    required this.semanticLabel,
    required this.onCopy,
    this.look = VaultCopyLook.round,
    super.key,
  });

  final String semanticLabel;

  /// Copies; true when something was copied (shows the tick).
  final Future<bool> Function() onCopy;
  final VaultCopyLook look;

  /// How long the tick stays.
  static const Duration hold = Duration(milliseconds: 1500);

  @override
  State<VaultCopyButton> createState() => _VaultCopyButtonState();
}

class _VaultCopyButtonState extends State<VaultCopyButton>
    with SingleTickerProviderStateMixin {
  /// The pop + ring of one copy (0 → 1).
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  bool _done = false;
  bool _busy = false;
  Timer? _back;

  @override
  void dispose() {
    _back?.cancel();
    _pop.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_busy) return;
    _busy = true;
    try {
      final copied = await widget.onCopy();
      if (!copied || !mounted) return;
      _back?.cancel();
      setState(() => _done = true);
      if (MediaQuery.disableAnimationsOf(context)) {
        _pop.value = 1;
      } else {
        unawaited(_pop.forward(from: 0));
      }
      _back = Timer(VaultCopyButton.hold, () {
        if (mounted) setState(() => _done = false);
      });
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final round = widget.look == VaultCopyLook.round;
    final size = round ? VaultSizes.roundButton : VaultSizes.smallButton;
    final glyph = round ? VaultSizes.roundGlyph : VaultSizes.iconMd;
    final ok = ff.vaultStrong.fg;
    final idleFill = round ? ff.vaultAccentSoft : ff.vaultKey;
    final idleInk = round ? ff.vaultAccentBright : ff.vaultAccent;
    final radius = round ? null : BorderRadius.circular(AppRadii.tile);
    final shape = round ? BoxShape.circle : BoxShape.rectangle;
    final swap = context.motion(AppMotion.fast);
    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel,
      value: _done ? tr('Copied') : null,
      onTap: () => unawaited(_tap()),
      excludeSemantics: true,
      child: FFPressable(
        onTap: () => unawaited(_tap()),
        scale: 0.92,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: AnimatedBuilder(
            animation: _pop,
            builder: (context, _) {
              final t = _pop.value;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // One ring that grows out of the button and fades.
                  if (_done && t > 0 && t < 1)
                    IgnorePointer(
                      child: Container(
                        width: size * (1 + 0.45 * t),
                        height: size * (1 + 0.45 * t),
                        decoration: BoxDecoration(
                          shape: shape,
                          borderRadius: radius,
                          border: Border.all(
                            color: ok.withValues(alpha: 0.55 * (1 - t)),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: swap,
                    curve: AppMotion.curve,
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _done ? ok.withValues(alpha: 0.22) : idleFill,
                      shape: shape,
                      borderRadius: radius,
                    ),
                    child: AnimatedSwitcher(
                      duration: swap,
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, a) => ScaleTransition(
                        scale: Tween(begin: 0.4, end: 1.0).animate(a),
                        child: FadeTransition(opacity: a, child: child),
                      ),
                      child: _Glyph(
                        key: ValueKey(_done),
                        icon: _done
                            ? FontAwesomeIcons.check
                            : FontAwesomeIcons.solidCopy,
                        size: glyph,
                        color: _done ? ok : idleInk,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A Font Awesome glyph as text (not `Icon`, whose square box clips wide
/// glyphs off-centre — see VaultRoundButton).
class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.icon,
    required this.size,
    required this.color,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(
      String.fromCharCode(icon.codePoint),
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size,
        height: 1,
        color: color,
      ),
    ),
  );
}

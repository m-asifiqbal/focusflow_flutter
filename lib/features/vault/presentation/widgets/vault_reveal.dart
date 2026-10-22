/// ============================================================
/// VAULT REVEAL — the timed eye button and the secret that fades away
/// ============================================================
///
/// What: [VaultRevealButton] is the eye of a secret field. While the secret
/// is shown a ring around the button drains over [duration] (4 s, like the
/// balance eye of the bank app) and the secret hides itself when it is
/// empty; tapping earlier hides it at once. [VaultSecretSwitcher] swaps the
/// masked dots and the revealed value with a soft fade + lift and animates
/// the row's height when the two differ.
/// Why: the timer lives in [VaultAutoHide]; these two are only the picture
/// of it, so a rebuild never restarts or skips the countdown (the ring is
/// keyed by [cycle]). Reduce motion: no ring drain (a full ring stays until
/// the secret hides) and no transitions.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_auto_hide.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';

/// Eye / eye-slash round button with the countdown ring while [open].
class VaultRevealButton extends StatelessWidget {
  const VaultRevealButton({
    required this.open,
    required this.what,
    required this.onTap,
    this.cycle = 0,
    this.duration = VaultAutoHide.defaultDuration,
    super.key,
  });

  /// The secret is shown right now.
  final bool open;

  /// Lower-case name for the screen reader ("password" → "Show password").
  final String what;
  final VoidCallback onTap;

  /// Restarts the ring when it changes ([VaultAutoHide.cycleOf]).
  final int cycle;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final reduce = context.reduceMotion;
    final button = VaultRoundButton(
      icon: open ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
      semanticLabel: open ? 'Hide $what' : 'Show $what',
      onTap: onTap,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        button,
        if (open)
          IgnorePointer(
            child: ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(cycle),
                tween: Tween<double>(begin: 1, end: 0),
                duration: reduce ? Duration.zero : duration,
                builder: (context, value, _) => CustomPaint(
                  size: const Size.square(VaultSizes.roundButton),
                  painter: _CountdownRing(
                    progress: reduce ? 1 : value,
                    color: ff.vaultAccentBright,
                    track: ff.vaultAccent.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ring hugging the round button; [progress] 1 = full, 0 = gone, draining
/// clockwise from 12 o'clock.
class _CountdownRing extends CustomPainter {
  const _CountdownRing({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  static const double _stroke = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CountdownRing old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Cross-fades the masked dots and the revealed secret (fade + a small lift)
/// and animates the height when they differ.
class VaultSecretSwitcher extends StatelessWidget {
  const VaultSecretSwitcher({
    required this.open,
    required this.masked,
    required this.revealed,
    super.key,
  });

  final bool open;
  final Widget masked;
  final Widget revealed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: context.motion(AppMotion.fast),
      curve: AppMotion.curve,
      alignment: AlignmentDirectional.topStart,
      child: AnimatedSwitcher(
        duration: context.motion(const Duration(milliseconds: 320)),
        switchInCurve: AppMotion.curve,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(open),
          child: open ? revealed : masked,
        ),
      ),
    );
  }
}

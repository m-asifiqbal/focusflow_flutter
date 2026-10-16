/// ============================================================
/// VAULT PIN PAD — six PIN dots + the 3 × 4 number pad (screen 17)
/// ============================================================
///
/// Pure view over [vaultPinPadProvider]: [VaultPinDots] (filled emerald,
/// shake on a wrong PIN unless reduce motion is on), [VaultKeypad] (keys
/// 56 pt, radius 16, white 6 %, backspace glyph) and [VaultPadStatusLine]
/// (error / lock-out countdown). Haptics follow Settings › Haptics.
/// ============================================================
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_list_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// The six PIN dots; shakes when [VaultPinPadState.errorTick] changes.
class VaultPinDots extends ConsumerStatefulWidget {
  const VaultPinDots({super.key});

  @override
  ConsumerState<VaultPinDots> createState() => _VaultPinDotsState();
}

class _VaultPinDotsState extends ConsumerState<VaultPinDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final pad = ref.watch(vaultPinPadProvider);
    ref.listen(vaultPinPadProvider.select((s) => s.errorTick), (prev, next) {
      if (prev == null || next == prev) return;
      if (ref.read(settingsProvider).hapticsEnabled) {
        unawaited(HapticFeedback.heavyImpact());
      }
      if (!context.reduceMotion) unawaited(_shake.forward(from: 0));
    });
    const n = VaultPinPadState.pinLength;
    return Semantics(
      label: 'PIN, ${pad.length} of $n digits entered',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              AnimatedContainer(
                duration: context.motion(AppMotion.fast),
                width: VaultSizes.pinDot,
                height: VaultSizes.pinDot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pad.length ? ff.vaultAccent : null,
                  border: i < pad.length
                      ? null
                      : Border.all(
                          color: ff.vaultPinRing,
                          width: VaultSizes.ring,
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

/// Error / lock-out line under the dots (keeps its height when empty so
/// the pad doesn't jump).
class VaultPadStatusLine extends ConsumerWidget {
  const VaultPadStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final pad = ref.watch(vaultPinPadProvider);
    final until = ref.watch(vaultPinPadProvider.notifier).lockedUntil;
    final style = context.text.meta.copyWith(color: ff.vaultAlert.fg);
    Widget child;
    if (until != null && VaultPinPadController.checksPin(pad.step)) {
      child = _LockoutCountdown(until: until, style: style);
    } else if (pad.message != null) {
      child = Text(pad.message!, textAlign: TextAlign.center, style: style);
    } else if (pad.busy) {
      child = Text(
        'Checking…',
        style: context.text.meta.copyWith(color: ff.vaultInkMuted),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: VaultSizes.pinMessage),
      child: Center(child: Semantics(liveRegion: true, child: child)),
    );
  }
}

class _LockoutCountdown extends ConsumerStatefulWidget {
  const _LockoutCountdown({required this.until, required this.style});

  final DateTime until;
  final TextStyle style;

  @override
  ConsumerState<_LockoutCountdown> createState() => _LockoutCountdownState();
}

class _LockoutCountdownState extends ConsumerState<_LockoutCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).now();
    final left = widget.until.difference(now);
    if (left <= Duration.zero) {
      _timer?.cancel();
      return const SizedBox.shrink();
    }
    return Text(
      'Too many attempts · try again in ${formatCountdown(left)}',
      textAlign: TextAlign.center,
      style: widget.style,
    );
  }
}

/// 3 × 4 number pad: 1–9, blank, 0, backspace.
class VaultKeypad extends ConsumerWidget {
  const VaultKeypad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = ref.read(vaultPinPadProvider.notifier);
    final haptics = ref.watch(settingsProvider.select((s) => s.hapticsEnabled));
    void tap(VoidCallback action) {
      if (haptics) unawaited(HapticFeedback.selectionClick());
      action();
    }

    Widget digit(String d) =>
        _Key(label: d, onTap: () => tap(() => unawaited(pad.input(d))));

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows) ...[
          _KeyRow(children: [for (final d in row) digit(d)]),
          const SizedBox(height: _gap),
        ],
        _KeyRow(
          children: [
            const SizedBox.shrink(),
            digit('0'),
            _Key(
              semanticLabel: 'Delete last digit',
              icon: FontAwesomeIcons.deleteLeft,
              onTap: () => tap(pad.backspace),
            ),
          ],
        ),
      ],
    );
  }
}

const double _gap = 10;

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, this.label, this.icon, this.semanticLabel});

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final isDigit = label != null;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.94,
        child: Container(
          height: AppSizes.primaryButton,
          alignment: Alignment.center,
          decoration: isDigit
              ? BoxDecoration(
                  color: ff.vaultKey,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                )
              : null,
          child: isDigit
              ? Text(
                  label!,
                  textScaler: TextScaler.noScaling,
                  style: context.text.title.copyWith(
                    fontSize: VaultType.headline,
                    fontWeight: FontWeight.w600,
                    color: ff.vaultInk,
                  ),
                )
              : Icon(icon, size: VaultSizes.iconXl, color: ff.vaultAccent),
        ),
      ),
    );
  }
}

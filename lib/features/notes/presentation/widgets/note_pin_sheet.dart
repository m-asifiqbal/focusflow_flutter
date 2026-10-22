/// ============================================================
/// NOTE PIN SHEET — choose or enter the PIN of one note
/// ============================================================
///
/// What: a bottom sheet with the PIN dots and number pad.
///   * [NotePinMode.create] — "Set a PIN" then "Confirm PIN" (4–6 digits;
///     a mismatch starts over). Returns the confirmed PIN.
///   * [NotePinMode.verify] — "Enter PIN"; the caller's `verify` decides.
///     Wrong PINs shake the dots, count up, and after three in a row lock
///     the pad for a growing time ([NotePinBackoff], per note).
/// Returns the PIN, or null when the sheet was dismissed. The PIN lives only
/// in this widget's state while the sheet is open — never logged or stored.
/// Why: every note has its own PIN, so this replaces the Vault PIN sheet for
/// notes; the verifier is checked by the caller (Argon2 runs off the UI
/// thread), the sheet just shows "Checking…".
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/services/note_pin.dart';
import 'package:focusflow/features/notes/presentation/providers/note_lock_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_pin_keypad.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

enum NotePinMode { create, verify }

/// Opens the sheet; the PIN (create: confirmed twice; verify: accepted by
/// [verify]) or null when dismissed. [guardKey] (the note id) keys the
/// wrong-PIN back-off of verify mode.
Future<String?> showNotePinSheet(
  BuildContext context, {
  required NotePinMode mode,
  String? title,
  String? subtitle,
  String? guardKey,
  Future<bool> Function(String pin)? verify,
}) {
  assert(mode == NotePinMode.create || verify != null);
  return showFFBottomSheet<String>(
    context,
    builder: (_) => NotePinSheet(
      mode: mode,
      title: title,
      subtitle: subtitle,
      guardKey: guardKey,
      verify: verify,
    ),
  );
}

class NotePinSheet extends ConsumerStatefulWidget {
  const NotePinSheet({
    required this.mode,
    this.title,
    this.subtitle,
    this.guardKey,
    this.verify,
    super.key,
  });

  final NotePinMode mode;
  final String? title;
  final String? subtitle;
  final String? guardKey;
  final Future<bool> Function(String pin)? verify;

  @override
  ConsumerState<NotePinSheet> createState() => _NotePinSheetState();
}

class _NotePinSheetState extends ConsumerState<NotePinSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Timer? _tick;
  String _pin = '';

  /// Create mode: the PIN typed first, waiting for its confirmation.
  String? _first;
  String? _error;
  bool _busy = false;

  bool get _create => widget.mode == NotePinMode.create;
  bool get _confirming => _create && _first != null;

  @override
  void initState() {
    super.initState();
    // Reopening a note that is still locked out shows the countdown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncLockout();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _shake.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider).now();

  Duration get _lockedFor {
    final key = widget.guardKey;
    if (_create || key == null) return Duration.zero;
    return ref.read(notePinAttemptsProvider.notifier).remaining(key, _now);
  }

  /// While locked out, re-render each second for the countdown line.
  void _syncLockout() {
    _tick?.cancel();
    if (_lockedFor == Duration.zero) return;
    setState(() {});
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lockedFor == Duration.zero) _tick?.cancel();
      setState(() {});
    });
  }

  void _buzz({bool heavy = false}) {
    if (!ref.read(settingsProvider).hapticsEnabled) return;
    unawaited(
      heavy ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick(),
    );
  }

  void _digit(String d) {
    if (_busy || _lockedFor > Duration.zero) return;
    if (_pin.length >= NotePinService.maxLength) return;
    _buzz();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == NotePinService.maxLength) unawaited(_submit());
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    _buzz();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _wrong(String message) {
    _buzz(heavy: true);
    if (!context.reduceMotion) unawaited(_shake.forward(from: 0));
    setState(() {
      _pin = '';
      _busy = false;
      _error = message;
    });
  }

  Future<void> _submit() async {
    final pin = _pin;
    if (_busy || !NotePinService.isValidPin(pin)) return;
    if (_create) {
      final first = _first;
      if (first == null) {
        setState(() {
          _first = pin;
          _pin = '';
        });
      } else if (first == pin) {
        Navigator.of(context).pop(pin);
      } else {
        _first = null;
        _wrong(tr("PINs don't match. Choose a PIN again."));
      }
      return;
    }
    setState(() => _busy = true);
    final bool ok;
    try {
      ok = await widget.verify!(pin);
    } on Object {
      if (mounted) _wrong(tr("Couldn't check the PIN. Try again."));
      return;
    }
    if (!mounted) return;
    final attempts = ref.read(notePinAttemptsProvider.notifier);
    final key = widget.guardKey;
    if (ok) {
      if (key != null) attempts.succeeded(key);
      Navigator.of(context).pop(pin);
      return;
    }
    if (key != null) attempts.failed(key, _now);
    _wrong(tr('Wrong PIN'));
    _syncLockout();
  }

  String get _heading =>
      widget.title ??
      (_create
          ? (_confirming ? tr('Confirm PIN') : tr('Set a PIN for this note'))
          : tr('Enter PIN'));

  String get _hint {
    if (_create) {
      return _confirming
          ? tr('Enter the same PIN again.')
          : tr(
              'Only this note uses it. Choose 4–6 digits, then tap the check key.',
            );
    }
    return widget.subtitle ?? tr('This note has its own PIN.');
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final colors = ModuleStyle.notes.colors;
    final locked = _lockedFor;
    final message = locked > Duration.zero
        ? tr('Too many wrong PINs. Try again in {time}.', {
            'time': _format(locked),
          })
        : _busy
        ? tr('Checking…')
        : _error;
    final isError = !_busy && message != null;
    // showFFBottomSheet wraps this in the floating sheet card.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.minTap + AppSpacing.sm,
          height: AppSizes.minTap + AppSpacing.sm,
          decoration: BoxDecoration(
            color: colors.softFor(ff.brightness),
            shape: BoxShape.circle,
          ),
          child: Icon(
            FontAwesomeIcons.lock,
            size: AppSizes.tileGlyph + 4,
            color: colors.inkFor(ff.brightness),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            _heading,
            textAlign: TextAlign.center,
            style: context.text.sectionTitle,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _hint,
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(color: ff.inkMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
        NotePinDots(length: _pin.length, shake: _shake),
        // Keeps its height empty so the pad doesn't jump.
        Semantics(
          liveRegion: true,
          child: SizedBox(
            height: AppSpacing.xxl + AppSpacing.md,
            child: Center(
              child: message == null
                  ? null
                  : Text(
                      message,
                      textAlign: TextAlign.center,
                      style: context.text.meta.copyWith(
                        color: isError ? ff.danger : ff.inkMuted,
                      ),
                    ),
            ),
          ),
        ),
        NotePinKeypad(
          onDigit: _digit,
          onBackspace: _backspace,
          onConfirm: () => unawaited(_submit()),
          canConfirm:
              !_busy &&
              locked == Duration.zero &&
              NotePinService.isValidPin(_pin),
        ),
      ],
    );
  }

  static String _format(Duration d) => d.inMinutes >= 1
      ? tr('{m} min {s} s', {'m': d.inMinutes, 's': d.inSeconds % 60})
      : tr('{s} s', {'s': d.inSeconds.clamp(1, 59)});
}

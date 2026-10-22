/// ============================================================
/// VAULT LOCK CARD — the radius-30 glass card of screen 17
/// ============================================================
///
/// Ringed face / fingerprint icon · "Vault Locked" · explanation ·
/// "Unlock with Face ID" (when biometrics are ready) · PIN dots · status
/// line · number pad · "Use master PIN instead" / "Forgot PIN?".
/// First run turns it into "Create master PIN" → "Confirm your PIN".
/// Also used (without the outer card) by the unlock sheet.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_pin_pad.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_primary_button.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_recovery_dialogs.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// "Face ID" / "fingerprint" / "biometrics".
String biometricName(BiometricKind kind) => switch (kind) {
  BiometricKind.face => 'Face ID',
  BiometricKind.fingerprint => 'fingerprint',
  _ => 'biometrics',
};

class VaultLockCard extends ConsumerStatefulWidget {
  const VaultLockCard({this.framed = true, this.autoPrompt = true, super.key});

  /// Draw the glass card (lock screen) or just the content (sheet).
  final bool framed;

  /// Show the biometric prompt once when the card appears.
  final bool autoPrompt;

  @override
  ConsumerState<VaultLockCard> createState() => _VaultLockCardState();
}

class _VaultLockCardState extends ConsumerState<VaultLockCard> {
  /// "Use master PIN instead" hides the biometric button.
  bool _pinOnly = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
    }
  }

  Future<void> _autoPrompt() async {
    final session = ref.read(vaultSessionProvider.notifier);
    await session.ready;
    if (!mounted) return;
    final s = ref.read(vaultSessionProvider);
    final pinDigits = ref.read(vaultPinPadProvider).length;
    if (!s.isUnlocked && s.biometricsReady && !_pinOnly && pinDigits == 0) {
      await _biometrics();
    }
  }

  Future<void> _biometrics() async {
    if (_prompting || !mounted) return;
    setState(() => _prompting = true);
    try {
      await ref.read(vaultSessionProvider.notifier).unlockWithBiometrics();
    } finally {
      if (mounted) setState(() => _prompting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final session = ref.watch(vaultSessionProvider);
    final step = ref.watch(vaultPinPadProvider.select((s) => s.step));
    final pinDigits = ref.watch(vaultPinPadProvider.select((s) => s.length));
    final unlocking = step == VaultPadStep.unlock;
    final showBio = unlocking && session.biometricsReady && !_pinOnly;
    final bio = biometricName(session.biometricKind);

    final (title, body) = switch (step) {
      VaultPadStep.unlock => (
        'Vault Locked',
        session.biometricsReady
            ? 'Use ${bio == 'Face ID' ? 'Face ID / fingerprint' : bio} or '
                  'your master PIN to view your accounts.'
            : 'Enter your 6-digit master PIN to view your accounts.',
      ),
      VaultPadStep.create => (
        'Create master PIN',
        'Choose a 6-digit PIN. It encrypts your vault and is never stored '
            'or sent anywhere.',
      ),
      VaultPadStep.confirm || VaultPadStep.changeConfirm => (
        'Confirm your PIN',
        'Enter the same 6 digits again.',
      ),
      // Re-auth steps are shown by the Vault security sheet, not here.
      VaultPadStep.verify => ('Enter master PIN', ''),
      VaultPadStep.changeNew => ('New master PIN', ''),
    };

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RingedIcon(
          icon: !unlocking
              ? FontAwesomeIcons.lock
              : session.biometricKind == BiometricKind.fingerprint
              ? FontAwesomeIcons.fingerprint
              : FontAwesomeIcons.solidFaceSmile,
        ),
        const SizedBox(height: AppSpacing.md + 2),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.title.copyWith(
              fontSize: VaultType.headline,
              fontWeight: FontWeight.w600,
              color: ff.vaultInk,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          body,
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(
            fontSize: VaultType.subtitle,
            height: 1.7,
            color: ff.vaultInkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (showBio) ...[
          VaultPrimaryButton(
            label: 'Unlock with $bio',
            icon: FontAwesomeIcons.fingerprint,
            loading: _prompting && pinDigits == 0,
            onPressed: _biometrics,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        const VaultPinDots(),
        const VaultPadStatusLine(),
        const VaultKeypad(),
        _footerLink(step, session.biometricsReady),
      ],
    );

    if (!widget.framed) return content;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: ff.vaultSurface,
        borderRadius: BorderRadius.circular(AppRadii.dialog),
        border: Border.all(color: ff.vaultBorder),
      ),
      child: content,
    );
  }

  Widget _footerLink(VaultPadStep step, bool bioReady) {
    final ff = context.ff;
    final (label, onTap) = switch (step) {
      VaultPadStep.unlock when bioReady && !_pinOnly => (
        'Use master PIN instead',
        () => setState(() {
          _pinOnly = true;
          _prompting = false;
        }),
      ),
      VaultPadStep.unlock => (
        'Forgot PIN?',
        () => unawaited(showVaultRecoveryDialog(context)),
      ),
      VaultPadStep.confirm => (
        'Start over',
        () => ref.read(vaultPinPadProvider.notifier).restartSetup(),
      ),
      VaultPadStep.create ||
      VaultPadStep.verify ||
      VaultPadStep.changeNew ||
      VaultPadStep.changeConfirm => (null, null),
    };
    if (label == null) {
      return const SizedBox(height: AppSizes.minTap);
    }
    return FFTextButton(
      label: label,
      onPressed: onTap,
      color: ff.vaultAccent,
      style: context.text.bodySmall.copyWith(
        fontSize: VaultType.secondary,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md),
    );
  }
}

/// 96 pt faint ring around an 80 pt emerald disc with the glyph.
class _RingedIcon extends StatelessWidget {
  const _RingedIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return ExcludeSemantics(
      child: Container(
        width: VaultSizes.lockRingOuter,
        height: VaultSizes.lockRingOuter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ff.vaultInk.withValues(alpha: 0.03),
        ),
        child: Container(
          width: VaultSizes.lockRingInner,
          height: VaultSizes.lockRingInner,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ff.vaultAccent.withValues(alpha: 0.14),
          ),
          child: Icon(
            icon,
            size: VaultSizes.lockGlyph,
            color: ff.vaultStrong.fg,
          ),
        ),
      ),
    );
  }
}

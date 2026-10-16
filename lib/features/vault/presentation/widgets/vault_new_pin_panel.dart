/// ============================================================
/// VAULT NEW PIN PANEL — finish a "Forgot PIN?" recovery + new kit codes
/// ============================================================
///
/// After a recovery-code unlock the vault is open but still wrapped by the
/// forgotten PIN. [showVaultNewPinSheet] forces the next steps (the sheet
/// cannot be dismissed until done):
///   1. choose + confirm a new PIN (VaultPinPadController.startNewPin →
///      VaultSessionController.completePinReset re-wraps the data key,
///      re-keys backup encryption and PREPARES a new recovery code);
///   2. [VaultNewRecoveryCode] shows the new code. Only "I've saved it"
///      commits it (the used code stops working then); "Keep my old code"
///      discards it and the old one stays valid (two-phase).
/// The code is shown as plain, non-selectable text; "Copy code" goes
/// through the secure clipboard (auto-clear). Nothing is logged.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_pin_pad.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_screen_guard.dart';

/// The non-dismissible "Set a new PIN" sheet. [context] may be any context
/// below the root navigator (e.g. `Navigator.of(ctx, rootNavigator: true)
/// .context` when the caller's own widget is going away).
Future<void> showVaultNewPinSheet(BuildContext context) =>
    showFFBottomSheet<void>(
      context,
      vault: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) =>
          const VaultTheme(child: VaultScreenGuard(child: VaultNewPinPanel())),
    );

/// Sheet body (public for tests).
class VaultNewPinPanel extends ConsumerStatefulWidget {
  const VaultNewPinPanel({super.key});

  @override
  ConsumerState<VaultNewPinPanel> createState() => _VaultNewPinPanelState();
}

class _VaultNewPinPanelState extends ConsumerState<VaultNewPinPanel> {
  bool _ready = false;
  String? _code;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(vaultPinPadProvider.notifier).startNewPin();
      setState(() => _ready = true);
    });
  }

  void _close() {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final pad = ref.watch(vaultPinPadProvider);
    ref.listen(vaultPinPadProvider.select((p) => p.done), (_, done) {
      if (!done || !_ready) return;
      setState(
        () =>
            _code = ref.read(vaultSessionProvider.notifier).pendingRecoveryCode,
      );
      if (_code == null) _close();
    });
    ref.listen(vaultSessionProvider.select((s) => s.isUnlocked), (_, open) {
      if (!open) _close(); // locked meanwhile: recovery starts over
    });
    final code = _code;
    final Widget body;
    if (code != null) {
      body = VaultNewRecoveryCode(code: code, onFinished: _close);
    } else {
      final confirming = _ready && pad.step == VaultPadStep.changeConfirm;
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              confirming ? 'Confirm new PIN' : 'Set a new PIN',
              textAlign: TextAlign.center,
              style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            confirming
                ? 'Enter the same 6 digits again.'
                : 'Your vault was opened with the recovery code. Choose a '
                      'new 6-digit master PIN to finish.',
            textAlign: TextAlign.center,
            style: context.text.body.copyWith(color: ff.vaultSubtitle),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const VaultPinDots(),
          const SizedBox(height: AppSpacing.md),
          const VaultPadStatusLine(),
          const SizedBox(height: AppSpacing.lg),
          const VaultKeypad(),
          const SizedBox(height: AppSpacing.sm),
          if (confirming)
            FFTextButton(
              label: 'Start over',
              onPressed: () =>
                  ref.read(vaultPinPadProvider.notifier).restartSetup(),
            )
          else
            const SizedBox(height: AppSizes.minTap),
        ],
      );
    }
    return PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xxl,
          AppSpacing.sm,
          AppSpacing.xxl,
          AppSpacing.lg,
        ),
        child: body,
      ),
    );
  }
}

/// Shows a newly prepared recovery [code]; commits it only after "I've
/// saved it". Used after a PIN reset (and reusable for any new code).
class VaultNewRecoveryCode extends ConsumerStatefulWidget {
  const VaultNewRecoveryCode({
    required this.code,
    required this.onFinished,
    super.key,
  });

  final String code;
  final VoidCallback onFinished;

  @override
  ConsumerState<VaultNewRecoveryCode> createState() =>
      _VaultNewRecoveryCodeState();
}

class _VaultNewRecoveryCodeState extends ConsumerState<VaultNewRecoveryCode> {
  bool _busy = false;

  Future<void> _commit() async {
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await ref.read(vaultSessionProvider.notifier).commitRecoveryCode();
    } on Object {
      ok = false;
    }
    if (!mounted) return;
    showFFToast(
      context,
      ok ? 'New PIN and recovery code saved' : "Couldn't save the new code",
    );
    widget.onFinished();
  }

  void _keepOld() {
    ref.read(vaultSessionProvider.notifier).discardRecoveryCode();
    showFFToast(context, 'New PIN saved · your old recovery code still works');
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Your new recovery code',
            textAlign: TextAlign.center,
            style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Write it down or print a new Recovery Kit. Once you confirm, the '
          'code you just used stops working.',
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: ff.vaultSubtitle),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          widget.code,
          textAlign: TextAlign.center,
          style: context.text.mono.copyWith(
            fontSize: VaultType.nav,
            color: ff.vaultAccent,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FFSecondaryButton(
          label: 'Copy code',
          icon: FontAwesomeIcons.solidCopy,
          onPressed: () async {
            await ref
                .read(secureClipboardProvider)
                .copy(widget.code, clearAfter: const Duration(seconds: 60));
            if (context.mounted) {
              showFFToast(context, 'Recovery code copied · clears in 60s');
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        FFPrimaryButton(
          label: "I've saved it",
          loading: _busy,
          onPressed: _busy ? null : _commit,
        ),
        FFTextButton(label: 'Keep my old code', onPressed: _keepOld),
      ],
    );
  }
}

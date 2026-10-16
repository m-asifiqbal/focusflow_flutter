/// ============================================================
/// ACCOUNT DANGER ZONE — Sign out · Erase local data · Delete account
/// ============================================================
///
/// * Sign out (signed-in only) — simple confirm; local data stays.
/// * Erase local data (orange) — type DELETE (+ vault PIN when a vault
///   exists); wipes this device and returns to onboarding. Drive backups
///   are kept.
/// * Delete account & Drive data (rose, signed-in only) — same
///   confirmation; deletes the app's Drive folder first, then erases. A
///   part-way stop reports exactly what was deleted / erased.
/// The busy row shows a spinner; other rows are disabled meanwhile.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/notifiers/account_actions_controller.dart';
import 'package:focusflow/features/auth/presentation/widgets/danger_confirm_dialog.dart';
import 'package:go_router/go_router.dart';

/// Orange of "Erase local data" (tile + text, orange-600 text in light).
const ModuleColors _eraseTint = ModuleColors(
  solid: AppPalette.orange500,
  soft: AppPalette.orange100,
  ink: AppPalette.orange600,
);

class AccountDangerSection extends ConsumerWidget {
  const AccountDangerSection({super.key});

  void _toast(BuildContext context, String message, {bool error = false}) =>
      showUndoSnackbar(
        context,
        message: message,
        icon: error
            ? FontAwesomeIcons.triangleExclamation
            : FontAwesomeIcons.circleCheck,
      );

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showFFConfirm(
      context,
      title: 'Sign out?',
      message:
          'Your notes, tasks and vault stay on this device. Drive backups '
          'are kept — sign in again any time to sync.',
      confirmLabel: 'Sign out',
      icon: FontAwesomeIcons.arrowRightFromBracket,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(accountActionsProvider.notifier).signOut();
      if (context.mounted) _toast(context, 'Signed out');
    } on Object {
      if (context.mounted) {
        _toast(context, "Couldn't sign out. Try again.", error: true);
      }
    }
  }

  Future<void> _erase(
    BuildContext context,
    WidgetRef ref, {
    required bool deleteAccount,
  }) async {
    final actions = ref.read(accountActionsProvider.notifier);
    final askPin = await actions.hasVault();
    if (!context.mounted) return;
    final ok = await showDangerConfirm(
      context,
      title: deleteAccount
          ? 'Delete account & Drive data?'
          : 'Erase local data?',
      message: deleteAccount
          ? 'This permanently deletes every backup and sync file in your '
                "Google Drive app folder, then erases this device's data. "
                'This can’t be undone.'
          : 'Everything on this device — items, vault, files and settings — '
                'is erased. Backups in Google Drive are kept.',
      confirmLabel: deleteAccount ? 'Delete everything' : 'Erase',
      askPin: askPin,
      verifyPin: actions.verifyVaultPin,
      icon: deleteAccount
          ? FontAwesomeIcons.userXmark
          : FontAwesomeIcons.eraser,
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    try {
      if (deleteAccount) {
        await actions.deleteAccountAndDriveData();
      } else {
        await actions.eraseLocalData();
      }
      router.go(AppRoutes.onboarding);
    } on AccountActionFailure catch (e) {
      // Says exactly what was and wasn't done (partial Drive delete, …).
      if (context.mounted) _toast(context, e.message, error: true);
    } on Object {
      if (context.mounted) {
        _toast(context, "Couldn't erase everything. Try again.", error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final b = Theme.of(context).brightness;
    final busy = ref.watch(accountActionsProvider);
    final signedIn = ref.watch(cloudAccountProvider) != null;
    VoidCallback? idle(VoidCallback f) => busy == null ? f : null;

    return FFGroupedList(
      label: 'Danger zone',
      dividerIndent:
          AppSpacing.lg + AppSizes.iconTileSm + AppSpacing.rowLeadingGap,
      children: [
        if (signedIn)
          _DangerRow(
            icon: FontAwesomeIcons.arrowRightFromBracket,
            tint: ActionTints.lock,
            title: 'Sign out',
            color: ff.ink,
            busy: busy == AccountAction.signOut,
            onTap: idle(() => _signOut(context, ref)),
          ),
        _DangerRow(
          icon: FontAwesomeIcons.eraser,
          tint: _eraseTint,
          title: 'Erase local data',
          color: _eraseTint.inkFor(b),
          busy: busy == AccountAction.erase,
          onTap: idle(() => _erase(context, ref, deleteAccount: false)),
        ),
        if (signedIn)
          _DangerRow(
            icon: FontAwesomeIcons.userXmark,
            tint: ModuleStyle.scan.colors,
            title: 'Delete account & Drive data',
            color: ff.dangerStrong,
            busy: busy == AccountAction.deleteAccount,
            onTap: idle(() => _erase(context, ref, deleteAccount: true)),
          ),
      ],
    );
  }
}

/// A grouped-list row with a coloured title (FFListRow only knows ink and
/// rose) and a spinner while its action runs.
class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final ModuleColors tint;
  final String title;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.rowVertical,
            ),
            child: Row(
              children: [
                FFIconTile(
                  icon: icon,
                  colors: tint,
                  size: AppSizes.iconTileSm,
                  iconSize: 15,
                ),
                const SizedBox(width: AppSpacing.rowLeadingGap),
                Expanded(
                  child: Text(
                    title,
                    style: context.text.rowTitle.copyWith(color: color),
                  ),
                ),
                if (busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// FF SNACKBAR — dark-emerald undo snackbar + toast (screen 28 bottom)
/// ============================================================
///
/// Every destructive action shows [showUndoSnackbar] for 5 s
/// ([AppMotion.snackbar]). Only one snackbar is ever visible: showing a new
/// one removes the current one (and any queue) immediately. [showFFToast]
/// is the same pill without an action, for short confirmations.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';

/// The snackbar's visual: icon · message · optional action ("UNDO").
class FFSnackbar extends StatelessWidget {
  const FFSnackbar({
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        actionLabel == null ? AppSpacing.lg : AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ff.snackbar,
        borderRadius: BorderRadius.circular(AppRadii.button),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 14),
            blurRadius: 30,
            spreadRadius: -12,
            color: ff.snackbar.withValues(alpha: 0.5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: ff.snackbarAction),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.rowTitle.copyWith(color: ff.onSnackbar),
            ),
          ),
          if (actionLabel != null)
            Semantics(
              button: true,
              label: actionLabel,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.minTap,
                    minWidth: AppSizes.minTap,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        actionLabel!.toUpperCase(),
                        maxLines: 1,
                        style: context.text.button.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: ff.snackbarAction,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows the undo snackbar, replacing any visible one. [onUndo] runs at
/// most once, and the snackbar closes when it's tapped.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoSnackbar(
  BuildContext context, {
  required String message,
  IconData? icon,
  VoidCallback? onUndo,
  Duration duration = AppMotion.snackbar,
  String undoLabel = 'UNDO',
}) {
  final messenger = ScaffoldMessenger.of(context);
  var used = false;
  return _show(
    messenger,
    duration: duration,
    content: FFSnackbar(
      message: message,
      icon: icon,
      actionLabel: onUndo == null ? null : undoLabel,
      onAction: onUndo == null
          ? null
          : () {
              if (used) return;
              used = true;
              messenger.hideCurrentSnackBar(
                reason: SnackBarClosedReason.action,
              );
              onUndo();
            },
    ),
  );
}

/// Short confirmation pill without an action ("Copied", "Saved").
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showFFToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = const Duration(seconds: 2),
}) {
  return _show(
    ScaffoldMessenger.of(context),
    duration: duration,
    content: FFSnackbar(message: message, icon: icon),
  );
}

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _show(
  ScaffoldMessengerState messenger, {
  required Widget content,
  required Duration duration,
}) {
  messenger
    ..clearSnackBars()
    ..removeCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: content,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      // Sits close above the nav pill (which already adds 8 dp of its own).
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.none,
    ),
  );
}

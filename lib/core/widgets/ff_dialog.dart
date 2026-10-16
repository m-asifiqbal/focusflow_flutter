/// ============================================================
/// FF DIALOG — centred 30-radius dialog + delete / confirm helpers
/// ============================================================
///
/// * [FFDialog] — ringed icon · title · message · stacked full-width actions
///   (screen 28).
/// * [showFFDialog] — fade/scale-in route with `ff.scrim` + blur barrier.
/// * [confirmDelete] → [DeleteChoice] (delete / archive instead / cancel);
///   the copy names **Recently Deleted** and the 30-day purge.
/// * [showFFConfirm] → bool (discard changes, sign out…).
/// * [showFFTextConfirm] → bool, enabled only after typing e.g. "DELETE".
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_buttons.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_blur_barrier.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

/// Result of [confirmDelete].
enum DeleteChoice { delete, archive, cancel }

/// Pushes [builder] as a centred dialog (fade + 0.94→1 scale).
Future<T?> showFFDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final reduce = context.reduceMotion;
  return navigator.push<T>(
    _FFDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      barrierColor: context.ff.scrim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: reduce ? Duration.zero : AppMotion.normal,
      pageBuilder: (ctx, _, _) => themes.wrap(Builder(builder: builder)),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.curve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _FFDialogRoute<T> extends RawDialogRoute<T> {
  _FFDialogRoute({
    required super.pageBuilder,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
    super.transitionDuration,
    super.transitionBuilder,
  });

  @override
  Widget buildModalBarrier() =>
      ffBlurBarrier(super.buildModalBarrier(), animation);
}

class FFDialog extends StatelessWidget {
  const FFDialog({
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.title,
    this.message,
    this.messageWidget,
    this.content,
    this.actions = const [],
    super.key,
  });

  final IconData? icon;

  /// Icon colour (defaults to primary).
  final Color? iconColor;

  /// Ring fill (defaults to [iconColor] @12%).
  final Color? iconBackground;
  final String? title;
  final String? message;

  /// Rich message (wins over [message]).
  final Widget? messageWidget;

  /// Extra content between message and actions (text field…).
  final Widget? content;

  /// Stacked full-width buttons, 10 pt apart.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final media = MediaQuery.of(context);
    final bg = Theme.of(context).dialogTheme.backgroundColor ?? ff.surface;
    final accent = iconColor ?? ff.primary;
    final ring = iconBackground ?? accent.withValues(alpha: 0.12);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: Material(
                color: bg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.dialog),
                  side: BorderSide(color: ff.surfaceBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xxl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (icon != null) ...[
                        Center(
                          child: _RingedIcon(
                            icon: icon!,
                            color: accent,
                            fill: ring,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (title != null)
                        Semantics(
                          header: true,
                          child: Text(
                            title!,
                            textAlign: TextAlign.center,
                            style: context.text.title,
                          ),
                        ),
                      if (messageWidget != null || message != null) ...[
                        const SizedBox(height: 10),
                        DefaultTextStyle.merge(
                          textAlign: TextAlign.center,
                          style: context.text.body,
                          child:
                              messageWidget ??
                              Text(message!, textAlign: TextAlign.center),
                        ),
                      ],
                      if (content != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        content!,
                      ],
                      if (actions.isNotEmpty) const SizedBox(height: 22),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        actions[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingedIcon extends StatelessWidget {
  const _RingedIcon({
    required this.icon,
    required this.color,
    required this.fill,
  });

  final IconData icon;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill.withValues(alpha: fill.a * 0.45),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Icon(icon, size: 26, color: color),
      ),
    );
  }
}

/// Muted "Cancel" text action used at the bottom of dialogs.
class _CancelAction extends StatelessWidget {
  const _CancelAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FFTextButton(
      label: label,
      onPressed: onPressed,
      style: context.text.button.copyWith(
        fontSize: 17,
        color: context.ff.inkMuted,
      ),
    );
  }
}

/// Delete confirmation (screen 28). [noun] is singular ("note"); pass
/// [pluralNoun] for irregular plurals. Barrier tap / back = cancel.
Future<DeleteChoice> confirmDelete(
  BuildContext context, {
  required int count,
  required String noun,
  String? pluralNoun,
  bool permanent = false,
  bool offerArchive = true,
  int retentionDays = 30,
}) async {
  final plural = pluralNoun ?? '${noun}s';
  final many = count != 1;
  final title = permanent
      ? 'Delete forever?'
      : many
      ? 'Delete $count $plural?'
      : 'Delete this $noun?';
  final choice = await showFFDialog<DeleteChoice>(
    context,
    builder: (ctx) {
      final ff = ctx.ff;
      final bold = TextStyle(fontWeight: FontWeight.w700, color: ff.ink);
      final message = permanent
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: many
                        ? '$count $plural will be removed from '
                        : 'This $noun will be removed from ',
                  ),
                  TextSpan(text: 'Recently Deleted', style: bold),
                  const TextSpan(text: ' permanently. This can’t be undone.'),
                ],
              ),
              textAlign: TextAlign.center,
            )
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: many ? 'They’ll move to ' : 'It’ll move to '),
                  TextSpan(text: 'Recently Deleted', style: bold),
                  TextSpan(
                    text:
                        ' and be removed permanently after '
                        '$retentionDays days.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            );
      return FFDialog(
        icon: FontAwesomeIcons.trashCan,
        iconColor: ff.dangerSolid,
        iconBackground: ff.dangerSoft,
        title: title,
        messageWidget: message,
        actions: [
          FFDangerButton(
            label: permanent ? 'Delete forever' : 'Delete',
            onPressed: () => Navigator.of(ctx).pop(DeleteChoice.delete),
          ),
          if (!permanent && offerArchive)
            FFSecondaryButton(
              label: 'Archive instead',
              onPressed: () => Navigator.of(ctx).pop(DeleteChoice.archive),
            ),
          _CancelAction(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(DeleteChoice.cancel),
          ),
        ],
      );
    },
  );
  return choice ?? DeleteChoice.cancel;
}

/// Generic two-choice confirmation. Returns true only on confirm.
Future<bool> showFFConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showFFDialog<bool>(
    context,
    builder: (ctx) {
      final ff = ctx.ff;
      return FFDialog(
        icon: icon,
        iconColor: destructive ? ff.dangerSolid : ff.primary,
        iconBackground: destructive ? ff.dangerSoft : ff.primarySoft,
        title: title,
        message: message,
        actions: [
          if (destructive)
            FFDangerButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(ctx).pop(true),
            )
          else
            FFPrimaryButton(
              label: confirmLabel,
              height: AppSizes.secondaryButton,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          _CancelAction(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Confirmation that requires typing [word] (e.g. "DELETE") to enable the
/// confirm button. Returns true only on confirm.
Future<bool> showFFTextConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String word = 'DELETE',
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
  IconData? icon = FontAwesomeIcons.triangleExclamation,
}) async {
  final result = await showFFDialog<bool>(
    context,
    builder: (ctx) => _TextConfirmDialog(
      title: title,
      message: message,
      word: word,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _TextConfirmDialog extends StatefulWidget {
  const _TextConfirmDialog({
    required this.title,
    required this.word,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.message,
    this.icon,
  });

  final String title;
  final String? message;
  final String word;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  @override
  State<_TextConfirmDialog> createState() => _TextConfirmDialogState();
}

class _TextConfirmDialogState extends State<_TextConfirmDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    void confirm() => Navigator.of(context).pop(true);
    return FFDialog(
      icon: widget.icon,
      iconColor: widget.destructive ? ff.dangerSolid : ff.primary,
      iconBackground: widget.destructive ? ff.dangerSoft : ff.primarySoft,
      title: widget.title,
      message: widget.message,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Type ${widget.word} to confirm',
            textAlign: TextAlign.center,
            style: context.text.meta,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            style: context.text.button.copyWith(letterSpacing: 2),
            decoration: InputDecoration(
              hintText: widget.word,
              fillColor: ff.surfaceMuted,
            ),
            onChanged: (v) =>
                setState(() => _matches = v.trim() == widget.word),
            onSubmitted: (_) {
              if (_matches) confirm();
            },
          ),
        ],
      ),
      actions: [
        if (widget.destructive)
          FFDangerButton(
            label: widget.confirmLabel,
            onPressed: _matches ? confirm : null,
          )
        else
          FFPrimaryButton(
            label: widget.confirmLabel,
            height: AppSizes.secondaryButton,
            onPressed: _matches ? confirm : null,
          ),
        _CancelAction(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

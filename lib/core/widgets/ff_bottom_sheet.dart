/// ============================================================
/// FF BOTTOM SHEET — 34-radius sheet with handle, blur scrim, drag-dismiss
/// ============================================================
///
/// [showFFBottomSheet] pushes a [ModalBottomSheetRoute] whose barrier is
/// `ff.scrim` + a σ 3 backdrop blur, slides up with [AppMotion] timings
/// (instant under reduce motion) and supports drag-to-dismiss.
/// [FFBottomSheet] is the visual: `ff.sheet` background, 44×6 handle,
/// scrollable content, an optional sticky [FFBottomSheet.footer], and
/// keyboard + home-indicator safe padding.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_blur_barrier.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

/// Shows [builder]'s content in an [FFBottomSheet]. If the builder already
/// returns an [FFBottomSheet] (to set a footer/padding) it isn't wrapped;
/// pass [wrap] false when it returns a widget that builds its own sheet
/// (e.g. [FFActionSheet]).
Future<T?> showFFBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool wrap = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = true,
  bool vault = false,
  RouteSettings? settings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localizations = MaterialLocalizations.of(context);
  final reduce = context.reduceMotion;
  return navigator.push<T>(
    _FFSheetRoute<T>(
      builder: (sheetContext) {
        final content = builder(sheetContext);
        return !wrap || content is FFBottomSheet
            ? content
            : FFBottomSheet(vault: vault, child: content);
      },
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: true,
      useSafeArea: true,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      modalBarrierColor: context.ff.scrim,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      settings: settings,
      sheetAnimationStyle: reduce
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: AppMotion.slow,
              reverseDuration: AppMotion.normal,
            ),
    ),
  );
}

class _FFSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _FFSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    super.settings,
    super.useSafeArea,
    super.sheetAnimationStyle,
  });

  @override
  Widget buildModalBarrier() =>
      ffBlurBarrier(super.buildModalBarrier(), animation);
}

class FFBottomSheet extends StatelessWidget {
  const FFBottomSheet({
    required this.child,
    this.footer,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.screen,
      AppSpacing.xl,
      AppSpacing.screen,
      AppSpacing.lg,
    ),
    this.showHandle = true,
    this.scrollable = true,
    this.vault = false,
    this.maxHeightFactor = 0.94,
    super.key,
  });

  final Widget child;

  /// Sticky area under the scrolling content (action buttons).
  final Widget? footer;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  /// Wrap [child] in a scroll view (turn off when the child scrolls itself
  /// — then give it bounded height, e.g. via `Flexible` inside a Column).
  final bool scrollable;

  /// Always-dark vault sheet.
  final bool vault;

  /// Max height as a fraction of the screen.
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final media = MediaQuery.of(context);
    final bottomSafe = media.viewPadding.bottom > 0
        ? media.viewPadding.bottom
        : AppSpacing.sm;
    final body = scrollable
        ? SingleChildScrollView(padding: padding, child: child)
        : Padding(padding: padding, child: child);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * maxHeightFactor,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: vault ? ff.vaultCanvas : ff.sheet,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet),
            ),
            border: ff.isDark || vault
                ? Border(top: BorderSide(color: ff.surfaceBorder))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: AppSpacing.md),
                    width: AppSizes.sheetHandleWidth,
                    height: AppSizes.sheetHandleHeight,
                    decoration: BoxDecoration(
                      color: vault ? ff.vaultBorder : ff.sheetHandle,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
              Flexible(child: body),
              if (footer != null)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    media.viewInsets.bottom > 0 ? AppSpacing.md : bottomSafe,
                  ),
                  child: footer,
                )
              else
                SizedBox(height: media.viewInsets.bottom > 0 ? 0 : bottomSafe),
            ],
          ),
        ),
      ),
    );
  }
}

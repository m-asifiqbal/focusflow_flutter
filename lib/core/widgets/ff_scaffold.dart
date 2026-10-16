/// ============================================================
/// FF SCAFFOLD — canvas background + safe area + optional bottom bar
/// ============================================================
///
/// * Paints `ff.canvas` (or `ff.vaultCanvas` when [vault]) and sets the
///   status-bar icon brightness to match.
/// * With a [bottomBar] the body extends behind it (`extendBody`) so lists
///   scroll under the translucent tab bar and the raised FAB; give scrolling
///   content `AppSpacing.bottomBarClearance` bottom padding.
/// * [floating] is stacked over the body, bottom-centred above the bar
///   (multi-select action bars, "Save" buttons).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class FFScaffold extends StatelessWidget {
  const FFScaffold({
    required this.body,
    this.bottomBar,
    this.floating,
    this.floatingActionButton,
    this.vault = false,
    this.backgroundColor,
    this.safeTop = true,
    this.safeBottom,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget body;

  /// Usually [FFBottomNav]; the body extends behind it.
  final Widget? bottomBar;

  /// Overlay pinned to the bottom of the body (above [bottomBar]).
  final Widget? floating;
  final Widget? floatingActionButton;

  /// Use the always-dark vault canvas.
  final bool vault;
  final Color? backgroundColor;
  final bool safeTop;

  /// Defaults to true without a [bottomBar], false with one (content
  /// scrolls behind the bar).
  final bool? safeBottom;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final bg = backgroundColor ?? (vault ? ff.vaultCanvas : ff.canvas);
    final lightIcons = vault || ff.isDark;
    Widget content = SafeArea(
      top: safeTop,
      bottom: safeBottom ?? bottomBar == null,
      child: body,
    );
    if (floating != null) {
      content = Stack(
        children: [
          Positioned.fill(child: content),
          Builder(
            builder: (context) => Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.md,
                ),
                // The bottom inset is applied here; remove it so a floating
                // child with its own SafeArea doesn't add it twice.
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: floating!,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightIcons
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        extendBody: bottomBar != null,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        bottomNavigationBar: bottomBar,
        floatingActionButton: floatingActionButton,
        body: content,
      ),
    );
  }
}

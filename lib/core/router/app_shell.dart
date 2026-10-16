/// ============================================================
/// APP SHELL — the 4 tabs + centre FAB around StatefulShellRoute
/// ============================================================
///
/// Home · Library · Insights · Settings and the "+" button. The FAB always
/// opens the Quick Add sheet (screen 04) over whatever tab is showing.
/// Re-tapping the active tab pops that tab back to its root (iOS convention).
///
/// Android's back button / gesture: pages and sheets close first (they sit
/// above the shell); at a tab's root, back goes to **Home** when another tab
/// is showing, and from Home asks "Exit?" before leaving the app. iOS has no
/// back button, so nothing is intercepted there.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_bottom_nav.dart';
import 'package:focusflow/core/widgets/ff_dialog.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// The Home tab (first branch).
  static const int homeIndex = 0;

  /// Android is the only platform with a back button to handle here.
  static bool get _handlesBack =>
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> _onBack(BuildContext context) async {
    if (shell.currentIndex != homeIndex) {
      shell.goBranch(homeIndex);
      return;
    }
    final exit = await showFFConfirm(
      context,
      title: 'Exit ${AppInfo.name}?',
      message: 'Do you want to close the app?',
      confirmLabel: 'Exit',
      cancelLabel: 'Stay',
      icon: FontAwesomeIcons.rightFromBracket,
    );
    if (exit) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_handlesBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack(context));
      },
      child: Scaffold(
        backgroundColor: context.ff.canvas,
        extendBody: true,
        body: shell,
        bottomNavigationBar: FFBottomNav(
          currentIndex: shell.currentIndex,
          onTap: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          onFab: () => showQuickAdd(context),
        ),
      ),
    );
  }
}

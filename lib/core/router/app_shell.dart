/// ============================================================
/// APP SHELL — the 4 tabs + centre FAB around StatefulShellRoute
/// ============================================================
///
/// Home · Library · [+] · Insights · Settings. The FAB always opens the
/// Quick Add sheet (screen 04) over whatever tab is showing. Re-tapping the
/// active tab pops that tab back to its root (iOS convention).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_bottom_nav.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}

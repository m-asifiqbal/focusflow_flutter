/// ============================================================
/// APP SHELL — the tabs + the "+" button around StatefulShellRoute
/// ============================================================
///
/// Home · Library · (Prayer, when its tab is on) · Insights · Settings and
/// the "+" button. The FAB always opens the Quick Add sheet (screen 04)
/// over whatever tab is showing.
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_bottom_nav.dart';
import 'package:focusflow/core/widgets/ff_dialog.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// The Home tab (first branch).
  static const int homeIndex = 0;

  /// Branch indices (app_router.dart): the Prayer branch is registered last
  /// so the classic four keep theirs.
  static const int libraryIndex = 1;
  static const int insightsIndex = 2;
  static const int settingsIndex = 3;
  static const int prayerIndex = 4;

  /// The branches the bar shows, in bar order: Prayer sits after Library
  /// when its tab is on.
  static List<int> visibleBranches({required bool prayerTab}) => [
    homeIndex,
    libraryIndex,
    if (prayerTab) prayerIndex,
    insightsIndex,
    settingsIndex,
  ];

  static List<FFNavItem> _items(List<int> branches) => [
    for (final b in branches)
      switch (b) {
        homeIndex => FFNavItem(icon: FontAwesomeIcons.house, label: tr('Home')),
        libraryIndex => FFNavItem(
          icon: FontAwesomeIcons.layerGroup,
          label: tr('Library'),
        ),
        prayerIndex => FFNavItem(
          icon: FontAwesomeIcons.handsPraying,
          label: tr('Prayer'),
        ),
        insightsIndex => FFNavItem(
          icon: FontAwesomeIcons.chartPie,
          label: tr('Insights'),
        ),
        _ => FFNavItem(icon: FontAwesomeIcons.gear, label: tr('Settings')),
      },
  ];

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
      title: tr('Exit {name}?', {'name': AppInfo.name}),
      message: tr('Do you want to close the app?'),
      confirmLabel: tr('Exit'),
      cancelLabel: tr('Stay'),
      icon: FontAwesomeIcons.rightFromBracket,
    );
    if (exit) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerTab = ref.watch(
      settingsProvider.select((s) => s.prayer.showTab),
    );
    final branches = visibleBranches(prayerTab: prayerTab);
    final shown = branches.indexOf(shell.currentIndex);
    if (shown < 0) {
      // The Prayer tab was switched off while showing: back to Home.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => shell.goBranch(homeIndex),
      );
    }
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
          currentIndex: shown < 0 ? 0 : shown,
          items: _items(branches),
          onTap: (index) {
            final branch = branches[index];
            shell.goBranch(
              branch,
              initialLocation: branch == shell.currentIndex,
            );
          },
          onFab: () => showQuickAdd(context),
        ),
      ),
    );
  }
}

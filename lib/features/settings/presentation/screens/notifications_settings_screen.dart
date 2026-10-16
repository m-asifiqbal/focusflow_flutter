/// ============================================================
/// NOTIFICATIONS SETTINGS SCREEN — Settings › Notifications (screen 31)
/// ============================================================
///
/// What: "‹ Settings | Notifications" nav bar over a scrolling column:
/// Allow-notifications hero (+ denied banner) · DAILY DIGEST · BY MODULE ·
/// BEHAVIOUR (+ offline footnote). Every value reads `settingsProvider`
/// live; writes go through [NotificationSettingsController].
/// Why: the OS permission can change while the app is in the background
/// (the user flips it in system settings), so the screen re-reads it every
/// time the app resumes.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_behaviour_section.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_digest_section.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_module_section.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_permission_card.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_controller.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(notificationSettingsControllerProvider).refreshPermission(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A full-screen drill-in above the tab bar (root navigator): the
    // scaffold keeps the list above the home indicator.
    return FFScaffold(
      body: Column(
        children: [
          const FFNavHeader(
            leading: FFBackButton(label: 'Settings'),
            title: 'Notifications',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.grouped,
                AppSpacing.xs,
                AppSpacing.grouped,
                AppSpacing.xxl,
              ),
              children: const [
                NotificationPermissionCard(),
                SizedBox(height: AppSpacing.section),
                NotificationDigestSection(),
                SizedBox(height: AppSpacing.section),
                NotificationModuleSection(),
                SizedBox(height: AppSpacing.section),
                NotificationBehaviourSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

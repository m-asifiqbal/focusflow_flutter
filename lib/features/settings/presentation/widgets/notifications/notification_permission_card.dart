/// ============================================================
/// NOTIFICATION PERMISSION CARD — "Allow notifications" hero (screen 31)
/// ============================================================
///
/// What: the gradient card at the top of Settings › Notifications with the
/// master switch and the live OS permission status, plus the rose
/// "permission denied" banner under it when the OS blocks notifications.
/// Why: the master switch is only truly on when both the app setting and
/// the OS allow notifications, so the switch shows that combination and
/// turning it on runs the permission flow (prompt, or the system settings
/// after an earlier refusal).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_controller.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_style.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class NotificationPermissionCard extends ConsumerWidget {
  const NotificationPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsProvider.select((s) => s.notificationsEnabled),
    );
    final permission = ref.watch(notificationPermissionProvider);
    final controller = ref.read(notificationSettingsControllerProvider);
    final granted = permission.valueOrNull == NotificationPermission.granted;
    final on = permission.isLoading && !permission.hasValue
        ? enabled
        : enabled && granted;
    final denied =
        enabled && permission.valueOrNull == NotificationPermission.denied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeroCard(
          on: on,
          status: _status(enabled, permission),
          onChanged: (v) => controller.setEnabled(v),
        ),
        if (denied) ...[
          const SizedBox(height: AppSpacing.md),
          FFInfoBanner.danger(
            icon: FontAwesomeIcons.bellSlash,
            text:
                'Notifications are blocked in system settings, so reminders '
                "can't alert you.",
            actionLabel: 'Open settings',
            onAction: controller.requestPermission,
          ),
        ],
      ],
    );
  }

  static String _status(
    bool enabled,
    AsyncValue<NotificationPermission> permission,
  ) {
    if (!enabled) return 'All notifications are paused';
    return switch (permission.valueOrNull) {
      null => 'Checking system permission…',
      NotificationPermission.granted => 'System permission granted',
      NotificationPermission.denied => 'Blocked in system settings',
      NotificationPermission.notDetermined => 'Tap to allow notifications',
    };
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.on,
    required this.status,
    required this.onChanged,
  });

  final bool on;
  final String status;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const onGradient = NotificationTints.onGradient;
    final radius = BorderRadius.circular(AppRadii.card);
    return Semantics(
      toggled: on,
      label: 'Allow notifications',
      value: status,
      onTap: () => onChanged(!on),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ff.primaryGradient,
          borderRadius: radius,
          boxShadow: ff.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () => onChanged(!on),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.roundButton,
                    height: AppSizes.roundButton,
                    decoration: BoxDecoration(
                      color: onGradient.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadii.tileLg),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      FontAwesomeIcons.solidBell,
                      size: AppSizes.heroGlyph,
                      color: onGradient,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.rowLeadingGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Allow notifications',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.cardTitle.copyWith(
                            color: onGradient,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.meta.copyWith(
                            color: onGradient.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FFSwitch(
                    value: on,
                    onChanged: onChanged,
                    activeColor: onGradient.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

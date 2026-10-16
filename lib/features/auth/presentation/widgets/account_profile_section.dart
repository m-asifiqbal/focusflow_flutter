/// ============================================================
/// ACCOUNT PROFILE + LINKED DEVICES sections (screen 36)
/// ============================================================
///
/// * [AccountProfileSection] — Display name · Daily focus goal · Time
///   zone, each opening its editor sheet and saving through
///   [accountActionsProvider] (settings are live, so Home updates too).
/// * [AccountDevicesSection] — this device (ACTIVE) and the other devices
///   from the Drive manifest with Remove; offline/expired Drive shows a
///   footnote + Retry instead of failing the screen.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/notifiers/account_actions_controller.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/auth/presentation/widgets/account_editors.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Sky tile of the Time zone row (no module owns sky blue).
const ModuleColors _skyTile = ModuleColors(
  solid: AppPalette.sky500,
  soft: AppPalette.blue100,
  ink: AppPalette.blue700,
);

class AccountProfileSection extends ConsumerWidget {
  const AccountProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final deviceZone = ref.watch(deviceTimeZoneProvider).valueOrNull ?? '';
    final actions = ref.read(accountActionsProvider.notifier);
    final goal = settings.dailyFocusGoal;
    final zone = settings.timeZone ?? deviceZone;

    Widget tile(IconData icon, ModuleColors colors) => FFIconTile(
      icon: icon,
      colors: colors,
      size: AppSizes.iconTileSm,
      iconSize: 15,
    );

    return FFGroupedList(
      label: 'Profile',
      dividerIndent:
          AppSpacing.lg + AppSizes.iconTileSm + AppSpacing.rowLeadingGap,
      children: [
        FFListRow(
          leading: tile(FontAwesomeIcons.solidUser, ModuleStyle.notes.colors),
          title: 'Display name',
          value: settings.displayName.isEmpty ? 'Add' : settings.displayName,
          onTap: () async {
            final name = await showDisplayNameSheet(
              context,
              settings.displayName,
            );
            if (name != null) await actions.setDisplayName(name);
          },
        ),
        FFListRow(
          leading: tile(FontAwesomeIcons.bullseye, ModuleStyle.vault.colors),
          title: 'Daily focus goal',
          value: goal == 1 ? '1 task' : '$goal tasks',
          onTap: () async {
            final v = await showFocusGoalSheet(context, goal);
            if (v != null) await actions.setDailyFocusGoal(v);
          },
        ),
        FFListRow(
          leading: tile(FontAwesomeIcons.earthAsia, _skyTile),
          title: 'Time zone',
          value: zone.isEmpty ? 'Device' : zone,
          onTap: () async {
            final pick = await showTimeZoneSheet(
              context,
              current: settings.timeZone,
              deviceZone: deviceZone,
              zones: ref.read(timeZoneNamesProvider),
            );
            if (pick != null) await actions.setTimeZone(pick.zone);
          },
        ),
      ],
    );
  }
}

class AccountDevicesSection extends ConsumerWidget {
  const AccountDevicesSection({super.key});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    DeviceEntry device,
  ) async {
    final choice = await showRemoveDeviceDialog(context, device.name);
    if (choice == null || !context.mounted) return;
    try {
      await ref
          .read(accountActionsProvider.notifier)
          .removeDevice(
            device.deviceId,
            deleteBackups: choice == RemoveDeviceChoice.alsoDeleteBackups,
          );
    } on Object {
      if (context.mounted) {
        showUndoSnackbar(
          context,
          message: "Couldn't remove the device. Try again when online.",
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(linkedDevicesProvider);
    final now = ref.watch(clockProvider).now();
    final data = devices.valueOrNull;
    final error = data?.cloudError;
    return FFGroupedList(
      label: 'Linked devices',
      labelAction: error == null
          ? null
          : FFTextButton(
              label: 'Retry',
              onPressed: () => ref.invalidate(linkedDevicesProvider),
            ),
      footer: error,
      dividerIndent: 0,
      // One child: the mockup has no separators between devices.
      children: [
        if (data == null)
          const _DeviceSkeleton()
        else
          Column(
            children: [
              for (final d in data.devices)
                _DeviceRow(
                  device: d,
                  now: now,
                  onRemove: () => _remove(context, ref, d),
                ),
            ],
          ),
      ],
    );
  }
}

/// What "Remove device" should do.
enum RemoveDeviceChoice { keepBackups, alsoDeleteBackups }

/// "Remove [name]?" — Remove (its backups stay in Drive, still
/// restorable) or Also delete its backups. Null = cancelled.
Future<RemoveDeviceChoice?> showRemoveDeviceDialog(
  BuildContext context,
  String name,
) => showFFDialog<RemoveDeviceChoice>(
  context,
  builder: (ctx) => FFDialog(
    icon: FontAwesomeIcons.mobileScreenButton,
    iconColor: ctx.ff.dangerSolid,
    iconBackground: ctx.ff.dangerSoft,
    title: 'Remove $name?',
    message:
        'It stops appearing here and is linked again if it syncs. Its '
        'backups stay in Google Drive, so you can still restore them.',
    actions: [
      FFDangerButton(
        label: 'Remove',
        onPressed: () => Navigator.of(ctx).pop(RemoveDeviceChoice.keepBackups),
      ),
      FFSoftDangerButton(
        label: 'Also delete its backups',
        onPressed: () =>
            Navigator.of(ctx).pop(RemoveDeviceChoice.alsoDeleteBackups),
      ),
      FFTextButton(label: 'Cancel', onPressed: () => Navigator.of(ctx).pop()),
    ],
  ),
);

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.now,
    required this.onRemove,
  });

  final DeviceEntry device;
  final DateTime now;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final when = device.isThisDevice
        ? 'This device'
        : device.lastSyncAt == null
        ? 'Never synced'
        : 'Last synced ${DateUtilsX.ago(device.lastSyncAt!, now)}';
    final subtitle = device.platform.isEmpty
        ? when
        : '$when · ${device.platform}';
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
      child: FFListRow(
        leading: FFIconTile.soft(
          icon: device.isIos
              ? FontAwesomeIcons.mobileScreen
              : FontAwesomeIcons.mobileScreenButton,
          colors: ModuleStyle.notes.colors,
          size: AppSizes.iconTile,
          iconSize: 16,
        ),
        title: device.name,
        subtitle: subtitle,
        chevron: false,
        trailing: device.isThisDevice
            ? FFTag('Active', colors: ModuleStyle.notes.colors)
            : FFTextButton(
                label: 'Remove',
                color: ff.dangerStrong,
                style: context.text.bodySmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                semanticLabel: 'Remove ${device.name}',
                onPressed: onRemove,
              ),
      ),
    );
  }
}

class _DeviceSkeleton extends StatelessWidget {
  const _DeviceSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.all(AppSpacing.lg),
    child: Row(
      children: [
        FFSkeleton(width: AppSizes.iconTile, height: AppSizes.iconTile),
        SizedBox(width: AppSpacing.rowLeadingGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FFSkeleton(widthFactor: 0.5, height: 14),
              SizedBox(height: AppSpacing.sm),
              FFSkeleton(widthFactor: 0.7, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}

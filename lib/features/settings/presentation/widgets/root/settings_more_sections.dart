/// ============================================================
/// SETTINGS SECTIONS (2/2) — SECURITY & PRIVACY · DATA & SYNC · SUPPORT
/// ============================================================
///
/// Live values: vault unlock method (local_auth), app lock on/off,
/// clipboard timeout (edited on Vault security, behind re-auth), backup target (Drive when signed in with Google),
/// on-device storage, archive / trash counts and the app version.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsSecuritySection extends ConsumerWidget {
  const SettingsSecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final unlock = ref.watch(vaultUnlockLabelProvider).valueOrNull;
    return FFGroupedList(
      label: 'Security & privacy',
      children: [
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.shieldHalved,
            SettingsTints.emeraldDeep,
          ),
          title: 'Vault security',
          value: unlock,
          onTap: () => context.push(AppRoutes.settingsVaultSecurity),
        ),
        FFListRow(
          leading: settingsTile(FontAwesomeIcons.lock, SettingsTints.slateDeep),
          title: 'App lock',
          value: s.appLockEnabled ? 'On' : 'Off',
          onTap: () => context.push(AppRoutes.settingsAppLock),
        ),
        FFListRow.toggle(
          leading: settingsTile(
            FontAwesomeIcons.solidEyeSlash,
            SettingsTints.violetDeep,
          ),
          title: 'Hide content in app switcher',
          value: s.hideInAppSwitcher,
          onChanged: (_) =>
              runRootAction(context, ref, SettingsRootAction.hideInSwitcher),
        ),
        FFListRow(
          leading: settingsTile(FontAwesomeIcons.solidPaste, SettingsTints.sky),
          title: 'Clear clipboard after',
          value: SettingsLabels.clipboard(s.clipboardClearSeconds),
          // Vault security setting: changed there, behind the vault's
          // re-auth (the PIN / biometrics), never directly from the root.
          onTap: () => context.push(AppRoutes.settingsVaultSecurity),
        ),
      ],
    );
  }
}

class SettingsDataSection extends ConsumerWidget {
  const SettingsDataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final account = ref.watch(cloudAccountProvider);
    final local = ref.watch(
      settingsProvider.select((s) => s.localBackupFrequency),
    );
    final counts = ref.watch(libraryCountsProvider).valueOrNull;
    final storage = ref.watch(storageUsageProvider).valueOrNull;
    final drive = account?.hasDrive ?? false;
    final backupValue = drive
        ? 'Google Drive'
        : local == LocalBackupFrequency.off
        ? 'Off'
        : 'This device';
    return FFGroupedList(
      label: 'Data & sync',
      children: [
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.googleDrive,
            SettingsTints.blueDeep,
          ),
          title: 'Backup & Sync',
          value: backupValue,
          valueColor: drive ? ff.primary : null,
          onTap: () => context.push(AppRoutes.settingsBackup),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.fileExport,
            SettingsTints.amber,
          ),
          title: 'Import & Export',
          onTap: () => context.push(AppRoutes.settingsImportExport),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.database,
            SettingsTints.violet,
          ),
          title: 'Storage',
          value: storage == null ? null : formatBytes(storage.totalBytes),
          onTap: () => context.push(AppRoutes.settingsStorage),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.boxArchive,
            SettingsTints.slate,
          ),
          title: 'Archive',
          value: counts?.archived.toString(),
          onTap: () => context.push(AppRoutes.archive),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.solidTrashCan,
            SettingsTints.rose,
          ),
          title: 'Recently deleted',
          value: counts?.trash.toString(),
          onTap: () => context.push(AppRoutes.trash),
        ),
      ],
    );
  }
}

class SettingsSupportSection extends ConsumerWidget {
  const SettingsSupportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull;
    void run(SettingsRootAction a) => runRootAction(context, ref, a);
    return FFGroupedList(
      label: 'Support',
      children: [
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.solidCircleQuestion,
            SettingsTints.emerald,
          ),
          title: 'Help & Support',
          onTap: () => run(SettingsRootAction.help),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.solidCommentDots,
            SettingsTints.blue,
          ),
          title: 'Send feedback',
          onTap: () => run(SettingsRootAction.feedback),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.solidStar,
            SettingsTints.amber,
          ),
          title: 'Rate ${AppInfo.name}',
          onTap: () => run(SettingsRootAction.rate),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.circleInfo,
            SettingsTints.slate,
          ),
          title: 'About',
          value: version,
          onTap: () => context.push(AppRoutes.settingsAbout),
        ),
      ],
    );
  }
}

/// ============================================================
/// ABOUT — Settings › About (`/settings/about`)
/// ============================================================
///
/// What: app icon, name, version and tagline; FOCUSFLOW (privacy policy,
/// terms, feedback, rate) and ACKNOWLEDGEMENTS (the bundled fonts / icons
/// with their licences + "Open-source licences", which lists every package
/// and the asset licences from assets/licenses/).
/// Why: the version the root row shows needs a home, and the bundled
/// assets' licences must be reachable from the app. Links open only when
/// the user taps them (the one network use allowed here).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/data/bundled_licenses.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSettingsScreen extends ConsumerWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull;
    void run(SettingsRootAction a) => runRootAction(context, ref, a);
    return SettingsPage(
      title: tr('About'),
      children: [
        _AboutHeader(version: version),
        FFGroupedList(
          label: AppInfo.name,
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.circleInfo,
                SettingsTints.slate,
              ),
              title: tr('Version'),
              value: version ?? '…',
              chevron: false,
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.shieldHalved,
                SettingsTints.emerald,
              ),
              title: tr('Privacy policy'),
              onTap: () => _open(context, AppInfo.privacyUrl),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.fileLines,
                SettingsTints.blue,
              ),
              title: tr('Terms of use'),
              onTap: () => _open(context, AppInfo.termsUrl),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidCommentDots,
                SettingsTints.blue,
              ),
              title: tr('Send feedback'),
              onTap: () => run(SettingsRootAction.feedback),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidStar,
                SettingsTints.amber,
              ),
              title: tr('Rate {name}', {'name': AppInfo.name}),
              onTap: () => run(SettingsRootAction.rate),
            ),
          ],
        ),
        FFGroupedList(
          label: tr('Acknowledgements'),
          children: [
            for (final l in bundledLicenses)
              FFListRow(
                leading: settingsTile(
                  l.icons ? FontAwesomeIcons.icons : FontAwesomeIcons.font,
                  SettingsTints.violet,
                ),
                title: l.name,
                subtitle: '${l.use} · ${l.license}',
                chevron: false,
              ),
            FFListRow(
              leading: settingsTile(FontAwesomeIcons.code, SettingsTints.teal),
              title: tr('Open-source licences'),
              onTap: () => _showLicences(context, version),
            ),
          ],
        ),
        SettingsFootnote(
          tr(
            '{name} works fully offline. No ads, no analytics — your data stays yours.',
            {'name': AppInfo.name},
          ),
        ),
      ],
    );
  }

  void _showLicences(BuildContext context, String? version) {
    registerBundledLicenses();
    showLicensePage(
      context: context,
      applicationName: AppInfo.name,
      applicationVersion: version,
      useRootNavigator: true,
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (!opened && context.mounted) {
      showFFToast(
        context,
        tr('Couldn’t open {url}', {'url': url}),
        icon: FontAwesomeIcons.link,
      );
    }
  }
}

/// App icon, name, version and tagline, centred.
class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.version});

  final String? version;

  static const double _icon = 76;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return MergeSemantics(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_icon * 0.24),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: _icon,
              height: _icon,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppInfo.name, style: context.text.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            version ?? '',
            style: context.text.meta.copyWith(color: ff.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppInfo.tagline,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(color: ff.inkMuted),
          ),
        ],
      ),
    );
  }
}

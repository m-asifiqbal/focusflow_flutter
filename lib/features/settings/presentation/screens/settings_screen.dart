/// ============================================================
/// SETTINGS SCREEN — the Settings tab root (screen 30)
/// ============================================================
///
/// What: large "Settings" header · "Search settings…" · account card ·
/// GENERAL · PREFERENCES · MODULES · SECURITY & PRIVACY · DATA & SYNC ·
/// SUPPORT · Sign out · footer. Typing in search swaps the sections for
/// matches from every sub-page ([SettingsIndex]), each deep-linking.
/// Why: every value is live (settings, Library counts, sync status), so a
/// change anywhere shows here at once; the list scrolls under the tab bar.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_account_card.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_more_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_search_results.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = ref.watch(
      settingsQueryProvider.select((q) => q.trim().isNotEmpty),
    );
    final signedIn = ref.watch(cloudAccountProvider.select((a) => a != null));
    const gap = SizedBox(height: AppSpacing.section);
    return FFScaffold(
      safeBottom: false,
      // Toolbar stays put; only the settings list scrolls beneath it.
      body: Column(
        children: [
          const FFLargeHeader(title: 'Settings', fitTitle: true),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsetsDirectional.only(
                  bottom: context.barClearance,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.screen,
                      AppSpacing.sm,
                      AppSpacing.screen,
                      AppSpacing.lg,
                    ),
                    child: FFSearchField(
                      controller: _search,
                      hint: 'Search settings…',
                      onChanged: ref.read(settingsQueryProvider.notifier).set,
                      onClear: () {
                        _search.clear();
                        ref.read(settingsQueryProvider.notifier).clear();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.grouped,
                    ),
                    child: searching
                        ? const SettingsSearchResults()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SettingsAccountCard(),
                              gap,
                              const SettingsGeneralSection(),
                              gap,
                              const SettingsPreferencesSection(),
                              gap,
                              const SettingsModulesSection(),
                              gap,
                              const SettingsSecuritySection(),
                              gap,
                              const SettingsDataSection(),
                              gap,
                              const SettingsSupportSection(),
                              if (signedIn) ...[
                                const SizedBox(height: AppSpacing.xxl),
                                _SignOutButton(
                                  onPressed: () => confirmSignOut(context, ref),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xxl),
                              Text(
                                'Made with care · Your data stays yours',
                                textAlign: TextAlign.center,
                                style: context.text.meta.copyWith(
                                  color: context.ff.inkFaint,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width surface card with a rose "Sign out" label (mockup 30).
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      radius: AppRadii.row,
      onTap: onPressed,
      semanticLabel: 'Sign out',
      child: Text(
        'Sign out',
        textAlign: TextAlign.center,
        style: context.text.button.copyWith(color: ff.danger),
      ),
    );
  }
}

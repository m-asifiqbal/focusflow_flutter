/// ============================================================
/// SETTINGS SEARCH RESULTS — rows matching "Search settings…"
/// ============================================================
///
/// Replaces the sections while a query is typed: one grouped card of
/// matches (title + the page it lives on), each deep-linking to its page
/// or running its in-place picker; an empty state when nothing matches.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';

class SettingsSearchResults extends ConsumerWidget {
  const SettingsSearchResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(settingsSearchResultsProvider);
    final query = ref.watch(settingsQueryProvider).trim();
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxl),
        child: FFEmptyState.compact(
          colors: SettingsTints.slate,
          icon: FontAwesomeIcons.magnifyingGlass,
          title: tr('No settings match "{query}"', {'query': query}),
          body: tr('Try another word, like "dark", "backup" or "PIN".'),
        ),
      );
    }
    return FFGroupedList(
      label: tr('{count, plural, one {# result} other {# results}}', {
        'count': results.length,
      }),
      dividerIndent: AppSpacing.lg,
      children: [
        for (final e in results)
          FFListRow(
            title: e.title,
            subtitle: e.page,
            onTap: () => runSettingsEntry(context, ref, e),
          ),
      ],
    );
  }
}

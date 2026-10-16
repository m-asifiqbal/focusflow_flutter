/// ============================================================
/// VAULT FILTER SHEET — sort (A–Z / most recent) + category for the vault
/// list (screen 18, opened from the search field's filter button)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_list_providers.dart';

/// Sort + category filter for the vault list (the search field's slider
/// button).
Future<void> showVaultFilterSheet(BuildContext context) =>
    showFFBottomSheet<void>(
      context,
      vault: true,
      builder: (_) => const _FilterSheet(),
    );

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(vaultQueryProvider);
    final filter = ref.read(vaultQueryProvider.notifier);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        AppSpacing.sm,
        0,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetLabel('Sort'),
          FFChipBar<VaultSort>(
            vault: true,
            selected: q.sort,
            items: const [
              FFChipItem(value: VaultSort.az, label: 'A – Z'),
              FFChipItem(value: VaultSort.recent, label: 'Most recent'),
            ],
            onSelected: filter.setSort,
          ),
          const _SheetLabel('Category'),
          FFChipBar<String>(
            vault: true,
            selected: q.type?.name ?? '#any',
            items: [
              const FFChipItem(value: '#any', label: 'All types'),
              for (final t in VaultItemType.values)
                FFChipItem(value: t.name, label: t.plural),
            ],
            onSelected: (v) {
              if (v == '#any') {
                if (q.type != null) filter.toggleType(q.type!);
              } else {
                final t = VaultItemType.values.firstWhere((t) => t.name == v);
                if (q.type != t) filter.toggleType(t);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.screen,
      AppSpacing.md,
      AppSpacing.screen,
      AppSpacing.sm,
    ),
    child: FFSectionLabel(text),
  );
}

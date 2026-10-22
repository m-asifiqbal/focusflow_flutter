/// ============================================================
/// LIBRARY MODULES SHEET — reorder / show / hide spaces on the Library hub
/// ============================================================
///
/// What: one row per module (Notes … Vault) with a show/hide switch and a
/// drag handle, written straight to `AppSettings.hiddenLibraryModules` and
/// `AppSettings.libraryModuleOrder` (prompt 05: "reorder/hide modules").
/// Vault has no handle: it is always the full-width card under the grid.
/// Why: hiding a card only declutters the hub; the module, its data and
/// its routes keep working. At least one space stays visible.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/widgets/library_sections.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Opens the sheet; changes apply immediately.
Future<void> showLibraryModulesSheet(BuildContext context) =>
    showFFBottomSheet<void>(
      context,
      builder: (_) => const LibraryModulesSheet(),
    );

class LibraryModulesSheet extends ConsumerWidget {
  const LibraryModulesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final hidden = ref.watch(
      settingsProvider.select((s) => s.hiddenLibraryModules),
    );
    final order = orderedLibraryModules(
      ref.watch(settingsProvider.select((s) => s.libraryModuleOrder)),
    );
    final visible = ItemType.values.length - hidden.length;
    final settings = ref.read(settingsProvider.notifier);
    // Vault is last and fixed; only the grid modules move.
    final movable = order.length - 1;

    // [to] is already adjusted for the removed item (onReorderItem).
    void reorder(int from, int to) {
      if (from >= movable) return;
      final next = [...order]..removeAt(from);
      final at = to.clamp(0, movable - 1);
      next.insert(at, order[from]);
      settings.update(
        (s) => s.copyWith(libraryModuleOrder: [for (final t in next) t.key]),
      );
    }

    Widget row(int i, ItemType t) => Column(
      key: ValueKey(t.key),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (i > 0) const FFDividerInset(),
        Row(
          children: [
            Expanded(
              child: FFListRow.toggle(
                leading: FFIconTile(
                  icon: t.style.icon,
                  colors: t.style.colors,
                  size: AppSizes.iconTileSm,
                ),
                title: t.plural,
                value: !hidden.contains(t.key),
                // Keep at least one space on the hub.
                enabled: hidden.contains(t.key) || visible > 1,
                onChanged: (show) => settings.update(
                  (s) => s.copyWith(
                    hiddenLibraryModules: show
                        ? ({...s.hiddenLibraryModules}..remove(t.key))
                        : {...s.hiddenLibraryModules, t.key},
                  ),
                ),
              ),
            ),
            if (i < movable)
              ReorderableDragStartListener(
                index: i,
                child: Semantics(
                  container: true,
                  label: tr('Reorder {plural}', {'plural': t.plural}),
                  hint: tr('Drag to move'),
                  child: SizedBox.square(
                    dimension: AppSizes.minTap,
                    child: Icon(
                      FontAwesomeIcons.gripVertical,
                      size: AppSizes.tileGlyph,
                      color: ff.inkFaint,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: AppSizes.minTap),
          ],
        ),
      ],
    );

    final radius = BorderRadius.circular(AppRadii.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(tr('Spaces on Library'), style: context.text.title),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr(
            'Drag to reorder. Hidden spaces keep their items; open them from search or Home.',
          ),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ff.surface,
            borderRadius: radius,
            border: Border.all(color: ff.surfaceBorder),
            boxShadow: ff.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Material(
              type: MaterialType.transparency,
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: reorder,
                children: [
                  for (var i = 0; i < order.length; i++) row(i, order[i]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

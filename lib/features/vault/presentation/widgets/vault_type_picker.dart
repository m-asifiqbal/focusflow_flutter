/// ============================================================
/// VAULT TYPE PICKER — "What do you want to save?" (the + button)
/// ============================================================
///
/// A sheet of every item type, grouped (Everyday · Finance · Identity &
/// health · Digital & developer · Lifestyle), three tiles per row. Picking
/// one opens the editor on that type; the editor's own type chips still let
/// the user switch afterwards. Dark vault sheet.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';
import 'package:focusflow/features/vault/presentation/vault_type_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';

/// Asks which kind of item to add; null when dismissed.
Future<VaultItemType?> showVaultTypePicker(
  BuildContext context, {
  VaultItemType? selected,
}) => showFFBottomSheet<VaultItemType>(
  context,
  vault: true,
  builder: (_) => _TypePicker(selected: selected),
);

/// The vault's "+": pick a type, then open the editor on it.
Future<void> addVaultItem(BuildContext context) async {
  final type = await showVaultTypePicker(context);
  if (type == null || !context.mounted) return;
  unawaited(context.push(AppRoutes.newVaultItem(type: type.name)));
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({this.selected});

  final VaultItemType? selected;

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('What do you want to save?'),
          style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
        ),
        LayoutBuilder(
          builder: (context, c) {
            const gap = AppSpacing.sm;
            final width = (c.maxWidth - gap * (_columns - 1)) / _columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in VaultTypeGroup.values) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.sm,
                    ),
                    child: Semantics(
                      header: true,
                      child: VaultFieldLabel(group.label),
                    ),
                  ),
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final t in VaultItemType.values)
                        if (t.group == group)
                          SizedBox(
                            width: width,
                            child: _TypeTile(
                              type: t,
                              selected: t == selected,
                              onTap: () => Navigator.of(context).pop(t),
                            ),
                          ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final VaultItemType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tone = ff.vaultCategory(type);
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: VaultSizes.typeTile),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? ff.vaultKey : ff.vaultSurface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: selected ? ff.vaultAccent : ff.vaultBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: VaultSizes.typeTileIcon,
                height: VaultSizes.typeTileIcon,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  vaultTypeIcon(type),
                  size: VaultSizes.iconMd,
                  color: tone,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                type.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.cardTitle.copyWith(
                  fontSize: VaultType.secondary,
                  height: 1.2,
                  color: ff.vaultInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

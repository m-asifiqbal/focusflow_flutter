/// ============================================================
/// VAULT EDITOR ORGANISE — folder, tags, favourite, expiry, notes and
/// custom fields (screen 20)
/// ============================================================
///
/// [VaultOrganiseCard]: Folder › · Tags (emerald "#design #tools") · Add to
/// favourites switch · Password expiry reminder ("90 days").
/// [VaultEditorNotes]: the NOTES card (the body of a secure note).
/// Custom fields live in vault_editor_custom_fields.dart.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_editor_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_list_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_editor_state.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Expiry reminder choices in days (null = off).
const List<int?> vaultExpiryOptions = [null, 30, 60, 90, 180, 365];

String vaultExpiryLabel(int? days) => days == null ? 'Off' : '$days days';

class VaultOrganiseCard extends ConsumerWidget {
  const VaultOrganiseCard({required this.args, required this.state, super.key});

  final VaultEditorArgs args;
  final VaultEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final c = ref.read(vaultEditorProvider(args).notifier);
    final folders = ref.watch(vaultFoldersProvider).valueOrNull ?? const [];
    final folder = folders.where((f) => f.id == state.folderId).firstOrNull;
    final tags = state.tags.map((t) => '#$t').join(' ');
    Future<void> pickFolder() async {
      final choice = await showVaultChoiceSheet<String?>(
        context,
        title: 'Folder',
        current: state.folderId,
        options: [
          (value: null, label: 'No folder'),
          for (final f in folders) (value: f.id, label: f.name),
        ],
      );
      if (choice != null) c.setFolder(choice.value);
    }

    Future<void> pickTags() async {
      final names = await showVaultTagsSheet(context, state.tags);
      if (names != null) c.setTags(names);
    }

    Future<void> pickExpiry() async {
      final choice = await showVaultChoiceSheet<int?>(
        context,
        title: 'Password expiry reminder',
        current: state.expiryDays,
        options: [
          for (final d in vaultExpiryOptions)
            (value: d, label: vaultExpiryLabel(d)),
        ],
      );
      if (choice != null) c.setExpiry(choice.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VaultSectionLabel('Organise'),
        VaultCard(
          children: [
            VaultValueRow(
              label: 'Folder',
              value: folder?.name ?? 'No folder',
              onTap: () => unawaited(pickFolder()),
            ),
            VaultValueRow(
              label: 'Tags',
              value: tags.isEmpty ? 'Add tags' : tags,
              accent: tags.isNotEmpty,
              chevron: false,
              onTap: () => unawaited(pickTags()),
            ),
            VaultInlineRow(
              title: 'Add to favourites',
              minHeight: AppSizes.rowMin,
              trailing: FFSwitch(
                value: state.isFavorite,
                vault: true,
                semanticLabel: 'Add to favourites',
                onChanged: c.setFavorite,
              ),
            ),
            if (state.hasPassword)
              VaultInlineRow(
                title: 'Password expiry reminder',
                semanticLabel:
                    'Password expiry reminder: '
                    '${vaultExpiryLabel(state.expiryDays)}',
                onTap: () => unawaited(pickExpiry()),
                trailing: Text(
                  vaultExpiryLabel(state.expiryDays),
                  style: context.vaultValueStyle.copyWith(
                    fontSize: VaultType.row,
                    color: ff.vaultFieldLabel,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class VaultEditorNotes extends StatelessWidget {
  const VaultEditorNotes({
    required this.type,
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final VaultItemType type;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final note = type == VaultItemType.secureNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VaultSectionLabel(note ? 'Note' : 'Notes'),
        VaultCard(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                vaultFieldInset + 2,
                AppSpacing.md + 2,
                vaultFieldInset,
                AppSpacing.sm + 2,
              ),
              child: Semantics(
                textField: true,
                label: note ? 'Note' : 'Notes',
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  minLines: note ? 6 : 3,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  // Notes may hold secrets: keep them out of the keyboard.
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  autocorrect: false,
                  cursorColor: ff.vaultAccent,
                  style: context.vaultValueStyle.copyWith(
                    fontSize: VaultType.field,
                    height: 1.45,
                    color: ff.vaultInkSoft,
                  ),
                  decoration: vaultBareDecoration(
                    hintText: note
                        ? 'Write anything you want to keep private'
                        : 'Add notes',
                    hintStyle: context.vaultValueStyle.copyWith(
                      fontSize: VaultType.field,
                      color: ff.vaultFieldLabel,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

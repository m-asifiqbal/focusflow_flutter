/// ============================================================
/// VAULT ITEM DETAIL — `/vault/item/:id` (screen 19)
/// ============================================================
///
/// One credential: header (back · favourite · Edit), brand hero, the
/// secrets card (copy with auto-clear, reveal, 2FA code with countdown,
/// website), Security health, notes + password history, Archive / Delete.
/// Always-dark secure mode with screenshot blocking; every touch counts as
/// vault activity. Locked → unlock prompt; the payload is decrypted on
/// demand and dropped when the vault locks or the screen closes.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_detail_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_footer.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_header.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_health_card.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_screen_guard.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:go_router/go_router.dart';

class VaultItemDetailScreen extends StatelessWidget {
  const VaultItemDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) => VaultTheme(
    child: VaultScreenGuard(child: _DetailShell(id: id)),
  );
}

class _DetailShell extends ConsumerWidget {
  const _DetailShell({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(
      vaultSessionProvider.select((s) => s.isUnlocked),
    );
    final record = ref.watch(vaultItemRecordProvider(id));
    final colors = ModuleStyle.vault.colors;
    final Widget body;
    if (!unlocked) {
      body = _Message(
        child: FFEmptyState.compact(
          colors: colors,
          icon: FontAwesomeIcons.lock,
          title: tr('Vault locked'),
          body: tr('Unlock the vault to see this item.'),
          ctaLabel: tr('Unlock'),
          ctaIcon: FontAwesomeIcons.unlockKeyhole,
          onCta: () => unawaited(ensureVaultUnlocked(context)),
        ),
      );
    } else {
      body = record.when(
        loading: () => const _Loading(),
        error: (_, _) => _Message(
          child: FFEmptyState.compact(
            colors: colors,
            icon: FontAwesomeIcons.circleExclamation,
            title: tr('Couldn\'t load this item'),
            body: tr('Something went wrong while reading the vault.'),
            ctaLabel: tr('Retry'),
            ctaIcon: FontAwesomeIcons.arrowRotateRight,
            onCta: () => ref.invalidate(vaultItemRecordProvider(id)),
          ),
        ),
        data: (r) => r == null
            ? _Message(
                child: FFEmptyState.compact(
                  colors: colors,
                  icon: FontAwesomeIcons.key,
                  title: tr('Item not found'),
                  body: tr('It may have been deleted on another device.'),
                ),
              )
            : _Loaded(record: r),
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(vaultSessionProvider.notifier).touch(),
      child: FFScaffold(vault: true, body: body),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.record});

  final VaultItemRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(vaultItemPayloadProvider(record.id));
    return payload.when(
      loading: () => const _Loading(),
      error: (_, _) => const _Undecryptable(),
      data: (p) => p == null
          ? const _Undecryptable()
          : _Content(record: record, payload: p),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.record, required this.payload});

  final VaultItemRecord record;
  final VaultPayload payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = record.id;
    final now = ref.watch(clockProvider).now();
    final health = ref.watch(vaultItemHealthProvider(id));
    final history = ref.watch(vaultHistoryProvider(id)).valueOrNull ?? const [];
    final notes = record.type == VaultItemType.secureNote ? '' : payload.notes;
    const gap = SizedBox(height: AppSpacing.lg);
    return ListView(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
      ),
      children: [
        VaultDetailTopBar(
          isFavorite: record.isFavorite,
          onFavorite: record.isActive
              ? () => unawaited(toggleVaultFavourite(ref, record))
              : null,
          onEdit: () =>
              unawaited(context.push(AppRoutes.vaultItemEdit(record.id))),
        ),
        VaultDetailHero(
          record: record,
          subtitle: vaultUpdatedSubtitle(record, now),
        ),
        const SizedBox(height: AppSpacing.section),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.grouped,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VaultDetailFields(record: record, payload: payload),
              if (health != null) ...[gap, VaultHealthCard(health: health)],
              if (notes.isNotEmpty || history.isNotEmpty) ...[
                gap,
                VaultNotesCard(
                  notes: notes,
                  historyCount: history.length,
                  onHistory: () =>
                      unawaited(showVaultPasswordHistory(context, history)),
                  onCopy: () => unawaited(
                    copyVaultValue(context, ref, notes, tr('Notes')),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg + 2),
              _LifecycleButtons(record: record),
            ],
          ),
        ),
      ],
    );
  }
}

/// Archive / Delete — or Unarchive / Restore for items outside the lists.
class _LifecycleButtons extends ConsumerWidget {
  const _LifecycleButtons({required this.record});

  final VaultItemRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refs = [record.ref];
    final title = record.title;
    if (record.isDeleted) {
      return VaultDetailActions(
        archiveLabel: tr('Restore'),
        archiveIcon: FontAwesomeIcons.arrowRotateLeft,
        deleteLabel: tr('Delete forever'),
        onArchive: () =>
            unawaited(restoreFromTrash(context, ref, refs, title: title)),
        onDelete: () => unawaited(_deleteForever(context, ref)),
      );
    }
    if (record.isArchived) {
      return VaultDetailActions(
        archiveLabel: tr('Unarchive'),
        archiveIcon: FontAwesomeIcons.boxOpen,
        onArchive: () =>
            unawaited(restoreFromArchive(context, ref, refs, title: title)),
        onDelete: () => unawaited(deleteVaultItem(context, ref, record)),
      );
    }
    return VaultDetailActions(
      onArchive: () => unawaited(archiveVaultItem(context, ref, record)),
      onDelete: () => unawaited(deleteVaultItem(context, ref, record)),
    );
  }

  Future<void> _deleteForever(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final done = await deleteItemsForever(context, ref, [
      record.ref,
    ], title: record.title);
    if (done && router.canPop()) router.pop();
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.fromSTEB(
      AppSpacing.grouped,
      AppSpacing.xxxl * 3,
      AppSpacing.grouped,
      0,
    ),
    child: FFSkeletonList(count: 3),
  );
}

class _Undecryptable extends StatelessWidget {
  const _Undecryptable();

  @override
  Widget build(BuildContext context) => _Message(
    child: FFEmptyState.compact(
      colors: ModuleStyle.vault.colors,
      icon: FontAwesomeIcons.triangleExclamation,
      title: tr('Couldn\'t decrypt this item'),
      body: tr('It was encrypted with a different vault key.'),
    ),
  );
}

/// Back link above a centred message.
class _Message extends StatelessWidget {
  const _Message({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg - 4,
          AppSpacing.xxs,
          AppSpacing.lg,
          0,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FFBackButton(label: tr('Vault')),
        ),
      ),
      SizedBox(
        height: context.isCompactHeight ? AppSpacing.xxl : AppSpacing.xxxl * 3,
      ),
      child,
    ],
  );
}

extension on BuildContext {
  bool get isCompactHeight => MediaQuery.sizeOf(this).height < 600;
}

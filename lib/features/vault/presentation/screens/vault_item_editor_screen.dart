/// ============================================================
/// VAULT ITEM EDITOR — `/vault/new?type=` · `/vault/item/:id/edit` (20)
/// ============================================================
///
/// Cancel · "Edit Item" / "New Item" · Save, type chips, the title card,
/// CREDENTIALS (per type), ORGANISE, NOTES and CUSTOM FIELDS. All edits
/// live in [vaultEditorProvider] (plaintext in memory only); Save seals
/// the payload, refreshes the strength / reuse caches and pushes the old
/// password into history. Unsaved changes ask before being discarded.
/// Always-dark secure mode with screenshot blocking; every touch counts as
/// vault activity, and locking drops the draft.
/// ============================================================
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_editor_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_editor_state.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_credentials.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_header.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_custom_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_organise.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_screen_guard.dart';
import 'package:go_router/go_router.dart';

class VaultItemEditorScreen extends StatelessWidget {
  const VaultItemEditorScreen({
    this.id,
    this.type = VaultItemType.login,
    super.key,
  });

  /// The item to edit (null = new item of [type]).
  final String? id;
  final VaultItemType type;

  /// `?type=card|wifi|secureNote|login` → the type (login by default).
  static VaultItemType typeFromQuery(String? q) => VaultItemType.values
      .firstWhere((t) => t.name == q, orElse: () => VaultItemType.login);

  @override
  Widget build(BuildContext context) => VaultTheme(
    child: VaultScreenGuard(child: _EditorShell(args: (id: id, type: type))),
  );
}

class _EditorShell extends ConsumerStatefulWidget {
  const _EditorShell({required this.args});

  final VaultEditorArgs args;

  @override
  ConsumerState<_EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends ConsumerState<_EditorShell> {
  VaultEditorTexts _texts = VaultEditorTexts();

  VaultEditorArgs get _args => widget.args;

  @override
  void dispose() {
    _texts.dispose();
    super.dispose();
  }

  /// A fresh load (or a lock) must not keep text typed into the old draft.
  void _resetTexts() {
    final old = _texts;
    _texts = VaultEditorTexts();
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _cancel() async {
    final dirty =
        ref.read(vaultEditorProvider(_args)).valueOrNull?.dirty ?? false;
    if (dirty) {
      final discard = await showFFConfirm(
        context,
        title: 'Discard changes?',
        message: 'Your edits to this item will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
        icon: FontAwesomeIcons.triangleExclamation,
      );
      if (!discard || !mounted) return;
    }
    _close();
  }

  void _close() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.vault);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final String? id;
    try {
      id = await ref.read(vaultEditorProvider(_args).notifier).save();
    } on VaultLockedException {
      if (mounted) showFFToast(context, 'The vault locked — unlock to save');
      return;
    } on Object {
      if (mounted) showFFToast(context, "Couldn't save this item");
      return;
    }
    if (id == null || !mounted) return;
    showFFToast(context, 'Saved', icon: FontAwesomeIcons.circleCheck);
    _close();
  }

  Future<void> _changeIcon(VaultEditorState s) async {
    final choice = await showVaultIconSheet(
      context,
      title: s.title,
      type: s.type,
      iconKey: s.iconKey,
      colorHex: s.colorHex,
    );
    if (choice == null) return;
    ref
        .read(vaultEditorProvider(_args).notifier)
        .setIcon(choice.iconKey, colorHex: choice.colorHex);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultEditorProvider(_args), (prev, next) {
      if (next is! AsyncData || prev is! AsyncData) _resetTexts();
    });
    final editor = ref.watch(vaultEditorProvider(_args));
    final s = editor.valueOrNull;
    final title = _args.id == null ? 'New Item' : 'Edit Item';
    final Widget body = switch (editor) {
      AsyncData(:final value) => _content(value),
      AsyncError(:final error) => _message(error),
      _ => const _Loading(),
    };
    return PopScope(
      canPop: !(s?.dirty ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(vaultSessionProvider.notifier).touch(),
        child: FFScaffold(
          vault: true,
          // The mockup's nav row sits 6 pt into the status-bar inset.
          safeTop: false,
          body: Column(
            children: [
              SizedBox(
                height: math.max(0, MediaQuery.paddingOf(context).top - 6),
              ),
              VaultEditorTopBar(
                title: title,
                saving: s?.saving ?? false,
                onCancel: () => unawaited(_cancel()),
                onSave: s == null ? null : () => unawaited(_save()),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(VaultEditorState s) {
    final c = ref.read(vaultEditorProvider(_args).notifier);
    final texts = _texts;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
      ),
      children: [
        VaultTypeChips(selected: s.type, onSelected: c.setType),
        const SizedBox(height: AppSpacing.lg + 1),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.grouped,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VaultTitleCard(
                state: s,
                controller: texts.of('title', s.title),
                onTitle: c.setTitle,
                onChangeIcon: () => unawaited(_changeIcon(s)),
              ),
              VaultCredentialsCard(args: _args, state: s, texts: texts),
              VaultOrganiseCard(args: _args, state: s),
              VaultEditorNotes(
                type: s.type,
                controller: texts.of('notes', s.payload.notes),
                onChanged: c.setNotes,
              ),
              VaultCustomFieldsSection(
                args: _args,
                fields: s.payload.customFields,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _message(Object error) {
    final colors = ModuleStyle.vault.colors;
    final child = switch (error) {
      VaultLockedException() => FFEmptyState.compact(
        colors: colors,
        icon: FontAwesomeIcons.lock,
        title: 'Vault locked',
        body: 'Unlock the vault to edit this item.',
        ctaLabel: 'Unlock',
        ctaIcon: FontAwesomeIcons.unlockKeyhole,
        onCta: () => unawaited(ensureVaultUnlocked(context)),
      ),
      VaultItemNotFound() => FFEmptyState.compact(
        colors: colors,
        icon: FontAwesomeIcons.key,
        title: 'Item not found',
        body: 'It may have been deleted on another device.',
      ),
      VaultItemUndecryptable() => FFEmptyState.compact(
        colors: colors,
        icon: FontAwesomeIcons.triangleExclamation,
        title: "Couldn't decrypt this item",
        body: 'It was encrypted with a different vault key.',
      ),
      _ => FFEmptyState.compact(
        colors: colors,
        icon: FontAwesomeIcons.circleExclamation,
        title: "Couldn't load this item",
        body: 'Something went wrong while reading the vault.',
        ctaLabel: 'Retry',
        ctaIcon: FontAwesomeIcons.arrowRotateRight,
        onCta: () => ref.invalidate(vaultEditorProvider(_args)),
      ),
    };
    return ListView(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxxl * 2),
      children: [child],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.fromSTEB(
      AppSpacing.grouped,
      AppSpacing.xxl,
      AppSpacing.grouped,
      0,
    ),
    child: FFSkeletonList(count: 4),
  );
}

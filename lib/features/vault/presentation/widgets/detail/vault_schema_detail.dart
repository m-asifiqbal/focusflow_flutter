/// ============================================================
/// VAULT SCHEMA DETAIL — the cards of a schema-driven item (19)
/// ============================================================
///
/// Bank account, passport, server, licence key … : one titled card per
/// schema section, only the rows that have a value. Masked fields (account
/// and document numbers, PINs, keys) use the standard secret row — eye with
/// re-authentication, auto-hide after 4 s, large type on long-press, copy
/// with auto-clear; dates flagged as expiry dates carry an "Expires in 12
/// days" / "Expired" note in the badge tone; links open in the browser.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';
import 'package:focusflow/features/vault/presentation/vault_expiry.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_rows.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class VaultSchemaDetail extends ConsumerWidget {
  const VaultSchemaDetail({
    required this.record,
    required this.payload,
    required this.rows,
    super.key,
  });

  final VaultItemRecord record;
  final VaultPayload payload;
  final VaultDetailRows rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider).now();
    final blocks = <Widget>[];
    void add(String title, List<Widget> children) {
      if (children.isEmpty) return;
      blocks
        ..add(_Heading(title, first: blocks.isEmpty))
        ..add(VaultCard(children: children));
    }

    for (final section in record.type.sections) {
      add(section.title, [
        for (final f in section.fields) ?_row(context, f, now),
      ]);
    }
    add(tr('Custom fields'), [
      for (final (i, f) in payload.customFields.indexed)
        if (f.hidden)
          rows.secret(f.label.isEmpty ? tr('Field') : f.label, 'cf$i', f.value)
        else
          rows.plain(f.label.isEmpty ? tr('Field') : f.label, f.value),
    ]);
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }

  /// The row of [f], or null when it has no value.
  Widget? _row(BuildContext context, VaultFieldSpec f, DateTime now) {
    switch (f.kind) {
      case VaultFieldKind.password:
        return payload.password.isEmpty
            ? null
            : rows.secret(f.label, 'password', payload.password, colour: true);
      case VaultFieldKind.totp:
        return record.hasTotp ? rows.totp() : null;
      default:
    }
    final v = payload.field(f.key);
    if (v.isEmpty) return null;
    switch (f.kind) {
      case VaultFieldKind.url:
        return rows.link(f.label, v);
      case VaultFieldKind.date:
        return rows.plain(
          f.label,
          vaultDateLabel(v),
          note: f.expiry ? vaultExpiryNote(v, now) : null,
          noteTone: f.expiry ? vaultExpiryTone(context.ff, v, now) : null,
        );
      case VaultFieldKind.choice:
        return rows.plain(f.label, f.display(v));
      case VaultFieldKind.multiline:
        return f.masked
            ? rows.secret(f.label, 'f:${f.key}', v)
            : rows.plain(f.label, v, height: 1.5);
      default:
        return f.masked
            ? rows.secret(
                f.label,
                'f:${f.key}',
                v,
                format: f.format == VaultFieldFormat.iban
                    ? VaultIban.format
                    : null,
              )
            : rows.plain(f.label, v, mono: f.mono);
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {required this.first});

  final String title;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xs,
      first ? 0 : AppSpacing.xl,
      AppSpacing.xs,
      AppSpacing.md,
    ),
    child: Semantics(
      header: true,
      child: Text(title.toUpperCase(), style: context.vaultLabelStyle),
    ),
  );
}

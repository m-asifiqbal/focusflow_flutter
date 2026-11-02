/// ============================================================
/// VAULT SCHEMA SECTIONS — the editor cards of the schema-driven types
/// ============================================================
///
/// Bank account, passport, server, licence key … : one titled card per
/// [VaultSection], one row per [VaultFieldSpec], built from the type's
/// schema (vault_type_schemas.dart). Text rows write to
/// `VaultPayload.fields`; the password and 2FA rows are the standard ones
/// (strength meter, Generate, QR scan); dates open the calendar sheet;
/// choices open the choice sheet; secret / PIN rows are obscured with an
/// eye. Format checks (IBAN, BIC) are advisory captions, never blockers.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';
import 'package:focusflow/features/vault/presentation/state/vault_editor_state.dart';
import 'package:focusflow/features/vault/presentation/vault_expiry.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_date_sheet.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_secret_controls.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class VaultSchemaSections extends ConsumerStatefulWidget {
  const VaultSchemaSections({
    required this.args,
    required this.state,
    required this.texts,
    super.key,
  });

  final VaultEditorArgs args;
  final VaultEditorState state;
  final VaultEditorTexts texts;

  @override
  ConsumerState<VaultSchemaSections> createState() =>
      _VaultSchemaSectionsState();
}

class _VaultSchemaSectionsState extends ConsumerState<VaultSchemaSections>
    with VaultSecretControls<VaultSchemaSections> {
  @override
  VaultEditorArgs get editorArgs => widget.args;

  @override
  VaultEditorTexts get editorTexts => widget.texts;

  /// Stored-field controllers are namespaced so they never collide with the
  /// title / notes / password controllers of the same editor.
  static String _ctl(String key) => 'f:$key';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in s.type.sections) ...[
          VaultSectionLabel(section.title),
          VaultCard(children: [for (final f in section.fields) _row(s, f)]),
        ],
      ],
    );
  }

  Widget _row(VaultEditorState s, VaultFieldSpec f) => switch (f.kind) {
    VaultFieldKind.password => passwordRow(s, label: f.label),
    VaultFieldKind.totp => totpRow(s, label: f.label),
    VaultFieldKind.date => _dateRow(s.payload, f),
    VaultFieldKind.choice => _choiceRow(s.payload, f),
    _ => _textRow(s.payload, f),
  };

  Widget _textRow(VaultPayload p, VaultFieldSpec f) {
    final hidden =
        f.kind == VaultFieldKind.secret || f.kind == VaultFieldKind.pin;
    final multiline = f.kind == VaultFieldKind.multiline;
    final field = _ctl(f.key);
    final value = p.field(f.key);
    return VaultTextRow(
      label: f.label,
      hint: f.hint,
      controller: textOf(field, value),
      onChanged: (v) => editor.setField(f.key, v),
      mono: f.mono || hidden,
      obscure: hidden && !shownSecrets.contains(field),
      keyboardType: _keyboard(f.kind),
      inputFormatters: _formatters(f),
      textCapitalization: switch (f.caps) {
        VaultCaps.none => TextCapitalization.none,
        VaultCaps.words => TextCapitalization.words,
        VaultCaps.sentences => TextCapitalization.sentences,
        VaultCaps.characters => TextCapitalization.characters,
      },
      maxLines: multiline ? null : 1,
      minLines: multiline ? 3 : null,
      trailing: hidden
          ? [eye(field, f.label.toLowerCase())]
          : const [],
      errorText: _check(f, value),
    );
  }

  Widget _dateRow(VaultPayload p, VaultFieldSpec f) {
    final stored = p.field(f.key);
    final now = ref.read(clockProvider).now();
    final note = f.expiry && stored.isNotEmpty
        ? vaultExpiryNote(stored, now)
        : null;
    final text = stored.isEmpty
        ? tr('Not set')
        : note == null
        ? vaultDateLabel(stored)
        : '${vaultDateLabel(stored)} · $note';
    return VaultValueRow(
      label: f.label,
      value: text,
      onTap: () => unawaited(_pickDate(f, stored)),
    );
  }

  Future<void> _pickDate(VaultFieldSpec f, String stored) async {
    final now = ref.read(clockProvider).now();
    final choice = await showVaultDateSheet(
      context,
      title: f.label,
      now: now,
      initial: VaultDates.tryParse(stored),
    );
    if (choice == null) return;
    editor.setField(f.key, choice.value ?? '');
  }

  Widget _choiceRow(VaultPayload p, VaultFieldSpec f) {
    final stored = p.field(f.key);
    return VaultValueRow(
      label: f.label,
      value: stored.isEmpty ? tr('Not set') : f.display(stored),
      onTap: () => unawaited(_pickChoice(f, stored)),
    );
  }

  Future<void> _pickChoice(VaultFieldSpec f, String stored) async {
    final choice = await showVaultChoiceSheet<String>(
      context,
      title: f.label,
      current: stored,
      options: [
        (value: '', label: tr('Not set')),
        for (final o in f.options) (value: o.value, label: o.label),
      ],
    );
    if (choice != null) editor.setField(f.key, choice.value);
  }

  static TextInputType? _keyboard(VaultFieldKind k) => switch (k) {
    VaultFieldKind.number || VaultFieldKind.pin => TextInputType.number,
    VaultFieldKind.email => TextInputType.emailAddress,
    VaultFieldKind.phone => TextInputType.phone,
    VaultFieldKind.url => TextInputType.url,
    VaultFieldKind.multiline => TextInputType.multiline,
    _ => null,
  };

  /// Digits-only kinds and the length caps that keep a pasted blob from
  /// outgrowing what a payload may hold ([VaultPayload.maxFieldValue]).
  static List<TextInputFormatter> _formatters(VaultFieldSpec f) => [
    if (f.kind == VaultFieldKind.number || f.kind == VaultFieldKind.pin)
      FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(switch (f.kind) {
      VaultFieldKind.pin => 12,
      VaultFieldKind.number => 10,
      VaultFieldKind.multiline ||
      VaultFieldKind.secret => VaultPayload.maxFieldValue,
      _ => 512,
    }),
  ];

  /// An advisory caption under a field whose format looks off.
  static String? _check(VaultFieldSpec f, String value) {
    switch (f.format) {
      case VaultFieldFormat.iban:
        return VaultIban.normalise(value).length >= 15 &&
                !VaultIban.isValid(value)
            ? tr("This IBAN doesn't look valid")
            : null;
      case VaultFieldFormat.bic:
        return value.replaceAll(' ', '').length >= 8 && !VaultBic.isValid(value)
            ? tr("This SWIFT / BIC code doesn't look valid")
            : null;
      case VaultFieldFormat.none:
        return null;
    }
  }
}

/// ============================================================
/// VAULT EDITOR CUSTOM FIELDS — extra named fields (screen 20)
/// ============================================================
///
/// [VaultCustomFieldsSection]: saved custom fields + the dashed
/// "+ Add field (PIN, security question…)" card; each opens
/// [_CustomFieldSheet] (edit / remove). Split from
/// vault_editor_organise.dart to keep files small.
/// ============================================================
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_editor_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_editor_state.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_generate_sheet.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_primary_button.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultCustomFieldsSection extends ConsumerWidget {
  const VaultCustomFieldsSection({
    required this.args,
    required this.fields,
    super.key,
  });

  final VaultEditorArgs args;
  final List<VaultCustomField> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final c = ref.read(vaultEditorProvider(args).notifier);
    Future<void> edit(int? index) async {
      final result = await showFFBottomSheet<_FieldResult>(
        context,
        vault: true,
        builder: (_) =>
            _CustomFieldSheet(initial: index == null ? null : fields[index]),
      );
      if (result == null) return;
      final f = result.field;
      if (index == null) {
        if (f != null) c.addCustomField(f);
      } else if (f == null) {
        c.removeCustomField(index);
      } else {
        c.updateCustomField(index, f);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VaultSectionLabel(tr('Custom fields')),
        if (fields.isNotEmpty) ...[
          VaultCard(
            children: [
              for (var i = 0; i < fields.length; i++)
                VaultValueRow(
                  label: fields[i].label.isEmpty
                      ? tr('Field')
                      : fields[i].label,
                  value: fields[i].hidden
                      ? '•' * fields[i].value.length.clamp(4, 12)
                      : fields[i].value,
                  onTap: () => unawaited(edit(i)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Semantics(
          button: true,
          label: tr('Add custom field'),
          excludeSemantics: true,
          child: FFPressable(
            onTap: () => unawaited(edit(null)),
            child: VaultCard(
              dashed: true,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: VaultSizes.organiseRow,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.plus,
                          size: VaultSizes.iconRow,
                          color: ff.vaultAccent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            tr('Add field (PIN, security question…)'),
                            textAlign: TextAlign.center,
                            style: context.text.rowTitle.copyWith(
                              fontSize: VaultType.row,
                              fontWeight: FontWeight.w700,
                              color: ff.vaultAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sheet result: the edited field, or `field: null` = remove.
typedef _FieldResult = ({VaultCustomField? field});

class _CustomFieldSheet extends StatefulWidget {
  const _CustomFieldSheet({this.initial});

  final VaultCustomField? initial;

  @override
  State<_CustomFieldSheet> createState() => _CustomFieldSheetState();
}

class _CustomFieldSheetState extends State<_CustomFieldSheet> {
  late final _label = TextEditingController(text: widget.initial?.label);
  late final _value = TextEditingController(text: widget.initial?.value);
  late bool _hidden = widget.initial?.hidden ?? false;

  // A getter, not a const list: the labels follow the active language, and
  // "hidden" is data (never compared against the label text).
  List<({String label, bool hidden})> get _suggestions => [
    (label: tr('PIN'), hidden: true),
    (label: tr('Security question'), hidden: false),
    (label: tr('Recovery email'), hidden: false),
    (label: tr('Account number'), hidden: false),
  ];

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  void _save() {
    if (_label.text.trim().isEmpty && _value.text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop<_FieldResult>((
      field: VaultCustomField(
        label: _label.text.trim(),
        value: _value.text,
        hidden: _hidden,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.initial == null ? tr('Add field') : tr('Edit field'),
          style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s.label),
                labelStyle: context.text.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ff.vaultAccent,
                ),
                backgroundColor: ff.vaultAccentSoft,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                onPressed: () => setState(() {
                  _label.text = s.label;
                  if (s.hidden) _hidden = true;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        VaultCard(
          children: [
            VaultTextRow(
              label: tr('Label'),
              controller: _label,
              onChanged: (_) {},
              textCapitalization: TextCapitalization.sentences,
            ),
            VaultTextRow(
              label: tr('Value'),
              controller: _value,
              onChanged: (_) {},
              obscure: _hidden,
            ),
          ],
        ),
        VaultSwitchLine(
          label: tr('Hide value'),
          value: _hidden,
          onChanged: (v) => setState(() => _hidden = v),
        ),
        const SizedBox(height: AppSpacing.md),
        VaultPrimaryButton(label: tr('Save field'), onPressed: _save),
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop<_FieldResult>((field: null)),
            child: Text(
              tr('Remove field'),
              style: context.text.button.copyWith(color: ff.vaultDanger.fg),
            ),
          ),
      ],
    );
  }
}

/// ============================================================
/// VAULT EDITOR SHEETS — the editor's pickers (screen 20)
/// ============================================================
///
/// * (the icon picker lives in vault_icon_picker.dart)
/// * [showVaultChoiceSheet]     — single choice (expiry, Wi-Fi security).
/// * [showVaultTagsSheet]       — "#design #tools" free text.
/// All dark (vault) sheets; values return through `Navigator.pop`, never
/// through URLs.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_primary_button.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

Widget _title(BuildContext context, String text) => Padding(
  padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
  child: Text(
    text,
    style: context.text.sectionTitle.copyWith(color: context.ff.vaultInk),
  ),
);

// ------------------------------------------------------------------ choice

/// One option of [showVaultChoiceSheet].
typedef VaultChoice<T> = ({T value, String label});

/// Single choice; returns the picked option (null when dismissed).
Future<VaultChoice<T>?> showVaultChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<VaultChoice<T>> options,
  required T current,
}) => showFFBottomSheet<VaultChoice<T>>(
  context,
  vault: true,
  builder: (context) {
    final ff = context.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, title),
        VaultCard(
          children: [
            for (final o in options)
              Semantics(
                button: true,
                selected: o.value == current,
                label: o.label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(o),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: VaultSizes.sheetRow,
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: vaultFieldInset,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              o.label,
                              style: context.vaultValueStyle,
                            ),
                          ),
                          if (o.value == current)
                            Icon(
                              FontAwesomeIcons.check,
                              size: VaultSizes.iconRow,
                              color: ff.vaultAccent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  },
);

// -------------------------------------------------------------------- tags

/// Edits tag names as "#design #tools"; null when dismissed.
Future<List<String>?> showVaultTagsSheet(
  BuildContext context,
  List<String> current,
) => showFFBottomSheet<List<String>>(
  context,
  vault: true,
  builder: (_) => _TagsSheet(current: current),
);

class _TagsSheet extends StatefulWidget {
  const _TagsSheet({required this.current});

  final List<String> current;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  late final _c = TextEditingController(
    text: widget.current.map((t) => '#$t').join(' '),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop([
    for (final t in _c.text.split(RegExp(r'[\s,]+')))
      if (t.replaceAll('#', '').isNotEmpty) t.replaceAll('#', ''),
  ]);

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, tr('Tags')),
        Container(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: ff.vaultSurface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: ff.vaultBorder),
          ),
          child: TextField(
            controller: _c,
            autofocus: true,
            autocorrect: false,
            enableIMEPersonalizedLearning: false,
            style: context.vaultValueStyle.copyWith(color: ff.vaultAccent),
            cursorColor: ff.vaultAccent,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
            decoration: vaultBareDecoration(
              hintText: tr('#work #personal'),
              hintStyle: context.vaultValueStyle.copyWith(
                color: ff.vaultFieldLabel,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          tr('Separate tags with spaces.'),
          style: context.text.caption.copyWith(color: ff.vaultSubtitleMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        VaultPrimaryButton(label: tr('Done'), onPressed: _done),
      ],
    );
  }
}

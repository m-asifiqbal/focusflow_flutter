/// ============================================================
/// VAULT EDITOR SHEETS — the editor's pickers (screen 20)
/// ============================================================
///
/// * [showVaultIconSheet]       — brand glyph or letter avatar + colour.
/// * [showVaultChoiceSheet]     — single choice (expiry, Wi-Fi security).
/// * [showVaultTagsSheet]       — "#design #tools" free text.
/// All dark (vault) sheets; values return through `Navigator.pop`, never
/// through URLs.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/vault_brands.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_avatar.dart';
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

// -------------------------------------------------------------------- icon

/// The chosen avatar: brand [iconKey] (null = automatic / letter) and an
/// optional letter colour.
typedef VaultIconChoice = ({String? iconKey, String? colorHex});

/// Letter-avatar colours (stored as `RRGGBB` data).
final List<String> vaultLetterColours = [
  for (final c in [
    AppPalette.emerald700,
    AppPalette.teal700,
    AppPalette.blue600,
    AppPalette.indigo600,
    AppPalette.violet600,
    AppPalette.pink600,
    AppPalette.rose600,
    AppPalette.orange600,
    AppPalette.amber600,
    AppPalette.slate600,
  ])
    toHex(c),
];

Future<VaultIconChoice?> showVaultIconSheet(
  BuildContext context, {
  required String title,
  required VaultItemType type,
  String? iconKey,
  String? colorHex,
}) => showFFBottomSheet<VaultIconChoice>(
  context,
  vault: true,
  builder: (context) {
    final ff = context.ff;
    void pick(VaultIconChoice c) => Navigator.of(context).pop(c);
    Widget tile(
      String label,
      Widget child,
      bool selected,
      VoidCallback onTap,
    ) => Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.all(VaultSizes.swatchRing),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppRadii.tileLg + VaultSizes.swatchRing,
            ),
            border: Border.all(
              color: selected ? ff.vaultAccent : Colors.transparent,
              width: VaultSizes.ring,
            ),
          ),
          child: child,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'Change icon'),
        VaultFieldLabel('Letter'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final hex in vaultLetterColours)
              tile(
                'Letter avatar',
                VaultAvatar(title: title, type: type, colorHex: hex),
                iconKey == null && colorHex == hex,
                () => pick((iconKey: null, colorHex: hex)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        VaultFieldLabel('Brands'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final b in VaultBrands.all)
              tile(
                b.name,
                VaultAvatar(title: b.name, type: type, iconKey: b.key),
                iconKey == b.key,
                () => pick((iconKey: b.key, colorHex: null)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => pick((iconKey: null, colorHex: null)),
          child: Text(
            'Automatic',
            style: context.text.button.copyWith(color: ff.vaultAccent),
          ),
        ),
      ],
    );
  },
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
        _title(context, 'Tags'),
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
              hintText: '#work #personal',
              hintStyle: context.vaultValueStyle.copyWith(
                color: ff.vaultFieldLabel,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Separate tags with spaces.',
          style: context.text.caption.copyWith(color: ff.vaultSubtitleMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        VaultPrimaryButton(label: 'Done', onPressed: _done),
      ],
    );
  }
}

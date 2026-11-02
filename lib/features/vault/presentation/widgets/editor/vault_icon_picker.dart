/// ============================================================
/// VAULT ICON PICKER — "Change icon" sheet of the item editor (screen 20)
/// ============================================================
///
/// One sheet for every avatar an item can wear: a glyph from the icon
/// library (108 icons in 9 groups), a brand tile (≈110 brands, banks and
/// wallets included) or the letter avatar, on a colour of the user's choice.
/// A live preview, a search box (icons + brands together) and "Automatic"
/// (resolve from the title) sit on top; **Done** returns the choice.
/// Dark vault sheet; values return through `Navigator.pop`, never URLs.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/vault_brands.dart';
import 'package:focusflow/features/vault/presentation/vault_icons.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_avatar.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_primary_button.dart';

/// The chosen avatar: an icon key (`g:<glyph>`, a brand key or null =
/// automatic / letter) and an optional tile colour.
typedef VaultIconChoice = ({String? iconKey, String? colorHex});

/// Tile colours of glyph and letter avatars (stored as `RRGGBB` data).
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
    AppPalette.sky500,
    AppPalette.red700,
    AppPalette.lavender600,
    AppPalette.sage600,
    AppPalette.mocha600,
    AppPalette.amethyst600,
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
  builder: (_) => _IconPicker(
    title: title,
    type: type,
    iconKey: iconKey,
    colorHex: colorHex,
  ),
);

enum _Tab { icons, brands }

class _IconPicker extends StatefulWidget {
  const _IconPicker({
    required this.title,
    required this.type,
    required this.iconKey,
    required this.colorHex,
  });

  final String title;
  final VaultItemType type;
  final String? iconKey;
  final String? colorHex;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  late String? _iconKey = widget.iconKey;
  late String? _colorHex = widget.colorHex;
  _Tab _tab = _Tab.icons;
  String _query = '';

  bool get _searching => _query.trim().isNotEmpty;

  void _done() => Navigator.of(context).pop<VaultIconChoice>((
    iconKey: _iconKey,
    colorHex: _colorHex,
  ));

  Widget _tile({
    required String label,
    required String? iconKey,
    required String? colorHex,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ff = context.ff;
    return Semantics(
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
          child: VaultAvatar(
            title: title,
            type: widget.type,
            iconKey: iconKey,
            colorHex: colorHex,
          ),
        ),
      ),
    );
  }

  Widget _glyphTile(VaultGlyph g) => _tile(
    label: tr('Icon: {name}', {'name': g.key.replaceAll('-', ' ')}),
    iconKey: g.iconKey,
    colorHex: _colorHex,
    title: widget.title,
    selected: _iconKey == g.iconKey,
    onTap: () => setState(() => _iconKey = g.iconKey),
  );

  Widget _brandTile(VaultBrand b) => _tile(
    // Brand names are proper nouns; "Bank" is the one generic word.
    label: b.key == 'bank' ? tr('Bank') : b.name,
    iconKey: b.key,
    colorHex: null,
    title: b.name,
    selected: _iconKey == b.key,
    onTap: () => setState(() {
      _iconKey = b.key;
      _colorHex = null; // a brand keeps its own colour
    }),
  );

  Widget _wrap(List<Widget> tiles) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: tiles,
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsetsDirectional.only(
      top: AppSpacing.lg,
      bottom: AppSpacing.sm,
    ),
    child: VaultFieldLabel(text),
  );

  List<Widget> _content() {
    if (_searching) {
      final glyphs = VaultIcons.search(_query);
      final brands = VaultBrands.search(_query);
      if (glyphs.isEmpty && brands.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.xl,
            ),
            child: Text(
              tr('No icons match'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall.copyWith(
                color: context.ff.vaultInkMuted,
              ),
            ),
          ),
        ];
      }
      return [
        if (glyphs.isNotEmpty) ...[
          _label(tr('Icons')),
          _wrap([for (final g in glyphs) _glyphTile(g)]),
        ],
        if (brands.isNotEmpty) ...[
          _label(tr('Brands')),
          _wrap([for (final b in brands) _brandTile(b)]),
        ],
      ];
    }
    if (_tab == _Tab.brands) {
      return [
        const SizedBox(height: AppSpacing.sm),
        _wrap([for (final b in VaultBrands.all) _brandTile(b)]),
      ];
    }
    return [
      _label(tr('Letter')),
      _wrap([
        _tile(
          label: tr('Letter avatar'),
          iconKey: null,
          colorHex: _colorHex,
          title: widget.title,
          selected: _iconKey == null && _colorHex != null,
          onTap: () => setState(() {
            _iconKey = null;
            _colorHex ??= vaultLetterColours.first;
          }),
        ),
      ]),
      for (final group in VaultIcons.groups) ...[
        _label(group.title),
        _wrap([for (final g in group.glyphs) _glyphTile(g)]),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final showColours =
        _searching ||
        _tab == _Tab.icons ||
        (_iconKey != null && VaultIcons.isGlyphKey(_iconKey));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            VaultAvatar(
              title: widget.title,
              type: widget.type,
              iconKey: _iconKey,
              colorHex: _colorHex,
              size: VaultSizes.editorAvatar,
              radius: AppRadii.statTile,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                tr('Change icon'),
                style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _iconKey = null;
                _colorHex = null;
              }),
              child: Text(
                tr('Automatic'),
                style: context.text.button.copyWith(color: ff.vaultAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FFSearchField(
          vault: true,
          hint: tr('Search icons and brands'),
          onChanged: (v) => setState(() => _query = v),
          onClear: () => setState(() => _query = ''),
          textInputAction: TextInputAction.done,
        ),
        if (!_searching) ...[
          const SizedBox(height: AppSpacing.sm),
          FFChipBar<_Tab>(
            vault: true,
            padding: EdgeInsets.zero,
            selected: _tab,
            items: [
              FFChipItem(value: _Tab.icons, label: tr('Icons')),
              FFChipItem(value: _Tab.brands, label: tr('Brands')),
            ],
            onSelected: (t) => setState(() => _tab = t),
          ),
        ],
        if (showColours) ...[
          _label(tr('Colour')),
          _wrap([
            for (final hex in vaultLetterColours)
              Semantics(
                button: true,
                selected: _colorHex == hex,
                label: tr('Colour'),
                excludeSemantics: true,
                child: FFPressable(
                  onTap: () => setState(() => _colorHex = hex),
                  child: SizedBox.square(
                    dimension: AppSizes.minTap,
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: parseHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorHex == hex
                                ? ff.vaultAccent
                                : ff.vaultBorder,
                            width: _colorHex == hex ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ],
        ..._content(),
        const SizedBox(height: AppSpacing.lg),
        VaultPrimaryButton(label: tr('Done'), onPressed: _done),
      ],
    );
  }
}

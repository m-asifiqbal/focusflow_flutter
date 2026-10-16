/// ============================================================
/// VAULT EDITOR FIELDS — editable rows of the editor cards (screen 20)
/// ============================================================
///
/// * [VaultEditorTexts]   — the editor's text controllers, created once
///   from the loaded state (programmatic fills: Generate, QR scan).
/// * [VaultTextRow]       — tracked label over a borderless text field
///   (+ trailing widgets: eye, Generate, scan).
/// (Password controls: vault_password_widgets.dart; title card:
/// vault_editor_credentials.dart.)
/// * [VaultValueRow]      — label over a value, chevron (Folder / Tags).
/// * [VaultInlineRow]     — one-line row with a trailing switch / value.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Text controllers of one editor, keyed by field name.
class VaultEditorTexts {
  final Map<String, TextEditingController> _c = {};

  /// The controller of [field], created with [initial] the first time.
  TextEditingController of(String field, [String initial = '']) =>
      _c.putIfAbsent(field, () => TextEditingController(text: initial));

  /// Replaces [field]'s text (cursor at the end).
  void set(String field, String value) {
    of(field).value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _c.clear();
  }
}

/// Borderless, padding-free field decoration. The app theme's outlined
/// input borders would otherwise still apply (and inset the text 4 pt).
InputDecoration vaultBareDecoration({
  required String? hintText,
  TextStyle? hintStyle,
}) => InputDecoration.collapsed(hintText: hintText, hintStyle: hintStyle)
    .copyWith(
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );

/// Row padding shared by the editor rows.
const EdgeInsetsDirectional _rowPadding = EdgeInsetsDirectional.fromSTEB(
  vaultFieldInset + 2,
  AppSpacing.md + 2,
  vaultFieldInset,
  AppSpacing.md + 2,
);

class VaultTextRow extends StatelessWidget {
  const VaultTextRow({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.mono = false,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.maxLines = 1,
    this.minLines,
    this.trailing = const [],
    this.below,
    this.errorText,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool mono;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final int? maxLines;
  final int? minLines;
  final List<Widget> trailing;

  /// Under the field, full width (strength meter, error).
  final Widget? below;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = mono
        ? context.vaultMonoStyle
        : context.vaultValueStyle.copyWith(fontSize: VaultType.row);
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      obscureText: obscure,
      obscuringCharacter: '•',
      // Vault fields hold secrets: no keyboard suggestions, and the IME must
      // not learn (Android incognito keyboard flag / iOS equivalent).
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autocorrect: false,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      style: style,
      cursorColor: ff.vaultAccent,
      decoration: vaultBareDecoration(
        hintText: hint,
        hintStyle: context.vaultValueStyle.copyWith(
          fontSize: VaultType.row,
          color: ff.vaultFieldLabel,
        ),
      ).copyWith(semanticCounterText: label),
    );
    final labelled = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VaultFieldLabel(label),
        const SizedBox(height: AppSpacing.sm),
        Semantics(textField: true, label: label, child: field),
      ],
    );
    return Padding(
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trailing.isEmpty)
            labelled
          else
            // 44-pt trailing targets span the label + value; their glyphs
            // sit on the value line (see VaultIconButton).
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: labelled),
                for (final t in trailing) ...[
                  const SizedBox(width: AppSpacing.xs),
                  t,
                ],
              ],
            ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              errorText!,
              style: context.text.caption.copyWith(
                color: ff.vaultDanger.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          ?below,
        ],
      ),
    );
  }
}

/// A label over a value with a chevron (Folder, Tags).
class VaultValueRow extends StatelessWidget {
  const VaultValueRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.accent = false,
    this.chevron = true,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// Emerald value (tags).
  final bool accent;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: _rowPadding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VaultFieldLabel(label),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      value,
                      style: context.vaultValueStyle.copyWith(
                        fontSize: VaultType.row,
                        color: accent ? ff.vaultAccent : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (chevron)
                Icon(
                  FontAwesomeIcons.chevronRight,
                  size: VaultSizes.iconXs,
                  color: ff.vaultFieldLabel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-line row: title + trailing (switch / muted value).
class VaultInlineRow extends StatelessWidget {
  const VaultInlineRow({
    required this.title,
    required this.trailing,
    this.onTap,
    this.semanticLabel,
    this.minHeight = 52,
    super.key,
  });

  final String title;
  final Widget trailing;

  /// 52 for a value row, 60 with a switch (mockup).
  final double minHeight;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          vaultFieldInset + 2,
          AppSpacing.sm,
          vaultFieldInset,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: context.vaultValueStyle.copyWith(
                  fontSize: VaultType.row,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            trailing,
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

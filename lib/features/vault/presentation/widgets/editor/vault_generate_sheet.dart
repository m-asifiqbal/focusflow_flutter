/// ============================================================
/// VAULT GENERATE SHEET — quick password generator for the editor (20)
/// ============================================================
///
/// Length slider + character sets, regenerate, "Use password" (the value
/// returns through `Navigator.pop`, never a URL). The full generator with
/// passphrases and PINs is the vault's Generator tab (screen 21).
/// [VaultSwitchLine] is the label + vault switch row shared by the sheets.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
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

// ---------------------------------------------------------------- generate

/// A generated password, or null when dismissed.
Future<String?> showVaultGenerateSheet(BuildContext context) =>
    showFFBottomSheet<String>(
      context,
      vault: true,
      builder: (_) => const _GenerateSheet(),
    );

class _GenerateSheet extends ConsumerStatefulWidget {
  const _GenerateSheet();

  @override
  ConsumerState<_GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends ConsumerState<_GenerateSheet> {
  PasswordOptions _o = const PasswordOptions();
  late String _value = _make();

  String _make() => ref.read(passwordGeneratorProvider).password(_o).value;

  void _update(PasswordOptions o) {
    // At least one character set stays on.
    if (!o.upper && !o.lower && !o.digits && !o.symbols) return;
    setState(() {
      _o = o;
      _value = _make();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    Widget toggle(String label, bool value, PasswordOptions Function(bool) f) =>
        VaultSwitchLine(
          label: label,
          value: value,
          onChanged: (v) => _update(f(v)),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, tr('Generate password')),
        Container(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: ff.vaultSurface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: ff.vaultBorder),
          ),
          child: Row(
            children: [
              Expanded(
                // Not selectable: copying goes through the secure clipboard.
                child: Text(_value, style: context.vaultMonoStyle, maxLines: 3),
              ),
              VaultRoundButton(
                icon: FontAwesomeIcons.arrowsRotate,
                semanticLabel: tr('Regenerate'),
                onTap: () => setState(() => _value = _make()),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text(
              tr('Length'),
              style: context.vaultValueStyle.copyWith(
                fontSize: VaultType.field,
              ),
            ),
            Expanded(
              child: Slider(
                value: _o.length.toDouble(),
                min: PasswordOptions.minLength.toDouble(),
                max: PasswordOptions.maxLength.toDouble(),
                divisions:
                    PasswordOptions.maxLength - PasswordOptions.minLength,
                activeColor: ff.vaultAccent,
                inactiveColor: ff.vaultTrack,
                label: '${_o.length}',
                semanticFormatterCallback: (v) =>
                    tr('{n} characters', {'n': v.round()}),
                onChanged: (v) => _update(_o.copyWith(length: v.round())),
              ),
            ),
            SizedBox(
              width: VaultSizes.lengthLabel,
              child: Text(
                '${_o.length}',
                textAlign: TextAlign.end,
                style: context.vaultMonoStyle.copyWith(
                  fontSize: VaultType.field,
                ),
              ),
            ),
          ],
        ),
        toggle(tr('Uppercase (A–Z)'), _o.upper, (v) => _o.copyWith(upper: v)),
        toggle(tr('Lowercase (a–z)'), _o.lower, (v) => _o.copyWith(lower: v)),
        toggle(tr('Numbers (0–9)'), _o.digits, (v) => _o.copyWith(digits: v)),
        toggle(tr('Symbols (!@#)'), _o.symbols, (v) => _o.copyWith(symbols: v)),
        const SizedBox(height: AppSpacing.lg),
        VaultPrimaryButton(
          label: tr('Use password'),
          icon: FontAwesomeIcons.check,
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

/// Label + vault switch, 44 pt tall.
class VaultSwitchLine extends StatelessWidget {
  const VaultSwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AppSizes.minTap + 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.vaultValueStyle.copyWith(fontSize: VaultType.field),
          ),
        ),
        FFSwitch(
          value: value,
          vault: true,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

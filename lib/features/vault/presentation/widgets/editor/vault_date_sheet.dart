/// ============================================================
/// VAULT DATE SHEET — pick (or clear) a document date
/// ============================================================
///
/// Used by the schema editor's date fields (issue / expiry / renewal …).
/// An inline calendar plus Done and "Clear date"; returns the day as the
/// stored `yyyy-MM-dd` text, `value: null` for "clear", or null when
/// dismissed. Dark vault sheet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_primary_button.dart';

/// Result of [showVaultDateSheet]: the picked day, or `value: null` = clear.
typedef VaultDateChoice = ({String? value});

Future<VaultDateChoice?> showVaultDateSheet(
  BuildContext context, {
  required String title,
  required DateTime now,
  DateTime? initial,
}) => showFFBottomSheet<VaultDateChoice>(
  context,
  vault: true,
  builder: (_) => _DateSheet(title: title, now: now, initial: initial),
);

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.title, required this.now, this.initial});

  final String title;
  final DateTime now;
  final DateTime? initial;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _picked = DateUtilsX.dateOnly(widget.initial ?? widget.now);

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final today = DateUtilsX.dateOnly(widget.now);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Passports and licences are dated decades either side of today.
        CalendarDatePicker(
          initialDate: _picked,
          firstDate: DateTime(today.year - 100),
          lastDate: DateTime(today.year + 50, 12, 31),
          onDateChanged: (d) => _picked = d,
        ),
        const SizedBox(height: AppSpacing.sm),
        VaultPrimaryButton(
          label: tr('Done'),
          onPressed: () => Navigator.of(
            context,
          ).pop<VaultDateChoice>((value: VaultDates.key(_picked))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop<VaultDateChoice>((
            value: null,
          )),
          child: Text(
            tr('Clear date'),
            style: context.text.button.copyWith(color: ff.vaultDanger.fg),
          ),
        ),
      ],
    );
  }
}

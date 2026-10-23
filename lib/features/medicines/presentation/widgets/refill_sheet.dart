/// ============================================================
/// REFILL — the low-stock banner and the "How many did you add?" sheet
/// ============================================================
///
/// [MedicineRefillBanner]: amber card "Metformin is running low · 6
/// tablets left · about 3 days" with a REFILLED pill. [showRefillSheet]:
/// a stepper pre-filled with the last pack size (30 the first time), the
/// stock after the refill shown live; Add writes it through
/// [refillMedicine] (Undo restores the previous count).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/widgets/medicine_stepper.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card_parts.dart';

class MedicineRefillBanner extends ConsumerWidget {
  const MedicineRefillBanner({required this.medicine, super.key});

  final Medicine medicine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final m = medicine;
    final colors = MedicineStyle.stock;
    final ink = colors.inkFor(ff.brightness);
    final days = MedicineSchedule.daysLeft(m);
    final left = MedicineWords.left(m.stockLeft ?? 0, m.form);
    final meta = days == null
        ? left
        : '$left · ${tr('{count, plural, =0 {runs out today} one {about # day} other {about # days}}', {'count': days})}';
    return FFCard(
      color: colors.softFor(ff.brightness),
      shadow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          FFIconTile(icon: FontAwesomeIcons.boxOpen, colors: colors),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('{name} is running low', {'name': m.name.trim()}),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.rowTitle.copyWith(color: ink),
                  ),
                  Text(
                    meta,
                    maxLines: 2,
                    style: context.text.meta.copyWith(color: ink),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ReminderActionPill(
            label: tr('REFILLED'),
            colors: colors,
            onTap: () => showRefillSheet(context, ref, m),
          ),
        ],
      ),
    );
  }
}

/// Asks how many units were added, then refills [m].
Future<void> showRefillSheet(
  BuildContext context,
  WidgetRef ref,
  Medicine m,
) async {
  final amount = await showFFBottomSheet<double>(
    context,
    builder: (_) => _RefillSheet(medicine: m),
  );
  if (amount == null || !context.mounted) return;
  await refillMedicine(context, ref, m, amount);
}

class _RefillSheet extends StatefulWidget {
  const _RefillSheet({required this.medicine});

  final Medicine medicine;

  @override
  State<_RefillSheet> createState() => _RefillSheetState();
}

class _RefillSheetState extends State<_RefillSheet> {
  late double _amount = widget.medicine.packSize ?? 30;

  @override
  Widget build(BuildContext context) {
    final m = widget.medicine;
    final after = (m.stockLeft ?? 0) + _amount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Refill {name}', {'name': m.name.trim()}),
          style: context.text.title,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(tr('How many did you add?'), style: context.text.bodySmall),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: MedicineStepper(
            value: _amount,
            step: 1,
            min: 1,
            max: 999,
            label: (v) => MedicineWords.amount(v, m.form),
            onChanged: (v) => setState(() => _amount = v),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          tr('You\'ll have {left}', {
            'left': MedicineWords.amount(after, m.form),
          }),
          textAlign: TextAlign.center,
          style: context.text.meta,
        ),
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: tr('Add to stock'),
          icon: FontAwesomeIcons.plus,
          onPressed: () => Navigator.of(context).pop(_amount),
        ),
      ],
    );
  }
}

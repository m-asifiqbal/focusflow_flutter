/// ============================================================
/// MEDICINE EDITOR SHEETS — dose time wheel and option lists
/// ============================================================
///
/// [showDoseTimeSheet]: the Reminders time wheel in a floating sheet, with
/// Done; returns minutes after midnight. [showMedicineOptionSheet]: a list
/// of choices with a check on the current one (course length, follow-up,
/// snooze length).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_time_wheel.dart';

Future<int?> showDoseTimeSheet(
  BuildContext context, {
  required int minutes,
  bool use24h = false,
}) => showFFBottomSheet<int>(
  context,
  builder: (_) => _TimeSheet(minutes: minutes, use24h: use24h),
);

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.minutes, required this.use24h});

  final int minutes;
  final bool use24h;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _minutes = widget.minutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Dose time'), style: context.text.title),
        const SizedBox(height: AppSpacing.lg),
        FFCard(
          padding: EdgeInsetsDirectional.zero,
          child: ReminderTimeWheel(
            minutes: widget.minutes,
            use24h: widget.use24h,
            onChanged: (m) => _minutes = m,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: tr('Done'),
          onPressed: () => Navigator.of(context).pop(_minutes),
        ),
      ],
    );
  }
}

/// One choice of [showMedicineOptionSheet].
@immutable
class MedicineOption<T> {
  const MedicineOption(this.value, this.label);

  final T value;
  final String label;
}

Future<T?> showMedicineOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<MedicineOption<T>> options,
  required T selected,
}) => showFFBottomSheet<T>(
  context,
  builder: (sheet) {
    final ff = sheet.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: sheet.text.title),
        const SizedBox(height: AppSpacing.lg),
        FFGroupedList(
          dividerIndent: AppSpacing.lg,
          children: [
            for (final o in options)
              FFListRow(
                title: o.label,
                semanticLabel: o.value == selected
                    ? tr('{label}, selected', {'label': o.label})
                    : o.label,
                trailing: o.value == selected
                    ? Icon(
                        FontAwesomeIcons.check,
                        size: AppSpacing.lg,
                        color: ff.primary,
                      )
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheet).pop(o.value),
              ),
          ],
        ),
      ],
    );
  },
);

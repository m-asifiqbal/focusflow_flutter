/// ============================================================
/// PRAYER SCHOOL PICKER — "Which school do you follow?", skippable
/// ============================================================
///
/// What: the tradition's own question ("Which movement?", "Which stream of
/// Hinduism?" …) over a wrapping row of chips — its schools in the order
/// its followers expect, and "Not sure" (the default). Nothing is chosen
/// until the person taps; nothing is hidden by it.
/// Why: one faith is many practices; the answer only picks a better
/// starting set (Hanafi Asr, Orthodox prayer rule, Reform's lighter week,
/// a Zen sit, a Pure Land nembutsu). Shared by "Set up Prayer" and the "+"
/// sheet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';

class PrayerSchoolPicker extends StatelessWidget {
  const PrayerSchoolPicker({
    required this.tradition,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final PrayerTradition tradition;
  final PrayerSchool? selected;
  final ValueChanged<PrayerSchool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final schools = PrayerSchool.of(tradition);
    final question = tradition.schoolQuestion;
    if (schools.isEmpty || question == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(question),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr('This only picks a good starting set. You can change everything.'),
          style: context.text.meta.copyWith(
            color: context.ff.inkMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final s in schools)
              FFChip(
                label: s.label,
                selected: selected == s,
                onTap: () => onChanged(s),
              ),
            FFChip(
              label: tr('Not sure'),
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
          ],
        ),
      ],
    );
  }
}

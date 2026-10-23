/// ============================================================
/// MEDICINE HISTORY CARD — the latest doses, newest first
/// ============================================================
///
/// "Today, 8:00 AM · 1 tablet · Taken 8:04" rows (last 30 days, doses whose
/// time has come). "See all" expands the list in place; a tap opens the
/// dose sheet, so a dose logged by mistake (or forgotten) can be fixed.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/widgets/dose_sheet.dart';

class MedicineHistoryCard extends ConsumerStatefulWidget {
  const MedicineHistoryCard({
    required this.history,
    required this.now,
    this.use24h = false,
    super.key,
  });

  /// Newest first.
  final List<DoseSlot> history;
  final DateTime now;
  final bool use24h;

  static const int defaultLimit = 6;

  @override
  ConsumerState<MedicineHistoryCard> createState() =>
      _MedicineHistoryCardState();
}

class _MedicineHistoryCardState extends ConsumerState<MedicineHistoryCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final items = _all
        ? widget.history
        : widget.history.take(MedicineHistoryCard.defaultLimit).toList();
    final more = widget.history.length > MedicineHistoryCard.defaultLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('History'),
          actionLabel: more ? (_all ? tr('Show less') : tr('See all')) : null,
          onAction: more ? () => setState(() => _all = !_all) : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSize(
          duration: context.reduceMotion ? Duration.zero : AppMotion.normal,
          curve: AppMotion.curve,
          alignment: AlignmentDirectional.topCenter,
          child: widget.history.isEmpty
              ? FFCard(
                  child: Text(
                    tr('Doses you take will show up here.'),
                    style: context.text.bodySmall,
                  ),
                )
              : FFGroupedList(
                  dividerIndent: AppSpacing.xl,
                  children: [
                    for (final s in items)
                      FFListRow(
                        key: ValueKey(s.id),
                        title:
                            '${DateUtilsX.relativeDay(s.day, widget.now)}, '
                            '${DateUtilsX.time(s.at, use24h: widget.use24h)}',
                        subtitle: s.isAsNeeded
                            ? tr('As needed · {amount}', {
                                'amount': MedicineWords.amount(
                                  s.quantity,
                                  s.medicine.form,
                                ),
                              })
                            : MedicineWords.amount(s.quantity, s.medicine.form),
                        value: _status(s),
                        valueColor: switch (s.stateAt(widget.now)) {
                          DoseState.taken => ff.primary,
                          DoseState.missed => ff.danger,
                          _ => ff.inkMuted,
                        },
                        chevron: false,
                        onTap: () => showDoseSheet(
                          context,
                          ref,
                          s,
                          widget.now,
                          showOpen: false,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _status(DoseSlot s) {
    final taken = s.log?.takenAt;
    return switch (s.stateAt(widget.now)) {
      DoseState.taken =>
        taken == null
            ? tr('Taken')
            : tr('Taken {time}', {
                'time': DateUtilsX.time(taken, use24h: widget.use24h),
              }),
      DoseState.skipped => tr('Skipped'),
      DoseState.missed => tr('Missed'),
      DoseState.snoozed => tr('Snoozed'),
      DoseState.due => tr('Due'),
      DoseState.upcoming => tr('Upcoming'),
    };
  }
}

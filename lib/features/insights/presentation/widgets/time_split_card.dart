/// ============================================================
/// TIME SPLIT CARD — "Where your time went" callout donut (mockup 25)
/// ============================================================
///
/// What: the animated callout donut ([TimeSplitDonut]) of actions per
/// module (tasks completed, habit check-ins, notes created, reminders done)
/// with the total in the centre, plus a legend with whole-number
/// percentages that add up to 100. Touching a slice or a legend row
/// highlights both.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:focusflow/features/insights/presentation/widgets/time_split_donut.dart';

class TimeSplitCard extends StatefulWidget {
  const TimeSplitCard({required this.split, super.key});

  final TimeSplit split;

  @override
  State<TimeSplitCard> createState() => _TimeSplitCardState();
}

class _TimeSplitCardState extends State<TimeSplitCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final split = widget.split;
    final percents = split.percents;
    final entries = [
      ('Tasks', split.tasks, ModuleStyle.tasks.colors),
      ('Habits', split.habits, ModuleStyle.habits.colors),
      ('Notes', split.notes, ModuleStyle.notes.colors),
      ('Reminders', split.reminders, ModuleStyle.reminders.colors),
    ];
    return FFCard(
      padding: const EdgeInsetsDirectional.all(InsightsDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Where your time went',
              style: context.text.sectionTitle.copyWith(
                fontSize: InsightsDimens.cardTitle,
              ),
            ),
          ),
          const SizedBox(height: InsightsDimens.cardGap),
          if (split.total == 0)
            const InsightsNoData(
              icon: FontAwesomeIcons.chartPie,
              message: 'Nothing done in this range yet.',
            )
          else
            Semantics(
              label:
                  '${split.total} actions. '
                  '${[for (var i = 0; i < 4; i++) '${entries[i].$1} ${percents[i]}%'].join(', ')}',
              excludeSemantics: true,
              child: Column(
                children: [
                  TimeSplitDonut(
                    total: split.total,
                    entries: entries,
                    percents: percents,
                    touched: _touched,
                    onTouch: (i) => setState(() => _touched = i),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Legend(
                    entries: entries,
                    percents: percents,
                    touched: _touched,
                    onTouch: (i) => setState(() => _touched = i),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.entries,
    required this.percents,
    required this.touched,
    this.onTouch,
  });

  final List<DonutEntry> entries;
  final List<int> percents;
  final int? touched;
  final ValueChanged<int?>? onTouch;

  @override
  Widget build(BuildContext context) {
    final style = context.text.rowTitle.copyWith(
      fontSize: InsightsDimens.legendText,
      fontWeight: FontWeight.w400,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          FFPressable(
            onTap: onTouch == null
                ? null
                : () => onTouch!(touched == i ? null : i),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: InsightsDimens.legendRow,
              ),
              child: Row(
                children: [
                  Container(
                    width: InsightsDimens.legendDot,
                    height: InsightsDimens.legendDot,
                    decoration: BoxDecoration(
                      color: entries[i].$3.solid,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      entries[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: touched == i
                          ? style.copyWith(fontWeight: FontWeight.w700)
                          : style,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${percents[i]}%',
                    style: style.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ============================================================
/// TIME SPLIT CARD — "Where your time went" donut (mockup 25)
/// ============================================================
///
/// What: an fl_chart donut of actions per module (tasks completed, habit
/// check-ins, notes created, reminders done) in the module colours, the
/// total in the centre ("132 actions") and a legend with whole-number
/// percentages that add up to 100. Touching a slice highlights it.
/// Why: the donut sits beside the legend when there is room and above it
/// otherwise (360 pt / text scale 1.3), so nothing overflows.
/// ============================================================
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';

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
      ('Tasks', split.tasks, ModuleStyle.tasks.solid),
      ('Habits', split.habits, ModuleStyle.habits.solid),
      ('Notes', split.notes, ModuleStyle.notes.solid),
      ('Reminders', split.reminders, ModuleStyle.reminders.solid),
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
              child: LayoutBuilder(
                builder: (context, c) {
                  final legendMin = MediaQuery.textScalerOf(
                    context,
                  ).scale(InsightsDimens.legendText * 10);
                  final side =
                      InsightsDimens.donut +
                          InsightsDimens.donutGap +
                          legendMin <=
                      c.maxWidth;
                  final donut = _Donut(
                    total: split.total,
                    entries: entries,
                    touched: _touched,
                    onTouch: (i) => setState(() => _touched = i),
                  );
                  final legend = _Legend(
                    entries: entries,
                    percents: percents,
                    touched: _touched,
                  );
                  return side
                      ? Row(
                          children: [
                            donut,
                            const SizedBox(width: InsightsDimens.donutGap),
                            Expanded(child: legend),
                          ],
                        )
                      : Column(
                          children: [
                            donut,
                            const SizedBox(height: AppSpacing.lg),
                            legend,
                          ],
                        );
                },
              ),
            ),
        ],
      ),
    );
  }
}

typedef _Entry = (String label, int value, Color color);

class _Donut extends StatelessWidget {
  const _Donut({
    required this.total,
    required this.entries,
    required this.touched,
    required this.onTouch,
  });

  final int total;
  final List<_Entry> entries;
  final int? touched;
  final ValueChanged<int?> onTouch;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const size = InsightsDimens.donut;
    const stroke = InsightsDimens.donutStroke;
    // fl_chart drops zero sections; keep the index map for touches.
    final visible = [
      for (var i = 0; i < entries.length; i++)
        if (entries[i].$2 > 0) i,
    ];
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            duration: context.motion(AppMotion.slow),
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: size / 2 - stroke,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final i = response?.touchedSection?.touchedSectionIndex;
                  if (!event.isInterestedForInteractions ||
                      i == null ||
                      i < 0) {
                    onTouch(null);
                  } else {
                    onTouch(visible[i]);
                  }
                },
              ),
              sections: [
                for (final i in visible)
                  PieChartSectionData(
                    value: entries[i].$2.toDouble(),
                    color: entries[i].$3,
                    radius: touched == i ? stroke + 4 : stroke,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$total', style: context.text.stat),
              ),
              Text(
                total == 1 ? 'action' : 'actions',
                style: context.text.caption.copyWith(color: ff.inkMuted),
              ),
            ],
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
  });

  final List<_Entry> entries;
  final List<int> percents;
  final int? touched;

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
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: InsightsDimens.legendRow,
            ),
            child: Row(
              children: [
                Container(
                  width: InsightsDimens.legendDot,
                  height: InsightsDimens.legendDot,
                  decoration: BoxDecoration(
                    color: entries[i].$3,
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
      ],
    );
  }
}

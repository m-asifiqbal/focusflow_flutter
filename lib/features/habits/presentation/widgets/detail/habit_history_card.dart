/// ============================================================
/// HABIT HISTORY CARD — "History ……… See all" of the habit detail (16)
/// ============================================================
///
/// The latest three days with a log: soft icon tile, day ("Today",
/// "Sun, Jun 11"), what happened ("6 of 8 glasses", "Skipped · note: …")
/// and the result ("75%" habit colour, "100%" emerald, "Skip" muted).
/// Tapping a row opens the day editor; See all lists every day in a sheet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/services/habit_history.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class HabitHistoryCard extends StatelessWidget {
  const HabitHistoryCard({
    required this.habit,
    required this.entries,
    required this.today,
    required this.onDay,
    this.limit = defaultLimit,
    super.key,
  });

  final Habit habit;

  /// Newest first (all of them; the card shows [limit]).
  final List<HabitHistoryEntry> entries;
  final DateTime today;
  final ValueChanged<DateTime> onDay;
  final int limit;

  /// Rows shown before "See all".
  static const int defaultLimit = 3;

  /// Up to this many rows the sheet sizes to its content; longer
  /// histories (years of logs) get a fixed-height, lazily built list.
  static const int _shrinkWrapLimit = 20;

  /// Max height of the See all sheet (fraction of the screen).
  static const double _sheetHeightFactor = 0.75;

  void _seeAll(BuildContext context) => showFFBottomSheet<void>(
    context,
    builder: (sheet) => FFBottomSheet(
      scrollable: false,
      maxHeightFactor: _sheetHeightFactor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('History', style: sheet.text.title),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView.builder(
              shrinkWrap: entries.length <= _shrinkWrapLimit,
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              itemBuilder: (_, i) => HabitHistoryRow(
                habit: habit,
                entry: entries[i],
                today: today,
                onTap: () {
                  Navigator.of(sheet).pop();
                  onDay(entries[i].day);
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: 'History',
          actionLabel: entries.length > limit ? 'See all' : null,
          onAction: () => _seeAll(context),
        ),
        SizedBox(
          height:
              AppSpacing.md +
              AppSpacing.xxs -
              (entries.length > limit ? HabitDimens.actionHeaderInset : 0),
        ),
        FFCard(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg + AppSpacing.xxs,
            vertical: AppSpacing.sm,
          ),
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    // A quit habit's clean days need no log.
                    habit.isQuit ? 'No slips logged yet' : 'No check-ins yet',
                    textAlign: TextAlign.center,
                    style: context.text.meta,
                  ),
                )
              : Column(
                  children: [
                    for (final e in entries.take(limit))
                      HabitHistoryRow(
                        habit: habit,
                        entry: e,
                        today: today,
                        onTap: () => onDay(e.day),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class HabitHistoryRow extends ConsumerWidget {
  const HabitHistoryRow({
    required this.habit,
    required this.entry,
    required this.today,
    required this.onTap,
    super.key,
  });

  final Habit habit;
  final HabitHistoryEntry entry;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final colors = habit.colors;
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final title = HabitFormat.historyTitle(entry.day, today);
    final subtitle = HabitFormat.historySubtitle(habit, entry, use24h: use24h);
    final value = HabitFormat.historyValue(habit, entry);
    final valueColor = switch (entry.kind) {
      HabitHistoryKind.skipped => ff.inkFaint,
      HabitHistoryKind.slip => ff.danger,
      HabitHistoryKind.done => ff.success,
      HabitHistoryKind.partial => colors.solid,
    };
    return Semantics(
      button: true,
      label: '$title, $subtitle, $value',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.rowMin + AppSpacing.xs,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                FFIconTile.soft(
                  icon: HabitIcons.of(habit.iconKey),
                  colors: colors,
                  size: HabitDimens.historyTile,
                  radius: AppRadii.tile,
                  iconSize: HabitDimens.historyIcon,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.rowTitle.copyWith(
                          fontSize: HabitDimens.historyTitle,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall.copyWith(
                          color: ff.inkFaint,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  value,
                  style: context.text.rowTitle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

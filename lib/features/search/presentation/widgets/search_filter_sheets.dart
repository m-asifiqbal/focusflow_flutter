/// ============================================================
/// SEARCH FILTER SHEETS — Date range · Tag · Priority pickers (screen 06)
/// ============================================================
///
/// Each picker returns the updated [SearchFilters], or null when dismissed.
/// Date ranges filter on the last edit; "Custom…" opens the Material range
/// picker. Priority applies to tasks only (other modules drop out).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// A chosen value (null = "Any").
class _Choice<T> {
  const _Choice(this.value);
  final T? value;
}

Future<_Choice<T>?> _showChoices<T>(
  BuildContext context, {
  required String title,
  required List<(T?, String)> options,
  required T? selected,
}) {
  return showFFBottomSheet<_Choice<T>>(
    context,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.sectionTitle),
          ),
        ),
        FFGroupedList(
          dividerIndent: AppSpacing.lg,
          children: [
            for (final (value, label) in options)
              FFListRow(
                title: label,
                chevron: false,
                trailing: value == selected
                    ? Icon(
                        FontAwesomeIcons.check,
                        size: 15,
                        color: context.ff.primary,
                      )
                    : null,
                semanticLabel: value == selected ? '$label, selected' : label,
                onTap: () => Navigator.of(sheet).pop(_Choice<T>(value)),
              ),
          ],
        ),
      ],
    ),
  );
}

enum _Range { today, week, month, year, custom }

/// Date range of the last edit.
Future<SearchFilters?> pickSearchDateRange(
  BuildContext context,
  SearchFilters filters,
  DateTime now,
) async {
  final today = DateUtilsX.dateOnly(now);
  final tomorrow = DateUtilsX.addDays(today, 1);
  final picked = await _showChoices<_Range>(
    context,
    title: 'Date range',
    selected: filters.hasDateRange ? _Range.custom : null,
    options: const [
      (null, 'Any time'),
      (_Range.today, 'Today'),
      (_Range.week, 'Last 7 days'),
      (_Range.month, 'Last 30 days'),
      (_Range.year, 'This year'),
      (_Range.custom, 'Custom…'),
    ],
  );
  if (picked == null || !context.mounted) return null;
  DateTime? from;
  DateTime? to = tomorrow;
  switch (picked.value) {
    case null:
      to = null;
    case _Range.today:
      from = today;
    case _Range.week:
      from = DateUtilsX.addDays(today, -6);
    case _Range.month:
      from = DateUtilsX.addDays(today, -29);
    case _Range.year:
      from = DateTime(today.year);
    case _Range.custom:
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: today,
        initialDateRange: filters.from == null
            ? null
            : DateTimeRange(
                start: filters.from!,
                end: DateUtilsX.addDays(filters.to ?? tomorrow, -1),
              ),
      );
      if (range == null) return null;
      from = DateUtilsX.dateOnly(range.start);
      to = DateUtilsX.addDays(DateUtilsX.dateOnly(range.end), 1);
  }
  return filters.copyWith(from: () => from, to: () => to);
}

/// Label of the date-range pill ("Date range" when unset).
String searchDateRangeLabel(SearchFilters f) {
  if (!f.hasDateRange) return 'Date range';
  String d(DateTime x) => '${x.month}/${x.day}';
  final from = f.from;
  final last = f.to == null ? null : DateUtilsX.addDays(f.to!, -1);
  if (from != null && last != null && DateUtilsX.isSameDay(from, last)) {
    return d(from);
  }
  return '${from == null ? '…' : d(from)} – ${last == null ? '…' : d(last)}';
}

/// Single tag (live list of every tag).
Future<SearchFilters?> pickSearchTag(
  BuildContext context,
  WidgetRef ref,
  SearchFilters filters,
) async {
  final tags = await ref.read(tagsRepositoryProvider).watchTags().first;
  if (!context.mounted) return null;
  final picked = await _showChoices<Tag>(
    context,
    title: 'Tag',
    selected: tags.where((t) => t.id == filters.tagId).firstOrNull,
    options: [(null, 'Any tag'), for (final t in tags) (t, '#${t.name}')],
  );
  if (picked == null) return null;
  return filters.copyWith(
    tagId: () => picked.value?.id,
    tagName: () => picked.value?.name,
  );
}

/// Minimum task priority.
Future<SearchFilters?> pickSearchPriority(
  BuildContext context,
  SearchFilters filters,
) async {
  final picked = await _showChoices<int>(
    context,
    title: 'Priority',
    selected: filters.minPriority,
    options: [
      (null, 'Any priority'),
      (TaskPriority.low.index, 'Low and above'),
      (TaskPriority.medium.index, 'Medium and above'),
      (TaskPriority.high.index, 'High only'),
    ],
  );
  if (picked == null) return null;
  return filters.copyWith(minPriority: () => picked.value);
}

/// Label of the priority pill.
String searchPriorityLabel(SearchFilters f) => switch (f.minPriority) {
  null => 'Priority',
  final p => '${TaskPriority.fromValue(p).label}+',
};

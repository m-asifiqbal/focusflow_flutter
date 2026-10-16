/// ============================================================
/// REPEAT SHEET — "Repeat" picker of the task / reminder editors (11, 13)
/// ============================================================
///
/// What: Never · Daily · Weekdays · Weekly (choose days) · Monthly ·
/// Yearly · Custom… (every N units, ends never / on date / after N).
/// One-tap choices close the sheet; Weekly and Custom expand in place and
/// confirm with "Done". Resolves to a [Picked] RRULE (null value = never),
/// or null when dismissed.
/// Why: one FocusFlow-style sheet for every repeating item; the rule logic
/// lives in [RepeatDraft] (pure, tested).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/repeat_custom_panel.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/repeat_draft.dart';

/// Opens the repeat sheet for [current] (RRULE or null) anchored on
/// [start] (the item's day).
Future<Picked<String?>?> showRepeatSheet(
  BuildContext context, {
  required String? current,
  required DateTime start,
  int weekStartsOn = DateTime.monday,
}) {
  return showFFBottomSheet<Picked<String?>>(
    context,
    wrap: false,
    builder: (_) => _RepeatSheet(
      initial: RepeatDraft.fromRule(current, start),
      start: start,
      weekStartsOn: weekStartsOn,
    ),
  );
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({
    required this.initial,
    required this.start,
    required this.weekStartsOn,
  });

  final RepeatDraft initial;
  final DateTime start;
  final int weekStartsOn;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late RepeatDraft _draft = widget.initial;

  bool get _expanded =>
      _draft.mode == RepeatChoice.weekly || _draft.mode == RepeatChoice.custom;

  void _choose(RepeatChoice mode) {
    final next = _draft.copyWith(mode: mode);
    if (mode == RepeatChoice.weekly || mode == RepeatChoice.custom) {
      setState(() => _draft = next);
      return;
    }
    Navigator.of(context).pop(Picked(next.toRRule()));
  }

  String _sub(RepeatChoice mode) =>
      _draft.copyWith(mode: mode).label(widget.start);

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final mode = _draft.mode;
    final valid = _draft.toRRule() != null;
    final repeatTint = ModuleStyle.tasks.colors;
    OptionRow row(
      RepeatChoice m,
      String label,
      IconData icon,
      ModuleColors colors, {
      String? subtitle,
    }) => OptionRow(
      label: label,
      subtitle: subtitle,
      icon: icon,
      colors: colors,
      selected: mode == m,
      onTap: () => _choose(m),
    );
    return FFBottomSheet(
      footer: _expanded
          ? FFPrimaryButton(
              label: 'Done',
              onPressed: valid
                  ? () => Navigator.of(context).pop(Picked(_draft.toRRule()))
                  : null,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            'Repeat',
            subtitle: mode == RepeatChoice.none
                ? 'Does not repeat'
                : _draft.label(widget.start),
          ),
          FFGroupedList(
            dividerIndent: AppSpacing.lg,
            children: [
              row(
                RepeatChoice.none,
                'Never',
                FontAwesomeIcons.ban,
                ActionTints.lock,
              ),
              row(
                RepeatChoice.daily,
                'Daily',
                FontAwesomeIcons.solidSun,
                TagPalette.finance,
              ),
              row(
                RepeatChoice.weekdays,
                'Weekdays',
                FontAwesomeIcons.briefcase,
                TagPalette.work,
                subtitle: 'Monday to Friday',
              ),
              row(
                RepeatChoice.weekly,
                'Weekly',
                FontAwesomeIcons.calendarWeek,
                repeatTint,
                subtitle: mode == RepeatChoice.weekly
                    ? null
                    : _sub(RepeatChoice.weekly),
              ),
              row(
                RepeatChoice.monthly,
                'Monthly',
                FontAwesomeIcons.calendarDays,
                TagPalette.design,
                subtitle: _sub(RepeatChoice.monthly),
              ),
              row(
                RepeatChoice.yearly,
                'Yearly',
                FontAwesomeIcons.solidCalendar,
                TagPalette.personal,
                subtitle: _sub(RepeatChoice.yearly),
              ),
              row(
                RepeatChoice.custom,
                'Custom…',
                FontAwesomeIcons.sliders,
                ActionTints.share,
              ),
            ],
          ),
          if (mode == RepeatChoice.weekly) ...[
            const SizedBox(height: AppSpacing.xl),
            const FFSectionLabel('On'),
            WeekdayToggleRow(
              selected: _draft.weekdays,
              weekStartsOn: widget.weekStartsOn,
              onToggle: (w) => setState(() => _draft = _draft.toggleWeekday(w)),
            ),
          ],
          if (mode == RepeatChoice.custom) ...[
            const SizedBox(height: AppSpacing.xl),
            RepeatCustomPanel(
              draft: _draft,
              start: widget.start,
              weekStartsOn: widget.weekStartsOn,
              onChanged: (d) => setState(() => _draft = d),
            ),
          ],
          if (_expanded && !valid) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pick at least one day',
              style: context.text.meta.copyWith(color: ff.danger),
            ),
          ],
        ],
      ),
    );
  }
}

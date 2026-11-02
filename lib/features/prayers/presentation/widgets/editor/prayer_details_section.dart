/// ============================================================
/// PRAYER DETAILS SECTION — days, reminders, priority and the rest
/// ============================================================
///
/// What (one grouped list each):
///   * DAYS — "Only between" a date range (the weekdays and calendar rules
///     are PrayerCalendarSection, just above);
///   * REMINDERS — before the start (a fast: Suhoor), before the end while
///     not marked (a fast: Iftar, "At the end"), and priority: Low (quiet),
///     Normal (notification), High (alarm — rings, full screen);
///   * DETAILS — place, colour, daily goal (counting practices), notes.
/// Why: the user's list (priority, colour, reminder time, place, notes) in
/// the editor's order of importance; each row one tap to a small sheet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/tradition_profile.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/editor/prayer_editor_sheets.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

class PrayerDetailsSection extends StatelessWidget {
  const PrayerDetailsSection({
    required this.draft,
    required this.onChanged,
    required this.now,
    super.key,
  });

  final Prayer draft;
  final ValueChanged<Prayer> onChanged;
  final DateTime now;

  static Widget _tile(IconData icon) => FFIconTile.soft(
    icon: icon,
    colors: PrayerStyle.module,
    size: AppSizes.iconTileSm,
  );

  String _before(int? m, {required bool end}) {
    if (m == null) return tr('Off');
    if (m == 0) return end ? tr('At the end') : tr('At the start');
    return tr('{m} min before', {'m': m});
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final fast = draft.kind.isFast;
    final profile = PrayerTraditionProfile.of(draft.tradition);
    final from = draft.startDate;
    final to = draft.endDate;
    final dates = from == null || to == null
        ? tr('Always')
        : '${DateFormats.of('d MMM y').format(from)} – '
              '${DateFormats.of('d MMM y').format(to)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFGroupedList(
          children: [
            FFListRow(
              leading: _tile(FontAwesomeIcons.calendarDays),
              title: tr('Only between'),
              value: dates,
              chevron: true,
              onTap: () async {
                final range = await showPrayerDatesSheet(
                  context,
                  from: from,
                  to: to,
                  now: now,
                );
                if (range != null) {
                  onChanged(
                    draft.copyWith(startDate: range.start, endDate: range.end),
                  );
                }
              },
            ),
            if (from != null)
              FFListRow(
                title: tr('Repeat for good'),
                leading: _tile(FontAwesomeIcons.repeat),
                onTap: () => onChanged(draft.copyWith(clearDates: true)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        FFSectionLabel(tr('Reminders')),
        const SizedBox(height: AppSpacing.sm),
        FFGroupedList(
          children: [
            FFListRow(
              leading: _tile(FontAwesomeIcons.solidBell),
              title: fast
                  ? profile.fast.remindStartLabel
                  : tr('Before it starts'),
              value: _before(draft.remindBefore, end: false),
              chevron: true,
              onTap: () async {
                final picked = await showMinutesBeforeSheet(
                  context,
                  title: fast
                      ? profile.fast.remindStartLabel
                      : tr('Before it starts'),
                  selected: draft.remindBefore,
                  choices: const [0, 5, 10, 15, 20, 30, 45, 60],
                  label: (m) => _before(m, end: false),
                );
                if (picked == null) return;
                onChanged(
                  picked.value == null
                      ? draft.copyWith(clearRemindBefore: true)
                      : draft.copyWith(remindBefore: picked.value),
                );
              },
            ),
            if (draft.end != null)
              FFListRow(
                leading: _tile(FontAwesomeIcons.hourglassHalf),
                title: fast
                    ? profile.fast.remindEndLabel
                    : tr('Before it ends'),
                subtitle: fast ? null : tr('Only if not marked yet'),
                value: _before(draft.remindBeforeEnd, end: true),
                chevron: true,
                onTap: () async {
                  final picked = await showMinutesBeforeSheet(
                    context,
                    title: fast
                        ? profile.fast.remindEndLabel
                        : tr('Before it ends'),
                    selected: draft.remindBeforeEnd,
                    choices: const [0, 5, 10, 15, 20, 30, 45, 60],
                    label: (m) => _before(m, end: true),
                  );
                  if (picked == null) return;
                  onChanged(
                    picked.value == null
                        ? draft.copyWith(clearRemindBeforeEnd: true)
                        : draft.copyWith(remindBeforeEnd: picked.value),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FFSegmented<PrayerPriority>(
          segments: [
            for (final p in PrayerPriority.values)
              FFSegment(value: p, label: p.label),
          ],
          value: draft.priority,
          onChanged: (p) => onChanged(draft.copyWith(priority: p)),
          height: 40,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          switch (draft.priority) {
            PrayerPriority.low => tr('A quiet notification, no sound.'),
            PrayerPriority.normal => tr('A notification with a sound.'),
            PrayerPriority.high => tr(
              'A real alarm: rings full screen until you stop or snooze it.',
            ),
          },
          style: text.meta.copyWith(
            color: ff.inkMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        FFSectionLabel(tr('Details')),
        const SizedBox(height: AppSpacing.sm),
        FFGroupedList(
          children: [
            FFListRow(
              leading: _tile(
                PrayerStyle.placeIcon(draft.place, draft.tradition),
              ),
              title: tr('Place'),
              value: draft.place.trim().isEmpty
                  ? tr('Any')
                  : draft.place.trim(),
              chevron: true,
              onTap: () async {
                final picked = await showOptionSheet<String>(
                  context,
                  title: tr('Place'),
                  options: [
                    for (final p in {
                      '',
                      ...profile.places,
                      if (draft.place.trim().isNotEmpty) draft.place.trim(),
                    })
                      OptionItem(
                        value: p,
                        label: p.isEmpty ? tr('Any') : p,
                        icon: p.isEmpty
                            ? FontAwesomeIcons.earthAmericas
                            : PrayerStyle.placeIcon(p, draft.tradition),
                        colors: PrayerStyle.module,
                      ),
                    OptionItem(
                      value: '\u0000',
                      label: tr('Other…'),
                      icon: FontAwesomeIcons.pen,
                      colors: PrayerStyle.module,
                    ),
                  ],
                  selected: draft.place.trim(),
                  accent: PrayerStyle.module.solid,
                );
                if (picked == null || !context.mounted) return;
                var place = picked.value;
                if (place == '\u0000') {
                  final typed = await showTextInputSheet(
                    context,
                    title: tr('Place'),
                    initial: draft.place,
                  );
                  if (typed == null) return;
                  place = typed;
                }
                onChanged(draft.copyWith(place: place));
              },
            ),
            if (draft.kind.counts)
              FFListRow(
                leading: _tile(FontAwesomeIcons.bullseye),
                title: profile.goalTitle,
                value: draft.targetCount?.toString() ?? tr('No goal'),
                chevron: true,
                onTap: () async {
                  final picked = await showGoalSheet(
                    context,
                    selected: draft.targetCount,
                    goals: profile.goals,
                    title: profile.goalTitle,
                  );
                  if (picked == null) return;
                  onChanged(
                    picked.value == null
                        ? draft.copyWith(clearTarget: true)
                        : draft.copyWith(targetCount: picked.value),
                  );
                },
              ),
            FFListRow(
              leading: _tile(FontAwesomeIcons.solidNoteSticky),
              title: tr('Notes'),
              value: draft.note.trim().isEmpty
                  ? tr('None')
                  : draft.note.trim().split('\n').first,
              chevron: true,
              onTap: () async {
                final typed = await showTextInputSheet(
                  context,
                  title: tr('Notes'),
                  hint: profile.notesHint,
                  initial: draft.note,
                );
                if (typed != null) onChanged(draft.copyWith(note: typed));
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(tr('Colour'), style: text.meta.copyWith(color: ff.inkMuted)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final hex in PrayerStyle.palette)
              Semantics(
                button: true,
                selected: draft.colorHex == hex,
                label: tr('Colour {hex}', {'hex': hex}),
                excludeSemantics: true,
                child: FFPressable(
                  onTap: () => onChanged(draft.copyWith(colorHex: hex)),
                  child: Container(
                    width: AppSizes.minTap,
                    height: AppSizes.minTap,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: draft.colorHex == hex
                            ? ff.ink
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PrayerStyle.hex(hex),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

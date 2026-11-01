/// ============================================================
/// PRAYER JAMAAT SECTION — when the congregation prays, and its reminder
/// ============================================================
///
/// What: Off · Set time · After start. "Set time" is the mosque's clock
/// time (1:30 PM); "After start" is minutes after the window opens (Maghrib
/// "10 min after the adhan" keeps following sunset). Then "Remind me" (Off,
/// at the jamaat, or N min before) and today's jamaat under them — with a
/// note when it falls outside today's window.
/// Why: praying with the congregation needs its own time, not the window's
/// start. Shown for prayers (not fasts or counting practices); the words
/// say "Jamaat" for Islam and "Congregation" for every other tradition.
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
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/editor/prayer_editor_sheets.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

enum _Mode { off, at, after }

class PrayerJamaatSection extends StatelessWidget {
  const PrayerJamaatSection({
    required this.draft,
    required this.onChanged,
    required this.sunFor,
    required this.today,
    required this.use24h,
    super.key,
  });

  final Prayer draft;
  final ValueChanged<Prayer> onChanged;
  final SolarDay? Function(DateTime) sunFor;
  final DateTime today;
  final bool use24h;

  /// Whether a prayer of [kind] can have a congregation time.
  static bool appliesTo(PrayerKind kind) => !kind.isFast && !kind.counts;

  static const _afterChoices = [0, 5, 10, 15, 20, 30, 45, 60, 90];
  static const _remindChoices = [0, 5, 10, 15, 20, 30];

  bool get _islam => draft.tradition == PrayerTradition.islam;

  PrayerWindow get _window => PrayerSchedule.windowOn(
    draft,
    today,
    sunFor(today),
    nextSun: sunFor(DateUtilsX.addDays(today, 1)),
    prevSun: sunFor(DateUtilsX.addDays(today, -1)),
  );

  /// Turning it on: a set time 15 minutes into today's window (rounded to
  /// 5), or 10 minutes after the start; reminded 10 minutes before.
  void _switch(_Mode m) {
    switch (m) {
      case _Mode.off:
        onChanged(draft.copyWith(clearJamaat: true));
      case _Mode.at:
        final s = _window.start.add(const Duration(minutes: 15));
        final minutes = (s.hour * 60 + s.minute + 4) ~/ 5 * 5;
        onChanged(
          draft.copyWith(
            jamaat: PrayerJamaat.at(minutes % (24 * 60)),
            remindBeforeJamaat: draft.jamaat == null
                ? 10
                : draft.remindBeforeJamaat,
          ),
        );
      case _Mode.after:
        onChanged(
          draft.copyWith(
            jamaat: const PrayerJamaat.afterStart(10),
            remindBeforeJamaat: draft.jamaat == null
                ? 10
                : draft.remindBeforeJamaat,
          ),
        );
    }
  }

  String _remindLabel(int? m) {
    if (m == null) return tr('Off');
    if (m == 0) return tr('At the jamaat');
    return tr('{m} min before', {'m': m});
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final j = draft.jamaat;
    final mode = j == null
        ? _Mode.off
        : j.afterStart
        ? _Mode.after
        : _Mode.at;
    final window = _window;
    final at = PrayerSchedule.jamaatOn(
      draft,
      today,
      window.start,
      window.until,
      DateUtilsX.atMinutes,
    );
    final outside = at != null && !window.contains(at);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(
          _islam ? tr('Jamaat (congregation)') : tr('Congregation time'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FFSegmented<_Mode>(
          segments: [
            FFSegment(value: _Mode.off, label: tr('Off')),
            FFSegment(value: _Mode.at, label: tr('Set time')),
            FFSegment(value: _Mode.after, label: tr('After start')),
          ],
          value: mode,
          onChanged: _switch,
          height: 40,
        ),
        if (j != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FFGroupedList(
            children: [
              if (j.afterStart)
                FFListRow(
                  leading: _tile(FontAwesomeIcons.hourglassStart),
                  title: tr('After the start'),
                  value: j.minutes == 0
                      ? tr('At the start')
                      : tr('{m} min', {'m': j.minutes}),
                  chevron: true,
                  onTap: () async {
                    final picked = await showOptionSheet<int>(
                      context,
                      title: tr('After the start'),
                      subtitle: tr('Follows the start time every day'),
                      options: [
                        for (final m in _afterChoices)
                          OptionItem(
                            value: m,
                            label: m == 0
                                ? tr('At the start')
                                : tr('{m} min', {'m': m}),
                            icon: FontAwesomeIcons.hourglassStart,
                            colors: PrayerStyle.module,
                          ),
                      ],
                      selected: j.minutes,
                      accent: PrayerStyle.module.solid,
                    );
                    final m = picked?.value;
                    if (m != null) {
                      onChanged(
                        draft.copyWith(jamaat: PrayerJamaat.afterStart(m)),
                      );
                    }
                  },
                )
              else
                FFListRow(
                  leading: _tile(FontAwesomeIcons.clock),
                  title: tr('Time'),
                  value: PrayerFormat.time(
                    DateUtilsX.atMinutes(today, j.minutes),
                    use24h: use24h,
                  ),
                  chevron: true,
                  onTap: () async {
                    final m = await showPrayerTimeSheet(
                      context,
                      title: _islam
                          ? tr('Jamaat time')
                          : tr('Congregation time'),
                      minutes: j.minutes,
                      use24h: use24h,
                    );
                    if (m != null) {
                      onChanged(draft.copyWith(jamaat: PrayerJamaat.at(m)));
                    }
                  },
                ),
              FFListRow(
                leading: _tile(FontAwesomeIcons.solidBell),
                title: tr('Remind me'),
                subtitle: tr('Only if not marked yet'),
                value: _remindLabel(draft.remindBeforeJamaat),
                chevron: true,
                onTap: () async {
                  final picked = await showMinutesBeforeSheet(
                    context,
                    title: tr('Remind me'),
                    selected: draft.remindBeforeJamaat,
                    choices: _remindChoices,
                    label: _remindLabel,
                  );
                  if (picked == null) return;
                  onChanged(
                    picked.value == null
                        ? draft.copyWith(clearRemindBeforeJamaat: true)
                        : draft.copyWith(remindBeforeJamaat: picked.value),
                  );
                },
              ),
            ],
          ),
          if (at != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                _islam
                    ? tr('Today: jamaat at {time}', {
                        'time': PrayerFormat.time(at, use24h: use24h),
                      })
                    : tr('Today: congregation at {time}', {
                        'time': PrayerFormat.time(at, use24h: use24h),
                      }),
                if (outside) tr('outside today\'s window'),
              ].join(' · '),
              style: text.meta.copyWith(
                color: outside ? ff.warning : ff.inkMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ],
    );
  }

  static Widget _tile(IconData icon) => FFIconTile.soft(
    icon: icon,
    colors: PrayerStyle.module,
    size: AppSizes.iconTileSm,
  );
}

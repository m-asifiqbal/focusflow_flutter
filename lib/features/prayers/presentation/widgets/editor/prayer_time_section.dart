/// ============================================================
/// PRAYER TIME SECTION — start and end of the window, auto or manual
/// ============================================================
///
/// What: "Starts" and "Ends", each Auto (a sun event ± minutes — dawn,
/// sunrise, noon, Asr, sunset, nightfall, midnight, last third) or Manual
/// (a clock time); the end can also be None. Under them, today's resolved
/// window: "Today 3:42 – 5:21 PM · 1h 39m".
/// Why: the design's start-to-end window for every prayer and fast, for
/// every tradition; the preview answers "what will this actually be?"
/// before saving. Switching modes keeps today's time, so nothing jumps.
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

enum _Mode { auto, manual, none }

class PrayerTimeSection extends StatelessWidget {
  const PrayerTimeSection({
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

  SolarDay? get _sun => sunFor(today);

  /// Today's minute of [rule] (for switching modes without a jump).
  int _minuteOf(PrayerTimeRule rule) {
    final t = rule.on(today, _sun);
    return t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final window = PrayerSchedule.windowOn(
      draft,
      today,
      _sun,
      nextSun: sunFor(DateUtilsX.addDays(today, 1)),
      prevSun: sunFor(DateUtilsX.addDays(today, -1)),
    );
    final length = window.length;
    final fast = draft.kind.isFast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ruleBlock(
          context,
          label: fast ? tr('Starts (Suhoor ends)') : tr('Starts'),
          rule: draft.start,
          allowNone: false,
          onRule: (r) => onChanged(draft.copyWith(start: r)),
          onNone: null,
        ),
        const SizedBox(height: AppSpacing.md),
        _ruleBlock(
          context,
          label: fast ? tr('Ends (Iftar)') : tr('Ends'),
          rule: draft.end,
          allowNone: !fast,
          onRule: (r) => onChanged(draft.copyWith(end: r)),
          onNone: () => onChanged(draft.copyWith(clearEnd: true)),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: PrayerStyle.module.soft,
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.clock,
                size: 15,
                color: PrayerStyle.module.ink,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tr('Today {window}', {
                    'window': PrayerFormat.window(window, use24h: use24h),
                  }),
                  style: text.rowTitle.copyWith(color: PrayerStyle.module.ink),
                ),
              ),
              if (length != null)
                Text(
                  PrayerFormat.duration(length),
                  style: text.meta.copyWith(color: PrayerStyle.module.ink),
                ),
            ],
          ),
        ),
        if (draft.usesSun && _sun == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(
              'No location yet: the usual times above are used until you set one.',
            ),
            style: text.meta.copyWith(
              color: ff.inkMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  Widget _ruleBlock(
    BuildContext context, {
    required String label,
    required PrayerTimeRule? rule,
    required bool allowNone,
    required ValueChanged<PrayerTimeRule> onRule,
    required VoidCallback? onNone,
  }) {
    final mode = rule == null
        ? _Mode.none
        : rule.isAuto
        ? _Mode.auto
        : _Mode.manual;
    final current = rule;
    void switchTo(_Mode m) {
      if (m == mode) return;
      switch (m) {
        case _Mode.none:
          onNone?.call();
        case _Mode.manual:
          onRule(
            PrayerTimeRule.fixed(
              current == null ? 18 * 60 : _minuteOf(current),
            ),
          );
        case _Mode.auto:
          final minutes = current == null ? 18 * 60 : _minuteOf(current);
          onRule(PrayerTimeRule.auto(_nearestEvent(minutes), minutes: minutes));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(label),
        const SizedBox(height: AppSpacing.sm),
        FFSegmented<_Mode>(
          segments: [
            FFSegment(value: _Mode.auto, label: tr('Auto (sun)')),
            FFSegment(value: _Mode.manual, label: tr('Manual')),
            if (allowNone) FFSegment(value: _Mode.none, label: tr('No end')),
          ],
          value: mode,
          onChanged: switchTo,
          height: 40,
        ),
        if (current != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FFGroupedList(
            children: [
              if (current.isAuto) ...[
                FFListRow(
                  title: tr('Sun event'),
                  value: current.event!.label,
                  chevron: true,
                  onTap: () async {
                    final e = await showSolarEventSheet(
                      context,
                      title: label,
                      selected: current.event,
                      today: _sun,
                      use24h: use24h,
                    );
                    if (e != null) {
                      onRule(
                        PrayerTimeRule.auto(
                          e,
                          offset: current.offset,
                          minutes: current.minutes,
                        ),
                      );
                    }
                  },
                ),
                FFListRow(
                  title: tr('Adjust'),
                  value: current.offset == 0
                      ? tr('Exactly at it')
                      : PrayerFormat.offset(current.offset),
                  chevron: true,
                  onTap: () async {
                    final o = await showOffsetSheet(
                      context,
                      selected: current.offset,
                    );
                    if (o != null) onRule(current.withOffset(o));
                  },
                ),
              ] else
                FFListRow(
                  title: tr('Time'),
                  value: PrayerFormat.time(
                    current.on(today, null),
                    use24h: use24h,
                  ),
                  chevron: true,
                  onTap: () async {
                    final m = await showPrayerTimeSheet(
                      context,
                      title: label,
                      minutes: current.minutes,
                      use24h: use24h,
                    );
                    if (m != null) onRule(PrayerTimeRule.fixed(m));
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// The sun event closest to [minutes] today (dawn without a location).
  SolarEvent _nearestEvent(int minutes) {
    final sun = _sun;
    if (sun == null) return SolarEvent.dawn;
    SolarEvent best = SolarEvent.dawn;
    var gap = 1 << 30;
    for (final e in SolarEvent.values) {
      final t = sun.at(e);
      if (DateUtilsX.dateOnly(t) != today) continue;
      final d = (t.hour * 60 + t.minute - minutes).abs();
      if (d < gap) {
        gap = d;
        best = e;
      }
    }
    return best;
  }
}

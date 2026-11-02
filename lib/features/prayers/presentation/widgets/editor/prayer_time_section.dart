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
import 'package:focusflow/features/prayers/domain/services/tradition_profile.dart';
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
    final profile = PrayerTraditionProfile.of(draft.tradition);
    final fixedLength = _lengthMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ruleBlock(
          context,
          profile: profile,
          label: fast ? profile.fast.startLabel : tr('Starts'),
          rule: draft.start,
          allowNone: false,
          onRule: (r) => onChanged(draft.copyWith(start: r)),
          onNone: null,
        ),
        const SizedBox(height: AppSpacing.md),
        _ruleBlock(
          context,
          profile: profile,
          label: fast ? profile.fast.endLabel : tr('Ends'),
          rule: draft.end,
          allowNone: !fast,
          onRule: (r) => onChanged(draft.copyWith(end: r)),
          onNone: () => onChanged(draft.copyWith(clearEnd: true)),
        ),
        // A sit of 20 minutes, a reading of half an hour: say how long
        // and the end follows the start.
        if (!fast && fixedLength != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FFGroupedList(
            children: [
              FFListRow(
                leading: FFIconTile.soft(
                  icon: FontAwesomeIcons.hourglassHalf,
                  colors: PrayerStyle.module,
                  size: AppSizes.iconTileSm,
                ),
                title: tr('Length'),
                value: PrayerFormat.duration(Duration(minutes: fixedLength)),
                chevron: true,
                onTap: () async {
                  final m = await showLengthSheet(
                    context,
                    selected: fixedLength,
                  );
                  if (m != null) onChanged(draft.copyWith(end: _endFor(m)));
                },
              ),
            ],
          ),
        ],
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

  /// How long the window lasts when both ends move together (both fixed,
  /// or the same sun event at two offsets); null when it changes daily.
  int? get _lengthMinutes {
    final s = draft.start, e = draft.end;
    if (e == null) return null;
    if (!s.isAuto && !e.isAuto) {
      final d = e.minutes - s.minutes;
      return d > 0 ? d : d + 24 * 60;
    }
    if (s.isAuto && e.isAuto && s.event == e.event) {
      final d = e.offset - s.offset;
      return d > 0 ? d : null;
    }
    return null;
  }

  /// The end that lasts [minutes] from the start.
  PrayerTimeRule _endFor(int minutes) {
    final s = draft.start;
    final fallback = (s.minutes + minutes) % (24 * 60);
    return s.isAuto
        ? PrayerTimeRule.auto(
            s.event!,
            offset: s.offset + minutes,
            minutes: fallback,
          )
        : PrayerTimeRule.fixed(fallback);
  }

  Widget _ruleBlock(
    BuildContext context, {
    required PrayerTraditionProfile profile,
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
          onRule(
            PrayerTimeRule.auto(
              _nearestEvent(minutes, profile.sunEvents),
              minutes: minutes,
            ),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(label),
        const SizedBox(height: AppSpacing.sm),
        FFSegmented<_Mode>(
          segments: [
            FFSegment(value: _Mode.auto, label: profile.autoLabel),
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
                  title: profile.sunEventTitle,
                  value: profile.eventLabel(current.event!),
                  chevron: true,
                  onTap: () async {
                    final e = await showSolarEventSheet(
                      context,
                      title: label,
                      selected: current.event,
                      today: _sun,
                      use24h: use24h,
                      events: [
                        ...profile.sunEvents,
                        if (!profile.sunEvents.contains(current.event))
                          current.event!,
                      ],
                      labelOf: profile.eventLabel,
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
                      offsets: {...profile.offsets, current.offset}.toList()
                        ..sort(),
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

  /// The one of [events] closest to [minutes] today (the first without a
  /// location).
  SolarEvent _nearestEvent(int minutes, List<SolarEvent> events) {
    final sun = _sun;
    SolarEvent best = events.first;
    if (sun == null) return best;
    var gap = 1 << 30;
    for (final e in events) {
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

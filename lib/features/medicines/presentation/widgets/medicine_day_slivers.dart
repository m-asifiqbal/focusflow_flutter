/// ============================================================
/// MEDICINE DAY SLIVERS — one day's doses, as slivers
/// ============================================================
///
/// Shared by the medicine list (`/library/medicines`) and the Reminders
/// list's "Medicine" chip, so both read the same: the "Today's doses"
/// hero, refill banners, the doses by part of day (MORNING · AFTERNOON ·
/// EVENING & NIGHT, cards from dose_card.dart), the as-needed medicines
/// with "Log a dose", and — on the medicine list — "Your medicines".
/// Cards animate in with a short fade + rise when the day is first shown —
/// never again when they scroll back into view (a lazy list rebuilds them,
/// which used to replay the fade on every scroll: the "flicker").
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/widgets/dose_card.dart';
import 'package:focusflow/features/medicines/presentation/widgets/medicine_cabinet.dart';
import 'package:focusflow/features/medicines/presentation/widgets/medicine_today_card.dart';
import 'package:focusflow/features/medicines/presentation/widgets/refill_sheet.dart';
import 'package:go_router/go_router.dart';

/// Parts of the day the timeline is split into (by dose minute).
enum _DayPart { morning, afternoon, evening }

_DayPart _partOf(int minutes) => minutes < 12 * 60
    ? _DayPart.morning
    : minutes < 17 * 60
    ? _DayPart.afternoon
    : _DayPart.evening;

String _label(_DayPart p) => switch (p) {
  _DayPart.morning => tr('Morning'),
  _DayPart.afternoon => tr('Afternoon'),
  _DayPart.evening => tr('Evening & night'),
};

/// The slivers of [day] at [now].
List<Widget> medicineDaySlivers(
  BuildContext context, {
  required MedicineDay day,
  required DateTime now,
  required bool use24h,
  bool showCabinet = true,
}) {
  if (day.isEmpty) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.xxl,
          ),
          child: FFEmptyState(
            colors: MedicineStyle.colors,
            icon: ModuleStyle.medicines.icon,
            title: tr('Add your first medicine'),
            body: tr(
              'Get a reminder for every dose, see what you\'ve taken and know when to refill.',
            ),
            ctaLabel: tr('Add medicine'),
            onCta: () => context.push(AppRoutes.newMedicinePath),
          ),
        ),
      ),
    ];
  }
  final scheduled = day.scheduled;
  final logged = [
    for (final s in day.slots)
      if (s.isAsNeeded) s,
  ];
  final parts = <_DayPart, List<DoseSlot>>{};
  for (final s in [...scheduled, ...logged]..sort(_byTime)) {
    parts.putIfAbsent(_partOf(s.minutes), () => []).add(s);
  }
  final low = day.lowStock;
  final asNeeded = day.asNeeded;
  const side = EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.screen);
  final group = DateUtilsX.dayKey(day.day);
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          0,
        ),
        child: _Appear(
          group: group,
          child: MedicineTodayCard(
            day: day.day,
            slots: scheduled,
            now: now,
            use24h: use24h,
          ),
        ),
      ),
    ),
    for (final m in low)
      SliverToBoxAdapter(
        key: ValueKey('low-${m.id}'),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            AppSpacing.cardGap,
            AppSpacing.screen,
            0,
          ),
          child: _Appear(
            group: group,
            child: MedicineRefillBanner(medicine: m),
          ),
        ),
      ),
    if (parts.isEmpty && asNeeded.isEmpty)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            AppSpacing.xxl,
            AppSpacing.screen,
            0,
          ),
          child: FFEmptyState.compact(
            colors: MedicineStyle.colors,
            icon: ModuleStyle.medicines.icon,
            title: tr('No doses this day'),
            body: DateUtilsX.isSameDay(day.day, now)
                ? tr('Nothing to take today.')
                : tr('Nothing is scheduled for this day.'),
          ),
        ),
      ),
    for (final p in _DayPart.values)
      if (parts[p] case final slots?) ...[
        SliverToBoxAdapter(child: _Section(_label(p))),
        SliverList.builder(
          itemCount: slots.length,
          itemBuilder: (context, i) => _Appear(
            key: ValueKey(slots[i].id),
            group: group,
            child: DoseCard(slot: slots[i], now: now, use24h: use24h),
          ),
        ),
      ],
    if (asNeeded.isNotEmpty) ...[
      SliverToBoxAdapter(child: _Section(tr('As needed'))),
      SliverToBoxAdapter(
        child: Padding(
          padding: side,
          child: AsNeededList(medicines: asNeeded),
        ),
      ),
    ],
    if (showCabinet) ...[
      SliverToBoxAdapter(child: _Section(tr('Your medicines'))),
      SliverToBoxAdapter(
        child: Padding(
          padding: side,
          child: MedicineCabinet(medicines: day.medicines, day: day.day),
        ),
      ),
    ],
  ];
}

int _byTime(DoseSlot a, DoseSlot b) {
  final t = a.minutes.compareTo(b.minutes);
  return t != 0 ? t : a.medicine.name.compareTo(b.medicine.name);
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => FFSectionLabel(
    label,
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.screen,
      AppSpacing.xxl,
      AppSpacing.screen,
      AppSpacing.md,
    ),
  );
}

/// A short fade + rise for the cards built while [group] (a day) is first
/// revealed — within [window] of its first card, remembered in the
/// route's [PageStorage]. A card a lazy list rebuilds later (scrolled back
/// into view) shows at once, so scrolling never makes cards blink. Skipped
/// with reduce motion.
class _Appear extends StatefulWidget {
  const _Appear({required this.group, required this.child, super.key});

  final String group;
  final Widget child;

  static const Duration window = Duration(milliseconds: 600);

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> {
  late final bool _animate = _inFirstReveal();

  bool _inFirstReveal() {
    final bucket = PageStorage.maybeOf(context);
    if (bucket == null) return false;
    final id = ('medicine-appear', widget.group);
    // Frame time (monotonic; the test clock in widget tests).
    final now = SchedulerBinding.instance.currentFrameTimeStamp.inMilliseconds;
    final start = bucket.readState(context, identifier: id);
    if (start is! int) {
      bucket.writeState(context, now, identifier: id);
      return true;
    }
    return now - start < _Appear.window.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (!_animate || context.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

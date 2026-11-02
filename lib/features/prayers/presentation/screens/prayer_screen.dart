/// ============================================================
/// PRAYER SCREEN — today's prayers, fasts, counters and progress
/// ============================================================
///
/// What: the Prayer page (pushed from Home, Library, Insights or a
/// notification): header (date · Hijri date, add, settings), a "you moved" banner, a
/// "set your location" banner while sun-based prayers have none, the hero
/// (now / next), today's prayers, fasts and counting practices, then
/// progress and the prayer tip of the day. Not set up yet → the "Set up Prayer" invitation.
/// Why: today first, progress second, one scroll — see the design brief.
/// Layout only: every action is in prayer_flows.dart.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_tips.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_flows.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_add_sheet.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_clock_ticker.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_day_card.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_hero.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_location_sheets.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_practice_cards.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_progress_section.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  /// Where the phone is now, when far from the saved place.
  GeoPoint? _moved;

  @override
  void initState() {
    super.initState();
    // Once per visit, quietly (never a prompt): did the user travel?
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final here = await prayerTravelCheck(ref);
      if (mounted && here != null) setState(() => _moved = here);
    });
  }

  Future<void> _updateToHere() async {
    final here = _moved;
    if (here == null) return;
    setState(() => _moved = null);
    await savePrayerLocation(
      ref,
      here,
      label: prayerPlaceLabel(here),
      precise: ref.read(prayerPrefsProvider).precise,
    );
    if (mounted) {
      showFFToast(
        context,
        tr('Prayer times set for {place}', {'place': prayerPlaceLabel(here)}),
        icon: FontAwesomeIcons.locationCrosshairs,
      );
    }
  }

  Future<void> _openLog(PrayerSlot slot) => openPrayerLog(context, ref, slot);

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(prayerTodayProvider);
    final prefs = ref.watch(prayerPrefsProvider);
    final hijri = ref.watch(prayerDateLineProvider);
    final now = ref.watch(minuteClockProvider);
    final date = DateFormats.of('EEEE, d MMMM').format(now);
    final actions = [
      FFRoundIconButton(
        icon: FontAwesomeIcons.plus,
        semanticLabel: tr('Add prayer'),
        onPressed: () => unawaited(showPrayerAddSheet(context)),
      ),
      FFRoundIconButton(
        icon: FontAwesomeIcons.gear,
        semanticLabel: tr('Prayer settings'),
        onPressed: () => context.push(AppRoutes.prayerSettings),
      ),
    ];
    // The page wakes at the exact second a waqt begins or ends (the minute
    // clock alone could leave the hero up to a minute behind).
    return MinuteTicker(
      child: PrayerClockTicker(
        at: today.valueOrNull?.nextChange,
        child: FFScaffold(
          body: Column(
            children: [
              FFNavHeader(
                leading: const FFBackButton(),
                title: tr('Prayer'),
                trailing: actions,
              ),
              Expanded(
                child: today.when(
                  loading: () => const FFLoadingView(),
                  error: (e, _) => Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.screen),
                    child: FFErrorBanner(
                      message: tr('Couldn\'t load your prayers.'),
                      onRetry: () => ref.invalidate(prayersProvider),
                    ),
                  ),
                  data: (d) => d.hasPrayers
                      ? _content(context, d, prefs.hasLocation, date, hijri)
                      : _empty(context, prefs.isSetUp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, bool setUp) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.screen),
      child: setUp
          ? FFEmptyState(
              colors: PrayerStyle.module,
              icon: FontAwesomeIcons.handsPraying,
              title: tr('No prayers yet'),
              body: tr('Add a prayer, a fast or a daily remembrance.'),
              ctaLabel: tr('Add prayer'),
              onCta: () => unawaited(showPrayerAddSheet(context)),
              hint: tr('Or start from a tradition'),
              onHint: () => context.push(AppRoutes.prayerSetup),
            )
          : FFEmptyState(
              colors: PrayerStyle.module,
              icon: FontAwesomeIcons.handsPraying,
              title: tr('Set up Prayer'),
              body: tr(
                'Reminders for each prayer, its time window, and your progress — for any tradition.',
              ),
              ctaLabel: tr('Get started'),
              ctaIcon: FontAwesomeIcons.arrowRight,
              onCta: () => context.push(AppRoutes.prayerSetup),
            ),
    ),
  );

  Widget _content(
    BuildContext context,
    PrayerToday d,
    bool hasLocation,
    String date,
    String? hijri,
  ) {
    final ff = context.ff;
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final progress = ref.watch(prayerProgressProvider);
    final prefs = ref.watch(prayerPrefsProvider);
    final needsPlace = !hasLocation && d.slots.any((s) => s.prayer.usesSun);
    const gap = SizedBox(height: AppSpacing.sm + 2);
    final moved = _moved;
    final lat = prefs.latitude;
    final lng = prefs.longitude;
    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        if (moved != null && lat != null && lng != null) ...[
          PrayerTravelBanner(
            km: moved.distanceKm(GeoPoint(lat, lng)),
            onUpdate: () => unawaited(_updateToHere()),
            onDismiss: () => setState(() => _moved = null),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (needsPlace) ...[
          FFInfoBanner(
            icon: FontAwesomeIcons.locationCrosshairs,
            colors: PrayerStyle.module,
            text: tr(
              'Set your location for exact prayer times. Until then, the usual times are used.',
            ),
            actionLabel: tr('Set location'),
            onAction: () => unawaited(showPrayerLocationSheet(context, ref)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _DateLine(date: date, hijri: hijri),
        const SizedBox(height: AppSpacing.md),
        PrayerHeroCard(
          slot: d.card,
          now: d.now,
          use24h: use24h,
          sunFor: ref.watch(prayerSunProvider),
          located: hasLocation,
          southern: (lat ?? 0) < 0,
          onOpen: () {
            final n = d.card;
            if (n != null) unawaited(_openLog(n));
          },
        ),
        if (d.allDone) ...[
          const SizedBox(height: AppSpacing.md),
          const _AllDone(),
        ],
        const SizedBox(height: AppSpacing.section),
        FFSectionHeader(
          title: tr('Today'),
          trailing: FFTextButton(
            label: hasLocation ? prefs.placeLabel : tr('Set location'),
            icon: FontAwesomeIcons.locationDot,
            color: ff.inkMuted,
            onPressed: () => unawaited(showPrayerLocationSheet(context, ref)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (d.prayers.isEmpty)
          Text(
            tr('Nothing due today.'),
            style: context.text.bodySmall.copyWith(color: ff.inkMuted),
          ),
        if (d.prayers.isNotEmpty) ...[
          PrayerDayCard(
            slots: d.prayers,
            now: d.now,
            use24h: use24h,
            onMark: (s) => unawaited(markPrayer(context, ref, s)),
            onTap: (s) => unawaited(_openLog(s)),
          ),
          gap,
        ],
        if (d.fasts.isNotEmpty || d.counters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          FFSectionHeader(title: tr('Fasts and practices')),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final s in d.fasts) ...[
          PrayerFastCard(
            slot: s,
            now: d.now,
            use24h: use24h,
            onTap: () => unawaited(_openLog(s)),
          ),
          gap,
        ],
        for (final s in d.counters) ...[
          PrayerCounterCard(
            slot: s,
            onAdd: () => unawaited(countPrayer(ref, s, 1)),
            onUndo: () => unawaited(countPrayer(ref, s, -1)),
            onTap: () =>
                unawaited(context.push(AppRoutes.prayerEdit(s.prayer.id))),
          ),
          gap,
        ],
        const SizedBox(height: AppSpacing.section),
        FFSectionHeader(title: tr('Progress')),
        const SizedBox(height: AppSpacing.sm),
        PrayerProgressSection(progress: progress),
        const SizedBox(height: AppSpacing.section),
        FFTipCard(
          title: tr('Prayer tip of the day'),
          tips: PrayerTips.forTradition(
            PrayerTradition.fromKey(prefs.tradition),
          ),
          day: d.now,
          icon: FontAwesomeIcons.solidLightbulb,
          colors: PrayerStyle.module,
        ),
      ],
    );
  }
}

/// "All prayers done today" under the card (not in it: the card keeps
/// showing what comes next).
class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: ff.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.solidCircleCheck,
              size: 20,
              color: ff.success,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                tr('All prayers done today'),
                style: context.text.rowTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sunday, 1 November · 20 Jumada al-Ula 1448" — wraps, never cut.
class _DateLine extends StatelessWidget {
  const _DateLine({required this.date, required this.hijri});

  final String date;
  final String? hijri;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _part(context, FontAwesomeIcons.calendarDay, date, ff.inkMuted),
        if (hijri != null)
          _part(
            context,
            FontAwesomeIcons.solidMoon,
            hijri!,
            PrayerStyle.module.inkFor(ff.brightness),
          ),
      ],
    );
  }

  static Widget _part(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: AppSpacing.xs),
      Flexible(
        child: Text(
          label,
          style: context.text.meta.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

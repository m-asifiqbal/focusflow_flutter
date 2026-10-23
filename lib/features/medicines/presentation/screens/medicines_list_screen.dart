/// ============================================================
/// MEDICINES LIST — `/library/medicines`
/// ============================================================
///
/// What: header ("Medicines" · "2 of 4 doses taken today", add + more),
/// the week strip (pick a day; doses of past days can still be logged),
/// then the day's slivers (medicine_day_slivers.dart): the hero, refill
/// banners, the dose timeline, as-needed medicines and "Your medicines".
/// Why: layout only — every write goes through medicine_flows.dart and the
/// lists are live StreamProviders, so a dose taken from a notification
/// shows up here at once. Notifications are planned by the engine from the
/// database, never from this screen.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/providers/medicines_providers.dart';
import 'package:focusflow/features/medicines/presentation/widgets/medicine_day_slivers.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class MedicinesListScreen extends ConsumerWidget {
  const MedicinesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final day = ref.watch(medicineListDayProvider);
    final async = ref.watch(medicineDayProvider(day));
    final now = ref.watch(minuteClockProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final data = async.valueOrNull;
    return MinuteTicker(
      child: FFScaffold(
        safeBottom: false,
        body: Column(
          children: [
            FFLargeHeader(
              title: tr('Medicines'),
              leading: const FFBackButton(),
              fitTitle: true,
              subtitle: _subtitle(data, now),
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                ReminderSizes.headerTop,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              actions: [
                FFRoundIconButton(
                  icon: FontAwesomeIcons.plus,
                  semanticLabel: tr('Add medicine'),
                  onPressed: () => context.push(AppRoutes.newMedicinePath),
                ),
                FFRoundIconButton(
                  icon: FontAwesomeIcons.ellipsis,
                  semanticLabel: tr('More options'),
                  onPressed: () => _showMore(context),
                ),
              ],
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (data == null || !data.isEmpty)
                    const SliverToBoxAdapter(child: _WeekCard()),
                  if (data != null)
                    ...medicineDaySlivers(
                      context,
                      day: data,
                      now: now,
                      use24h: use24h,
                    )
                  else if (async.hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(
                          AppSpacing.screen,
                        ),
                        child: FFErrorBanner(
                          message: tr('Couldn\'t load your medicines.'),
                          onRetry: () =>
                              ref.invalidate(medicineDayProvider(day)),
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: _Loading()),
                  SliverPadding(
                    padding: EdgeInsetsDirectional.only(
                      bottom:
                          bottom +
                          AppSpacing.bottomBarClearance +
                          AppSpacing.xxl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(MedicineDay? d, DateTime now) {
    if (d == null) return ' ';
    if (d.isEmpty) return tr('Your doses, on time');
    final doses = d.scheduled;
    if (doses.isEmpty) return tr('No doses this day');
    final taken = doses.where((s) => s.log?.isTaken ?? false).length;
    return DateUtilsX.isSameDay(d.day, now)
        ? tr('{taken} of {total} doses taken today', {
            'taken': taken,
            'total': doses.length,
          })
        : tr('{taken} of {total} doses taken', {
            'taken': taken,
            'total': doses.length,
          });
  }

  void _showMore(BuildContext context) {
    showFFActionSheet(
      context,
      FFActionSheetData(
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.plus,
            label: tr('Add medicine'),
            colors: MedicineStyle.colors,
            onTap: () => context.push(AppRoutes.newMedicinePath),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.solidBell,
            label: tr('Notification settings'),
            colors: ModuleStyle.tasks.colors,
            onTap: () => context.push(AppRoutes.settingsNotifications),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.boxArchive,
            label: tr('Archived medicines'),
            colors: ModuleStyle.habits.colors,
            onTap: () => context.push(AppRoutes.archive),
          ),
        ],
      ),
    );
  }
}

/// M–S strip in the medicine colour; picking a day shows its doses.
class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(medicineListDayProvider);
    final today = ref.watch(todayProvider);
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
    final accent = MedicineStyle.colors.solid;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        0,
      ),
      child: FFCard(
        radius: AppRadii.hero,
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: ReminderSizes.weekCardVertical,
        ),
        child: FFWeekStrip(
          style: FFWeekStripStyle.circle,
          days: DateUtilsX.weekDays(day, weekStart),
          selected: day,
          today: today,
          accent: accent,
          dotColor: accent.withValues(alpha: 0.55),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ReminderSizes.weekStripSide,
          ),
          onSelected: (d) {
            FFHaptics.selection(context);
            ref
                .read(selectedMedicineDayProvider.notifier)
                .select(DateUtilsX.isSameDay(d, today) ? null : d);
          },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => FFShimmer(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.screen),
      child: Column(
        children: [
          const FFSkeleton(
            height: MedicineSizes.skeletonHero,
            radius: AppRadii.hero,
          ),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: AppSpacing.cardGap),
            const FFSkeleton(
              height: MedicineSizes.skeletonRow,
              radius: AppRadii.card,
            ),
          ],
        ],
      ),
    ),
  );
}

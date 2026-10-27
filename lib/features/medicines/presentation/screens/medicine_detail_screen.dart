/// ============================================================
/// MEDICINE DETAIL — `/medicines/:id`
/// ============================================================
///
/// Back · "Medicine" · edit + more. The hero (today's ring, name, "Take
/// 8:00 PM dose" / "Skip"), three stats (on time over 30 days, streak,
/// stock), the refill banner when low, dose calendar (Week · Month · Year) and the history.
/// Everything comes from the live medicineDetailProvider (recomputed every
/// minute and on every dose write), so a dose taken from a notification
/// updates this screen at once.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/providers/medicines_providers.dart';
import 'package:focusflow/features/medicines/presentation/widgets/detail/medicine_detail_hero.dart';
import 'package:focusflow/features/medicines/presentation/widgets/detail/medicine_history_card.dart';
import 'package:focusflow/features/medicines/presentation/widgets/detail/medicine_dose_calendar_card.dart';
import 'package:focusflow/features/medicines/presentation/widgets/refill_sheet.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class MedicineDetailScreen extends ConsumerWidget {
  const MedicineDetailScreen({required this.medicineId, super.key});

  final String medicineId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.medicines);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(medicineDetailProvider(medicineId));
    final d = async.valueOrNull;
    return MinuteTicker(
      child: FFScaffold(
        body: Column(
          children: [
            FFNavHeader(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.grouped,
              ),
              leading: FFBackButton(onPressed: () => _back(context)),
              title: tr('Medicine'),
              trailing: [
                FFRoundIconButton(
                  icon: FontAwesomeIcons.pen,
                  semanticLabel: tr('Edit medicine'),
                  iconColor: context.ff.primary,
                  onPressed: d == null
                      ? null
                      : () => context.push(AppRoutes.medicineEdit(medicineId)),
                ),
                FFRoundIconButton(
                  icon: FontAwesomeIcons.ellipsis,
                  semanticLabel: tr('More options'),
                  onPressed: d == null
                      ? null
                      : () => _more(context, ref, d.medicine),
                ),
              ],
            ),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (_, _) => Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.grouped),
                  child: FFErrorBanner(
                    message: tr('Couldn\'t load this medicine.'),
                    onRetry: () =>
                        ref.invalidate(medicineDetailProvider(medicineId)),
                  ),
                ),
                data: (detail) => detail == null
                    ? FFEmptyState(
                        colors: MedicineStyle.colors,
                        icon: FontAwesomeIcons.pills,
                        title: tr('Medicine not found'),
                        body: tr('It may have been deleted.'),
                        ctaLabel: tr('Back to medicines'),
                        ctaIcon: null,
                        onCta: () => context.go(AppRoutes.medicines),
                      )
                    : _Body(detail: detail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _more(BuildContext context, WidgetRef ref, Medicine m) {
    showItemActions(
      context,
      ref,
      m.ref,
      extraActions: [
        if (m.isActive)
          FFActionItem(
            icon: FontAwesomeIcons.boxOpen,
            label: tr('Refill'),
            colors: MedicineStyle.stock,
            onTap: () {
              if (context.mounted) showRefillSheet(context, ref, m);
            },
          ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final MedicineDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final m = detail.medicine;
    final s = detail.stats;
    final colors = MedicineStyle.colors;
    final adherence = s.adherence;
    final daysLeft = MedicineSchedule.daysLeft(m);
    const gap = SizedBox(height: AppSpacing.xxxl);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.grouped,
        AppSpacing.xl,
        AppSpacing.grouped,
        AppSpacing.xxxl,
      ),
      children: [
        MedicineDetailHero(detail: detail, use24h: use24h),
        const SizedBox(height: AppSpacing.section),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FFStatTile(
                  value: adherence == null
                      ? '—'
                      : '${(adherence * 100).round()}%',
                  label: tr('On time · 30 days'),
                  colors: colors,
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: FFStatTile(
                  value: '${s.streak}',
                  label: tr('Day streak'),
                  colors: colors,
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: FFStatTile(
                  value: m.stockLeft == null
                      ? '—'
                      : MedicineWords.number(m.stockLeft!),
                  label: daysLeft == null
                      ? tr('Left')
                      : tr(
                          '{count, plural, one {Left · # day} other {Left · # days}}',
                          {'count': daysLeft},
                        ),
                  colors: MedicineStyle.stock,
                  onTap: m.isActive
                      ? () => showRefillSheet(context, ref, m)
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (m.isLow && m.isActive) ...[
          const SizedBox(height: AppSpacing.cardGap),
          MedicineRefillBanner(medicine: m),
        ],
        if (!m.isAsNeeded) ...[
          gap,
          MedicineDoseCalendarCard(medicine: m, week: s.week),
        ],
        gap,
        MedicineHistoryCard(
          history: s.history,
          now: detail.now,
          use24h: use24h,
        ),
        if (m.isActive && !m.isPaused && !m.isAsNeeded) ...[
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: TextButton.icon(
              onPressed: () => setMedicinePaused(context, ref, m, true),
              icon: const Icon(FontAwesomeIcons.pause, size: AppSpacing.md),
              label: Text(tr('Pause reminders')),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          tr(
            'FocusFlow only reminds you. Always follow your doctor\'s or pharmacist\'s instructions.',
          ),
          textAlign: TextAlign.center,
          style: context.text.caption,
        ),
      ],
    );
  }
}

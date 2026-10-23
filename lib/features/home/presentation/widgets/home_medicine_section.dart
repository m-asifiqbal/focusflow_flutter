/// ============================================================
/// HOME MEDICINE SECTION — "Medicine ……… All"
/// ============================================================
///
/// What: a card with today's progress (small ring + "2 of 4 doses taken")
/// and the next doses not logged yet (up to [HomeMedicineSection.maxRows]):
/// form icon, name, time · amount, and a TAKEN pill once a dose is due
/// (one tap, Undo in the snackbar). When everything is logged the card
/// says so. Home shows this section only to someone who has medicines
/// (home_screen.dart), so it never adds an empty card for everyone else.
/// Why: the same flows as the medicine list (medicine_flows.dart), so a
/// dose taken here updates the list, the notifications and Insights.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/providers/medicines_providers.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card_parts.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Whether the user has any active medicine (Home shows the section).
final homeHasMedicinesProvider = Provider.autoDispose<bool>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(
    medicineDayProvider(
      today,
    ).select((d) => d.valueOrNull?.medicines.isNotEmpty ?? false),
  );
});

class HomeMedicineSection extends ConsumerWidget {
  const HomeMedicineSection({super.key});

  static const int maxRows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final now = ref.watch(minuteClockProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final day = ref.watch(medicineDayProvider(today));
    final Widget body = day.when(
      skipLoadingOnReload: true,
      error: (_, _) => HomeErrorCard(
        onRetry: () => ref.invalidate(medicineDayProvider(today)),
      ),
      loading: () => const FFSkeletonList(count: 1),
      data: (d) => _Card(slots: d.scheduled, now: now, use24h: use24h),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('Medicine'),
          trailing: HomeSectionLink(
            tr('All'),
            onPressed: () => context.push(AppRoutes.medicines),
          ),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        body,
      ],
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.slots, required this.now, required this.use24h});

  final List<DoseSlot> slots;
  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final colors = MedicineStyle.colors;
    final taken = slots.where((s) => s.stateAt(now) == DoseState.taken).length;
    final open = [
      for (final s in slots)
        if (!s.stateAt(now).isLogged) s,
    ];
    final total = slots.length;
    final progress = total == 0 ? 0.0 : taken / total;
    final String headline;
    if (total == 0) {
      headline = tr('No doses today');
    } else if (open.isEmpty) {
      headline = tr('All doses logged for today');
    } else {
      headline = tr('{taken} of {total} doses taken', {
        'taken': taken,
        'total': total,
      });
    }
    return FFCard(
      onTap: () => context.push(AppRoutes.medicines),
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FFProgressRing(
                progress: progress,
                size: AppSizes.iconTileLg,
                stroke: AppSpacing.xs + 1,
                color: colors.solid,
                trackColor: colors.softFor(ff.brightness),
                child: Icon(
                  open.isEmpty && total > 0
                      ? FontAwesomeIcons.check
                      : MedicineStyle.icon(
                          open.firstOrNull?.medicine.form ??
                              slots.firstOrNull?.medicine.form ??
                              MedicineForm.tablet,
                        ),
                  size: AppSizes.tileGlyph,
                  color: colors.inkFor(ff.brightness),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion(AppMotion.normal),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    headline,
                    key: ValueKey(headline),
                    style: context.text.cardTitle,
                  ),
                ),
              ),
            ],
          ),
          for (final s in open.take(HomeMedicineSection.maxRows)) ...[
            const SizedBox(height: AppSpacing.md),
            _DoseRow(key: ValueKey(s.id), slot: s, now: now, use24h: use24h),
          ],
          if (open.length > HomeMedicineSection.maxRows) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr(
                '{count, plural, one {+ # more dose} other {+ # more doses}}',
                {'count': open.length - HomeMedicineSection.maxRows},
              ),
              style: context.text.meta,
            ),
          ],
        ],
      ),
    );
  }
}

class _DoseRow extends ConsumerWidget {
  const _DoseRow({
    required this.slot,
    required this.now,
    required this.use24h,
    super.key,
  });

  final DoseSlot slot;
  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final m = slot.medicine;
    final state = slot.stateAt(now);
    final name = m.name.trim().isEmpty ? tr('Untitled medicine') : m.name;
    final when = DateUtilsX.time(slot.at, use24h: use24h);
    return Row(
      children: [
        FFIconTile.soft(
          icon: MedicineStyle.icon(m.form),
          colors: MedicineStyle.colors,
          size: AppSizes.iconTileSm,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.rowTitle,
              ),
              Text(
                '$when · ${MedicineWords.amount(slot.quantity, m.form)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.meta.copyWith(
                  color: state.needsAction
                      ? MedicineStyle.colors.solid
                      : ff.inkFaint,
                ),
              ),
            ],
          ),
        ),
        if (state.needsAction)
          ReminderActionPill(
            label: tr('TAKEN'),
            primary: true,
            onTap: () => takeDose(context, ref, slot),
          )
        else
          Text(DateUtilsX.until(slot.at, now), style: context.text.caption),
      ],
    );
  }
}

/// ============================================================
/// MEDICINE DETAIL HERO — ring, name, meta and the next-dose buttons
/// ============================================================
///
/// The ring shows today's doses taken (it fills with a spring when a dose
/// is taken); the primary button takes the next dose of today ("Take 8:00
/// PM dose"), the secondary one skips it. An as-needed medicine logs a dose
/// instead; a paused or finished one shows why there is nothing to take.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';

class MedicineDetailHero extends ConsumerWidget {
  const MedicineDetailHero({
    required this.detail,
    this.use24h = false,
    super.key,
  });

  final MedicineDetail detail;
  final bool use24h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final text = context.text;
    final m = detail.medicine;
    final s = detail.stats;
    final colors = MedicineStyle.colors;
    final progress = s.dueToday == 0 ? 0.0 : s.takenToday / s.dueToday;
    final reduce = context.reduceMotion;
    final ended = m.hasEndedBy(detail.now);
    final next = s.nextDose;
    final meta = [
      [
        if (m.strength.trim().isNotEmpty) m.strength.trim(),
        MedicineWords.form(m.form).toLowerCase(),
      ].join(' '),
      MedicineWords.schedule(m),
      ?MedicineWords.foodNote(m.foodTiming),
    ].join(' · ');
    return Column(
      children: [
        FFProgressRing(
          progress: progress,
          size: MedicineSizes.detailRing,
          stroke: MedicineSizes.detailStroke,
          color: colors.solid,
          trackColor: colors.softFor(ff.brightness),
          duration: reduce ? Duration.zero : AppMotion.slow * 3,
          semanticLabel: m.isAsNeeded
              ? null
              : tr('{taken} of {total} doses taken today', {
                  'taken': s.takenToday,
                  'total': s.dueToday,
                }),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MedicineStyle.icon(m.form),
                size: AppSizes.heroGlyph + AppSpacing.sm,
                color: colors.inkFor(ff.brightness),
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedSwitcher(
                duration: reduce ? Duration.zero : AppMotion.normal,
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Text(
                  m.isAsNeeded ? '—' : '${s.takenToday}/${s.dueToday}',
                  key: ValueKey('${s.takenToday}/${s.dueToday}'),
                  style: text.heroNumber,
                ),
              ),
              Text(
                m.isAsNeeded ? tr('as needed') : tr('doses today'),
                style: text.meta,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          m.name.trim().isEmpty ? tr('Untitled medicine') : m.name.trim(),
          textAlign: TextAlign.center,
          style: text.largeTitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(meta, textAlign: TextAlign.center, style: text.meta),
        if (m.note.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            m.note.trim(),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (!m.isActive)
          const SizedBox.shrink()
        else if (m.isPaused)
          FFInfoBanner(
            icon: FontAwesomeIcons.pause,
            colors: colors,
            text: tr('Paused — no reminders until you resume.'),
            actionLabel: tr('Resume'),
            onAction: () => setMedicinePaused(context, ref, m, false),
          )
        else if (ended)
          FFInfoBanner(
            icon: FontAwesomeIcons.flagCheckered,
            colors: colors,
            text: tr('This course finished on {date}.', {
              'date': DateFormats.of('MMM d').format(m.endDate!),
            }),
          )
        else if (m.isAsNeeded)
          FFPrimaryButton(
            label: tr('Log a dose'),
            icon: FontAwesomeIcons.plus,
            onPressed: () => logAsNeededDose(context, ref, m),
          )
        else
          AnimatedSwitcher(
            duration: reduce ? Duration.zero : AppMotion.slow,
            child: next == null
                ? _AllDone(key: const ValueKey('done'), medicine: m)
                : Column(
                    key: ValueKey(next.id),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FFPrimaryButton(
                        label: tr('Take {time} dose', {
                          'time': DateUtilsX.time(next.at, use24h: use24h),
                        }),
                        icon: FontAwesomeIcons.check,
                        onPressed: () => takeDose(context, ref, next),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => skipDose(context, ref, next),
                          icon: const Icon(
                            FontAwesomeIcons.forward,
                            size: AppSpacing.md,
                          ),
                          label: Text(tr('Skip this dose')),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({required this.medicine, super.key});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FontAwesomeIcons.solidCircleCheck,
          color: ff.primary,
          size: AppSpacing.xl,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            tr('All doses logged for today'),
            style: context.text.rowTitle.copyWith(color: ff.primary),
          ),
        ),
      ],
    );
  }
}

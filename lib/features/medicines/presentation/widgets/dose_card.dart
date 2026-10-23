/// ============================================================
/// DOSE CARD — one dose on the medicine timeline (list + Reminders chip)
/// ============================================================
///
/// What: the time column and a pink-edged card (same parts as the
/// Reminders timeline): form icon, name, "500 mg · 1 tablet · after food",
/// and what the dose needs — SNOOZE / SKIP / TAKEN pills while it is due,
/// a popping check once taken, "Skipped" / "Missed" / "in 3 h" otherwise.
/// Tap → medicine detail (the page grows out of the card); long-press →
/// the dose sheet (take, skip, snooze, clear, open).
/// Motion: the trailing state cross-fades and scales, the pills fold away
/// (AnimatedSize) and a logged card fades to 55 % — all instant when the
/// system asks to reduce motion.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/medicines/presentation/medicine_flows.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/widgets/dose_sheet.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card_parts.dart';
import 'package:go_router/go_router.dart';

class DoseCard extends ConsumerWidget {
  const DoseCard({
    required this.slot,
    required this.now,
    this.use24h = false,
    super.key,
  });

  final DoseSlot slot;
  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = slot.stateAt(now);
    final reduce = context.reduceMotion;
    final duration = reduce ? Duration.zero : AppMotion.slow;
    final logged = state.isLogged;
    final card = _card(context, ref, state, duration);
    return Semantics(
      label: _semantics(state),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.cardGap,
        ),
        child: AnimatedOpacity(
          opacity: logged ? 0.55 : 1,
          duration: duration,
          curve: AppMotion.curve,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ReminderCard.timeColumn,
                child: ReminderTimeLabel(
                  at: slot.at,
                  use24h: use24h,
                  danger: state == DoseState.missed,
                  emphasis: state.needsAction,
                ),
              ),
              const SizedBox(width: ReminderCard.timeGap),
              Expanded(child: FFOpenOriginTracker(child: card)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    DoseState state,
    Duration duration,
  ) {
    final ff = context.ff;
    final m = slot.medicine;
    final colors = MedicineStyle.colors;
    final showPills = state.needsAction;
    final name = m.name.trim().isEmpty ? tr('Untitled medicine') : m.name;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.cardTitle.copyWith(
            decoration: state == DoseState.skipped
                ? TextDecoration.lineThrough
                : null,
            decorationColor: ff.inkMuted,
          ),
        ),
        const SizedBox(height: ReminderSizes.hairGap),
        Text(
          _meta(state),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.reminderNote.copyWith(color: ff.inkFaint),
        ),
      ],
    );
    // Name, meta and the trailing state beside the icon; the pills span
    // the whole card below (TAKEN first: the main action).
    final head = Row(
      children: [
        FFIconTile.soft(icon: MedicineStyle.icon(m.form), colors: colors),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: texts),
        const SizedBox(width: AppSpacing.sm),
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: AppMotion.curve,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: a, child: child),
          ),
          child: _trailing(context, state),
        ),
      ],
    );
    return ReminderCardFrame(
      accent: colors.solid,
      elevated: state == DoseState.due,
      bottomPadding: showPills
          ? ReminderSizes.cardBottomWithPills
          : ReminderSizes.cardVertical,
      onTap: () => context.push(AppRoutes.medicine(m.id)),
      onLongPress: () => showDoseSheet(context, ref, slot, now),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          AnimatedSize(
            duration: duration,
            curve: AppMotion.curve,
            alignment: AlignmentDirectional.topStart,
            child: showPills
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.xs,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        ReminderActionPill(
                          label: tr('TAKEN'),
                          primary: true,
                          onTap: () => takeDose(context, ref, slot),
                        ),
                        ReminderActionPill(
                          label: tr('SNOOZE {snoozeMinutes}m', {
                            'snoozeMinutes': m.snoozeMinutes > 0
                                ? m.snoozeMinutes
                                : 10,
                          }),
                          colors: colors,
                          onTap: () => snoozeDose(context, ref, slot),
                        ),
                        ReminderActionPill(
                          label: tr('SKIP'),
                          colors: ActionTints.lock,
                          onTap: () => skipDose(context, ref, slot),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context, DoseState state) {
    final ff = context.ff;
    final tag = context.text.meta;
    return switch (state) {
      DoseState.taken => KeyedSubtree(
        key: const ValueKey('taken'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ReminderDoneCheck(),
            if (slot.log?.takenAt case final at?) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                DateUtilsX.time(at, use24h: use24h),
                style: tag.copyWith(color: ff.primary),
              ),
            ],
          ],
        ),
      ),
      DoseState.skipped => Text(
        tr('Skipped'),
        key: const ValueKey('skipped'),
        style: tag.copyWith(color: ff.inkMuted),
      ),
      DoseState.missed => Text(
        tr('Missed'),
        key: const ValueKey('missed'),
        style: tag.copyWith(color: ff.danger),
      ),
      DoseState.snoozed => Icon(
        FontAwesomeIcons.solidClock,
        key: const ValueKey('snoozed'),
        size: AppSpacing.lg,
        color: MedicineStyle.colors.solid,
      ),
      DoseState.upcoming when slot.at.difference(now).inMinutes < 60 => Text(
        DateUtilsX.until(slot.at, now),
        key: const ValueKey('upcoming'),
        style: tag.copyWith(color: ff.inkFaint),
      ),
      DoseState.upcoming => const SizedBox.shrink(key: ValueKey('later')),
      DoseState.due => const SizedBox.shrink(key: ValueKey('due')),
    };
  }

  String _meta(DoseState state) {
    final m = slot.medicine;
    final line = MedicineWords.doseLine(m, slot.quantity);
    if (slot.isAsNeeded) return tr('As needed · {line}', {'line': line});
    final snooze = slot.log?.snoozedUntil;
    if (state == DoseState.snoozed && snooze != null) {
      return tr('Snoozed until {time}', {
        'time': DateUtilsX.time(snooze, use24h: use24h),
      });
    }
    return line;
  }

  String _semantics(DoseState state) {
    final name = slot.medicine.name.trim();
    final time = DateUtilsX.time(slot.at, use24h: use24h);
    final status = switch (state) {
      DoseState.taken => tr('taken'),
      DoseState.skipped => tr('skipped'),
      DoseState.snoozed => tr('snoozed'),
      DoseState.due => tr('due now'),
      DoseState.upcoming => tr('upcoming'),
      DoseState.missed => tr('missed'),
    };
    return tr('{name}, {time}, {status}', {
      'name': name,
      'time': time,
      'status': status,
    });
  }
}

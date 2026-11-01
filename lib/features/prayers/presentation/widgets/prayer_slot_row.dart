/// ============================================================
/// PRAYER SLOT ROW — one prayer of today in the Prayer tab list
/// ============================================================
///
/// What: the prayer's colour bar, name, window ("4:58 – 6:12 AM") or what
/// is next ("Starts in 1h 08m" / "Ends in 18 min"), and a state chip on
/// the end: On time / Late / Made up / Missed / Excused, or — while its
/// window is open — a "Mark prayed" chip that marks it in one tap.
/// Tap the row = the log sheet (any status, place, congregation, edit).
/// Why: the list is scanned many times a day; one line per prayer, the
/// open one outlined so it stands out without shouting.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

class PrayerSlotRow extends StatelessWidget {
  const PrayerSlotRow({
    required this.slot,
    required this.now,
    required this.use24h,
    required this.onMark,
    required this.onTap,
    super.key,
  });

  final PrayerSlot slot;
  final DateTime now;
  final bool use24h;
  final VoidCallback onMark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final p = slot.prayer;
    final state = slot.stateAt(now);
    final open =
        state == PrayerSlotState.open || state == PrayerSlotState.endingSoon;
    final w = slot.window;
    final windowText = PrayerFormat.window(w, use24h: use24h);
    final end = w.end;
    final hint = switch (state) {
      PrayerSlotState.upcoming => tr('Starts {when}', {
        'when': PrayerFormat.inTime(w.start.difference(now)),
      }),
      PrayerSlotState.endingSoon when end != null => PrayerFormat.endsIn(
        end.difference(now),
      ),
      _ => null,
    };
    final status = slot.status;
    final chipLabel = status != null
        ? status.labelFor(p.kind)
        : state == PrayerSlotState.missed
        ? tr('Not marked')
        : null;
    final chipColor = PrayerStyle.state(ff, state);
    final accent = PrayerStyle.of(p);
    return Semantics(
      button: true,
      label: [p.displayName, windowText, ?hint, ?chipLabel].join(', '),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: ff.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: open ? accent : ff.surfaceBorder,
              width: open ? 1.5 : 1,
            ),
            boxShadow: ff.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: PrayerStyle.rowAccent,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(PrayerStyle.rowAccent),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.rowTitle.copyWith(
                        fontWeight: open ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint == null ? windowText : '$windowText · $hint',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall.copyWith(
                        fontSize: 13,
                        color: state == PrayerSlotState.endingSoon
                            ? ff.warning
                            : ff.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (open && status == null)
                _MarkChip(
                  label: p.kind.isFast ? tr('Mark fasted') : tr('Mark prayed'),
                  color: accent,
                  onTap: onMark,
                )
              else if (chipLabel != null)
                _StateChip(label: chipLabel, color: chipColor)
              else
                Icon(
                  FontAwesomeIcons.chevronRight,
                  size: 13,
                  color: ff.inkFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      label,
      style: context.text.meta.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _MarkChip extends StatelessWidget {
  const _MarkChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: FFPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.minTap),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: context.text.buttonSmall.copyWith(
            color: context.ff.onGradient,
          ),
        ),
      ),
    ),
  );
}

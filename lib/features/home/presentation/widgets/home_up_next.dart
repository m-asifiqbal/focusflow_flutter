/// ============================================================
/// HOME UP NEXT — "Up Next ……… All Reminders" + the next reminder card
/// ============================================================
///
/// What: an orange-tinted card with the reminder's icon tile, title,
/// "in 25 min · 10:00 AM" and a Snooze pill (default snooze minutes from
/// settings, with Undo). For a day picked in the week strip it shows that
/// day's first pending reminder. Empty: compact empty state with an inline
/// "Add reminder".
/// Why: snoozing goes through the reminders lane's flow (same Undo and
/// notification rescheduling as the Reminders list).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/presentation/reminder_flows.dart';
import 'package:focusflow/features/reminders/presentation/reminder_style.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';

class HomeUpNextSection extends ConsumerWidget {
  const HomeUpNextSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(homeDayProvider);
    final next = ref.watch(homeUpNextProvider(day));
    final today = ref.watch(todayProvider);
    final isToday = DateUtilsX.isSameDay(day, today);
    final style = ModuleStyle.reminders;

    // A minute tick re-queries "next" (AsyncLoading with the previous
    // value): keep showing that value instead of flashing a skeleton.
    final Widget body = next.when(
      skipLoadingOnReload: true,
      error: (_, _) => HomeErrorCard(
        onRetry: () {
          ref.invalidate(homeNextReminderProvider);
          ref.invalidate(homeDayRemindersProvider(day));
        },
      ),
      loading: () => const FFSkeletonRow(),
      data: (o) => o != null
          ? _UpNextCard(occurrence: o, snooze: isToday)
          : HomeEmptyCard(
              colors: style.colors,
              icon: FontAwesomeIcons.solidBell,
              title: isToday ? 'Nothing coming up' : 'No reminders this day',
              body: 'Set a reminder so nothing slips through.',
              ctaLabel: 'Add reminder',
              onCta: () => context.push(
                AppRoutes.newReminder(
                  at: isToday ? null : DateUtilsX.atMinutes(day, 9 * 60),
                ),
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: 'Up Next',
          trailing: HomeSectionLink(
            'All Reminders',
            onPressed: () => context.push(AppRoutes.reminders),
          ),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        body,
      ],
    );
  }
}

class _UpNextCard extends ConsumerWidget {
  const _UpNextCard({required this.occurrence, required this.snooze});

  final ReminderOccurrence occurrence;

  /// Show the Snooze pill (only for today's Up Next).
  final bool snooze;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final b = ff.brightness;
    final r = occurrence.reminder;
    final module = ModuleStyle.reminders.colors;
    final tile = ReminderStyle.of(r);
    final now = ref.watch(minuteClockProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final minutes = ref.watch(
      settingsProvider.select((s) => s.defaultSnoozeMinutes),
    );
    final accent = module.inkFor(b);
    final soft = module.softFor(b);
    final meta =
        '${HomeRules.relative(occurrence.at, now)} · '
        '${DateUtilsX.time(occurrence.at, use24h: use24h)}';
    final title = r.title.trim().isEmpty ? 'Reminder' : r.title.trim();

    // Light: the module tint over white (not over the mint canvas) with a
    // hairline in the module colour, as in the mockup.
    final card = FFCard(
      color: ff.isDark
          ? soft
          : Color.alphaBlend(soft.withValues(alpha: soft.a * 0.6), ff.surface),
      shadow: false,
      border: false,
      semanticLabel: '$title, $meta',
      onTap: () => context.push(AppRoutes.reminder(r.id)),
      onLongPress: () => showItemActions(context, ref, r.ref),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg + AppSpacing.xxs,
      ),
      child: Row(
        children: [
          FFIconTile(
            icon: tile.icon,
            colors: tile.colors,
            size: HomeDimens.upNextTile,
          ),
          const SizedBox(width: AppSpacing.rowLeadingGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.cardTitle.copyWith(
                    fontSize: HomeDimens.upNextTitle,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.meta.copyWith(
                    fontSize: HomeDimens.upNextMeta,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          if (snooze) ...[
            const SizedBox(width: AppSpacing.sm),
            _SnoozePill(
              color: accent,
              minutes: minutes,
              onTap: () => snoozeReminder(context, ref, r, minutes: minutes),
            ),
          ],
        ],
      ),
    );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: module.solid.withValues(alpha: 0.12)),
      ),
      child: card,
    );
  }
}

class _SnoozePill extends StatelessWidget {
  const _SnoozePill({
    required this.color,
    required this.minutes,
    required this.onTap,
  });

  final Color color;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFPressable(
      onTap: onTap,
      semanticLabel: 'Snooze for $minutes minutes',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTap),
        child: Center(
          widthFactor: 1,
          child: Container(
            height: HomeDimens.snoozeHeight,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md + AppSpacing.xxs,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ff.isDark ? ff.surfaceMuted : ff.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              'Snooze',
              style: context.text.buttonSmall.copyWith(
                fontSize: HomeDimens.snoozeText,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

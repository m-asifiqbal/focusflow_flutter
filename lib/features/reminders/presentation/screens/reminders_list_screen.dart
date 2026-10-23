/// ============================================================
/// REMINDERS LIST — screen 12 (`/library/reminders`)
/// ============================================================
///
/// What: header ("Reminders" · "3 today · next in 25 min"), permission
/// banner, week card, chips, then the timeline: MISSED (red, with
/// Reschedule) · MORNING · AFTERNOON & EVENING · TOMORROW for the Today
/// chip, or one section per day for the other chips. The next-due card
/// carries SNOOZE 10m / MARK DONE.
/// Why: everything is live (StreamProviders over RemindersRepository) and
/// every write goes through reminder_flows.dart, so this file is layout
/// only. Notifications are scheduled by the engine from the database.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/presentation/providers/medicines_providers.dart';
import 'package:focusflow/features/medicines/presentation/widgets/medicine_day_slivers.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/reminders/presentation/providers/reminders_list_providers.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_timeline.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_timeline_item.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminders_header.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminders_list_states.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class RemindersListScreen extends ConsumerWidget {
  const RemindersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return MinuteTicker(
      child: FFScaffold(
        safeBottom: false,
        // Title + calendar/more stay fixed; week card, chips and timeline scroll.
        body: Column(
          children: [
            const RemindersToolbar(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: RemindersHeader()),
                  ..._timelineSlivers(context, ref),
                  SliverPadding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: bottom + AppSpacing.bottomBarClearance,
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

  List<Widget> _timelineSlivers(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(reminderFilterProvider);
    final day = ref.watch(reminderDayProvider);
    final now = ref.watch(minuteClockProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    if (ref.watch(reminderMedicineChipProvider)) {
      final doses = ref.watch(medicineDayProvider(day));
      final data = doses.valueOrNull;
      if (data == null) {
        return [
          SliverToBoxAdapter(
            child: doses.hasError
                ? RemindersErrorState(
                    onRetry: () => ref.invalidate(medicineDayProvider(day)),
                  )
                : const RemindersLoadingState(),
          ),
        ];
      }
      return medicineDaySlivers(
        context,
        day: data,
        now: now,
        use24h: use24h,
        showCabinet: false,
      );
    }
    final key = (day, scope);
    final async = ref.watch(remindersTimelineProvider(key));
    final timeline = async.valueOrNull;

    if (timeline == null) {
      if (async.hasError) {
        return [
          SliverToBoxAdapter(
            child: RemindersErrorState(
              onRetry: () => ref.invalidate(reminderOccurrencesProvider),
            ),
          ),
        ];
      }
      return const [SliverToBoxAdapter(child: RemindersLoadingState())];
    }

    if (timeline.isEmpty) {
      final any = ref.watch(
        reminderOccurrencesProvider(
          const RemindersQuery(scope: RemindersScope.all),
        ),
      );
      final isToday = DateUtilsX.isSameDay(day, now);
      return [
        SliverToBoxAdapter(
          child: RemindersEmptyState(
            scope: scope,
            hasAny: any.valueOrNull?.isNotEmpty ?? true,
            dayLabel: DateUtilsX.relativeDay(day, now),
            onAdd: () => context.push(
              AppRoutes.newReminder(
                at: scope == RemindersScope.today && !isToday
                    ? DateUtilsX.atMinutes(day, 9 * 60)
                    : null,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      for (final section in timeline.sections) ...[
        SliverToBoxAdapter(child: _SectionLabel(section)),
        SliverList.builder(
          itemCount: section.items.length,
          itemBuilder: (context, i) {
            final o = section.items[i];
            return ReminderTimelineItem(
              key: ValueKey('${section.key}/${o.id}/${o.at}'),
              occurrence: o,
              now: now,
              use24h: use24h,
              isMissed: section.isMissed,
              isNext: timeline.isNext(o),
            );
          },
        ),
      ],
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.section);

  final ReminderSection section;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFSectionLabel(
      section.label,
      color: section.isMissed ? ff.danger : null,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.xxl,
        AppSpacing.screen,
        AppSpacing.md,
      ),
    );
  }
}

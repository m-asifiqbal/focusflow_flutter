/// ============================================================
/// HOME SCREEN — the Today dashboard (screen 03; dark reference 37)
/// ============================================================
///
/// What: greeting header, then the sections in the order the user chose
/// in Settings › Home layout (hidden ones left out): Today's Focus, week
/// strip, Up Next, Today's Tasks, Recent Notes, Habit Tracker. Pull to
/// refresh runs a Drive sync when signed in.
/// Why: every section watches its own live provider, so each one loads,
/// fails (with Retry) and empties independently; the screen only lays
/// them out. MinuteTicker / HabitDayTicker keep "now" and the habit day
/// fresh while Home is visible.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_day_ticker.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/home/presentation/widgets/home_focus_card.dart';
import 'package:focusflow/features/home/presentation/widgets/home_habits_section.dart';
import 'package:focusflow/features/home/presentation/widgets/home_header.dart';
import 'package:focusflow/features/home/presentation/widgets/home_notes_section.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/home/presentation/widgets/home_tasks_section.dart';
import 'package:focusflow/features/home/presentation/widgets/home_up_next.dart';
import 'package:focusflow/features/home/presentation/widgets/home_week_section.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(minuteClockProvider.notifier).tick();
    if (ref.read(cloudAccountProvider) != null) {
      await ref.read(syncStatusProvider.notifier).syncNow(interactive: false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.visibleHomeSections),
    );
    const pad = EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.screen);

    Widget section(HomeSection s) => switch (s) {
      HomeSection.focus => const Padding(padding: pad, child: _FocusSection()),
      HomeSection.week => const HomeWeekSection(),
      HomeSection.upNext => const Padding(
        padding: pad,
        child: HomeUpNextSection(),
      ),
      HomeSection.tasks => const Padding(
        padding: pad,
        child: HomeTasksSection(),
      ),
      HomeSection.notes => const Padding(
        padding: pad,
        child: HomeNotesSection(),
      ),
      HomeSection.habits => const Padding(
        padding: pad,
        child: HomeHabitsSection(),
      ),
    };

    return MinuteTicker(
      child: HabitDayTicker(
        child: FFScaffold(
          safeBottom: false,
          // Greeting / search / bell stay fixed; the sections scroll.
          body: Column(
            children: [
              const HomeHeader(),
              Expanded(
                child: RefreshIndicator(
                  color: context.ff.primary,
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    padding: EdgeInsetsDirectional.only(
                      bottom: context.barClearance,
                    ),
                    children: [
                      for (final (i, s) in sections.indexed) ...[
                        SizedBox(
                          height: i == 0
                              ? AppSpacing.xxl
                              : HomeDimens.sectionGap,
                        ),
                        KeyedSubtree(key: ValueKey(s), child: section(s)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's Focus hero with its loading / error states.
class _FocusSection extends ConsumerWidget {
  const _FocusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(homeFocusProvider)
        .when(
          skipLoadingOnReload: true,
          data: (value) => HomeFocusCard(focus: value),
          error: (_, _) => HomeErrorCard(
            onRetry: () {
              ref.invalidate(homeTaskStatsProvider);
              ref.invalidate(todayHabitsProvider);
              ref.invalidate(homeDayRemindersProvider);
            },
          ),
          loading: () => const FFShimmer(
            child: FFSkeleton(
              height: HomeDimens.heroSkeleton,
              radius: AppRadii.hero,
            ),
          ),
        );
  }
}

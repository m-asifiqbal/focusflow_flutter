/// ============================================================
/// HOME WEEK SECTION — "June 2023 ……… View Monthly" + day pills
/// ============================================================
///
/// What: the month of the selected day, a "View Monthly" link to the
/// Calendar (opened on the selected day) and a horizontally scrolling
/// FFWeekStrip (this week + next, from Settings › Week starts on). Days with open tasks or pending
/// reminders get a dot; tapping a day filters Up Next and the tasks.
/// Why: the strip is full-bleed (it scrolls under the screen gutters), so
/// only the header is padded.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class HomeWeekSection extends ConsumerWidget {
  const HomeWeekSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(homeDayProvider);
    final today = ref.watch(todayProvider);
    final days = ref.watch(homeWeekDaysProvider);
    final dots = ref.watch(homeDotDaysProvider);
    // The selected pill keeps the accent's light-mode fill in dark mode too
    // (mockup 37), so white text stays readable; dots use the theme accent.
    final accent = ref.watch(settingsProvider.select((s) => s.accent));
    final ff = context.ff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: DateFormat.yMMMM().format(day),
          trailing: HomeSectionLink(
            tr('View Monthly'),
            onPressed: () => context.push(AppRoutes.calendarOn(day)),
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.screen,
          ),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        FFWeekStrip(
          days: days,
          selected: day,
          today: today,
          accent: accent.primary,
          dotColor: ff.primary.withValues(alpha: 0.7),
          hasItems: (d) => dots.contains(DateUtilsX.dayKey(d)),
          onSelected: (d) => ref
              .read(homeSelectedDayProvider.notifier)
              .select(d, today: ref.read(todayProvider)),
        ),
      ],
    );
  }
}

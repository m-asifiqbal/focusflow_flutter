/// ============================================================
/// HOME PRAYER SECTION — "Prayer ……… All": now or next
/// ============================================================
///
/// What: the prayer that is open now (or the next one) as the Prayer tab's
/// row — window, "Ends in …" / "Starts in …", one-tap "Mark prayed" — and
/// "3 of 5 done today". All opens the Prayer tab when it is shown, else
/// the Prayer page. Home shows this section only to someone who has
/// prayers (home_screen.dart).
/// Why: the moment that matters most is reachable from Home without a
/// tab switch; the same flows as the Prayer tab (prayer_flows.dart), so a
/// mark here updates the tab, the notifications and the progress.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_flows.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_slot_row.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Whether the user has any active prayer (Home shows the section).
final homeHasPrayersProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(
    prayersProvider.select((p) => p.valueOrNull?.isNotEmpty ?? false),
  ),
);

class HomePrayerSection extends ConsumerWidget {
  const HomePrayerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(prayerTodayProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final tab = ref.watch(settingsProvider.select((s) => s.prayer.showTab));
    void openAll() => tab
        ? context.go(AppRoutes.prayer)
        : unawaited(context.push(AppRoutes.prayers));
    final Widget body = today.when(
      skipLoadingOnReload: true,
      error: (_, _) =>
          HomeErrorCard(onRetry: () => ref.invalidate(prayersProvider)),
      loading: () => const FFSkeletonList(count: 1),
      data: (d) {
        final focus = d.focus;
        final prayers = d.prayers;
        final done = prayers
            .where((s) => s.stateAt(d.now) == PrayerSlotState.done)
            .length;
        final summary = Text(
          prayers.isEmpty
              ? tr('Nothing due today')
              : tr('{done} of {total} done today', {
                  'done': done,
                  'total': prayers.length,
                }),
          style: context.text.bodySmall.copyWith(color: context.ff.inkMuted),
        );
        if (focus == null) {
          return FFCard(onTap: openAll, child: summary);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrayerSlotRow(
              slot: focus,
              now: d.now,
              use24h: use24h,
              onMark: () => unawaited(markPrayer(context, ref, focus)),
              onTap: openAll,
            ),
            const SizedBox(height: HomeDimens.linkHeaderGap),
            summary,
          ],
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('Prayer'),
          trailing: HomeSectionLink(tr('All'), onPressed: openAll),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        body,
      ],
    );
  }
}

/// ============================================================
/// PRAYER JAMAAT SETTINGS — estimated jamaat for the five daily prayers
/// ============================================================
///
/// What: Settings › Prayer › JAMAAT: one row, "Estimated jamaat times"
/// (how many of the five use it), opening a choice:
///   • Fill in the rest — the daily prayers without a jamaat get the
///     estimate (your mosque's own times are kept);
///   • Use for all five — every daily prayer gets the estimate;
///   • Turn estimates off — estimated ones go back to no jamaat.
/// New estimates come with a reminder 10 minutes before (like turning a
/// jamaat on in the editor). A toast says how many changed.
/// Why: the user asked for jamaat times "in auto mode" for the five daily
/// prayers. They belong to each mosque and FocusFlow stays offline, so it
/// is a typical-time estimate (PrayerJamaatEstimate) — one tap here
/// instead of five editor visits, and each prayer can still be set to the
/// mosque's real time.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_jamaat_estimate.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

enum _Apply { fill, all, off }

class PrayerJamaatSettingsGroup extends ConsumerWidget {
  const PrayerJamaatSettingsGroup({super.key});

  /// Active daily prayers (one of the five), in the order of the day.
  static List<Prayer> dailyOf(List<Prayer> prayers) =>
      [
        for (final p in prayers)
          if (p.isActive && PrayerJamaatEstimate.roleOf(p) != null) p,
      ]..sort(
        (a, b) => PrayerJamaatEstimate.roleOf(
          a,
        )!.index.compareTo(PrayerJamaatEstimate.roleOf(b)!.index),
      );

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    List<Prayer> daily,
  ) async {
    final picked = await showOptionSheet<_Apply?>(
      context,
      title: tr('Estimated jamaat times'),
      subtitle: tr(
        'Typical mosque times worked out from each day\'s prayer times, offline. Set your mosque\'s own time in a prayer for accuracy.',
      ),
      options: [
        OptionItem(
          value: _Apply.fill,
          label: tr('Fill in the rest'),
          subtitle: tr('Keeps the times you set yourself'),
          icon: FontAwesomeIcons.wandMagicSparkles,
          colors: PrayerStyle.module,
        ),
        OptionItem(
          value: _Apply.all,
          label: tr('Use for all five'),
          subtitle: tr('Replaces the times you set'),
          icon: FontAwesomeIcons.arrowsRotate,
          colors: PrayerStyle.module,
        ),
        OptionItem(
          value: _Apply.off,
          label: tr('Turn estimates off'),
          icon: FontAwesomeIcons.xmark,
          colors: PrayerStyle.module,
        ),
      ],
      selected: null,
      accent: PrayerStyle.module.solid,
    );
    final choice = picked?.value;
    if (choice == null) return;
    final repo = ref.read(prayersRepositoryProvider);
    var changed = 0;
    for (final p in daily) {
      final j = p.jamaat;
      final Prayer? next = switch (choice) {
        _Apply.fill when j == null => _estimated(p),
        _Apply.all when !(j?.estimated ?? false) => _estimated(p),
        _Apply.off when j?.estimated ?? false => p.copyWith(clearJamaat: true),
        _ => null,
      };
      if (next == null) continue;
      await repo.save(next);
      changed++;
    }
    if (!context.mounted) return;
    showFFToast(
      context,
      changed == 0
          ? tr('Nothing to change')
          : tr(
              '{count, plural, one {# prayer updated} other {# prayers updated}}',
              {'count': changed},
            ),
      icon: FontAwesomeIcons.solidCircleCheck,
    );
  }

  static Prayer _estimated(Prayer p) => p.copyWith(
    jamaat: const PrayerJamaat.estimated(),
    remindBeforeJamaat: p.jamaat == null ? 10 : p.remindBeforeJamaat,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = dailyOf(ref.watch(prayersProvider).valueOrNull ?? const []);
    if (daily.isEmpty) return const SizedBox.shrink();
    final estimated = daily.where((p) => p.jamaat?.estimated ?? false).length;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.section),
      child: FFGroupedList(
        label: tr('Jamaat'),
        children: [
          FFListRow(
            leading: FFIconTile.soft(
              icon: FontAwesomeIcons.users,
              colors: PrayerStyle.module,
              size: AppSizes.iconTileSm,
            ),
            title: tr('Estimated jamaat times'),
            subtitle: tr('Fajr, Dhuhr, Asr, Maghrib and Isha · offline'),
            value: tr('{n} of {total}', {
              'n': estimated,
              'total': daily.length,
            }),
            chevron: true,
            onTap: () => unawaited(_choose(context, ref, daily)),
          ),
        ],
      ),
    );
  }
}

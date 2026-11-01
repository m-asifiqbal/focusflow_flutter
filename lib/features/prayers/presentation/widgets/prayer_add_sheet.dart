/// ============================================================
/// PRAYER ADD SHEET — the Prayer page's "+": tradition → what to add
/// ============================================================
///
/// What: step 1 asks for a tradition with the same tiles as "Set up
/// Prayer" (the one in use is marked); step 2 lists that tradition's
/// prayers, fasts and practices with today's window — the ones already
/// added show "Added" — plus "Create your own". Picking one opens the
/// editor pre-filled with it; nothing is saved until Save there.
/// Why: "+" used to open a blank Islamic prayer straight away; now every
/// tradition starts from its own choices, like Get started. A preset
/// keeps the user's time mode: sun-based when their prayers follow the
/// sun, fixed times when they set their own.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_tradition_grid.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Opens the sheet; a pick opens the editor with that draft.
Future<void> showPrayerAddSheet(BuildContext context) async {
  final draft = await showFFBottomSheet<Prayer>(
    context,
    builder: (_) => const PrayerAddSheet(),
  );
  if (draft != null && context.mounted) {
    unawaited(context.push(AppRoutes.newPrayer, extra: draft));
  }
}

class PrayerAddSheet extends ConsumerStatefulWidget {
  const PrayerAddSheet({super.key});

  @override
  ConsumerState<PrayerAddSheet> createState() => _PrayerAddSheetState();
}

class _PrayerAddSheetState extends ConsumerState<PrayerAddSheet> {
  PrayerTradition? _tradition;

  /// A blank prayer of [t] ("Other" kind: the user names it).
  Prayer _blank(PrayerTradition t) => Prayer.draft(
    now: ref.read(clockProvider).now(),
    tradition: t,
    kind: PrayerKind.custom,
  ).copyWith(remindBefore: 0);

  void _pick(PrayerTradition t) {
    // Nothing to suggest for your own practice: straight to the editor.
    if (t == PrayerTradition.custom) {
      Navigator.of(context).pop(_blank(t));
      return;
    }
    setState(() => _tradition = t);
  }

  @override
  Widget build(BuildContext context) {
    final t = _tradition;
    final current = ref.watch(prayerPrefsProvider).tradition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (t != null) ...[
              FFRoundIconButton(
                icon: FontAwesomeIcons.arrowLeft,
                semanticLabel: tr('Back to traditions'),
                onPressed: () => setState(() => _tradition = null),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t == null ? tr('Add to Prayer') : t.label,
                    style: context.text.title,
                  ),
                  Text(
                    t == null
                        ? tr('Choose a tradition')
                        : tr('Pick one to add, or create your own'),
                    style: context.text.bodySmall.copyWith(
                      color: context.ff.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: context.motion(AppMotion.normal),
          child: t == null
              ? PrayerTraditionGrid(
                  key: const ValueKey('traditions'),
                  current: current == null
                      ? null
                      : PrayerTradition.fromKey(current),
                  onPick: _pick,
                )
              : KeyedSubtree(key: ValueKey(t), child: _choices(context, t)),
        ),
      ],
    );
  }

  Widget _choices(BuildContext context, PrayerTradition t) {
    final now = ref.watch(clockProvider).now();
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final sunFor = ref.watch(prayerSunProvider);
    final existing = ref.watch(prayersProvider).valueOrNull ?? const [];
    final added = {for (final p in existing) p.displayName.toLowerCase()};
    // Keep the user's mode: their prayers set by hand → fixed times.
    final manual = existing.isNotEmpty && !existing.any((p) => p.usesSun);
    final presets = [
      for (final p in PrayerPresets.of(t, now))
        manual ? PrayerPresets.manual([p.draft]).first : p.draft,
    ];
    return FFGroupedList(
      children: [
        for (final d in presets)
          () {
            final isAdded = added.contains(d.displayName.toLowerCase());
            final window = PrayerSchedule.windowOn(
              d,
              now,
              sunFor(now),
              nextSun: sunFor(now.add(const Duration(days: 1))),
              prevSun: sunFor(now.subtract(const Duration(days: 1))),
            );
            return FFListRow(
              leading: FFIconTile.soft(
                icon: isAdded
                    ? FontAwesomeIcons.solidCircleCheck
                    : FontAwesomeIcons.handsPraying,
                colors: PrayerStyle.module,
                size: AppSizes.iconTileSm,
              ),
              title: d.displayName,
              subtitle: [
                d.kind.short,
                PrayerFormat.window(window, use24h: use24h),
                if (d.weekdaysMask != Prayer.everyDay)
                  PrayerFormat.weekdays(d.weekdaysMask),
                if (isAdded) tr('Added'),
              ].join(' · '),
              chevron: !isAdded,
              onTap: isAdded ? null : () => Navigator.of(context).pop(d),
              semanticLabel: isAdded
                  ? tr('{name}, added', {'name': d.displayName})
                  : d.displayName,
            );
          }(),
        FFListRow(
          leading: FFIconTile(
            icon: FontAwesomeIcons.plus,
            colors: PrayerStyle.module,
            size: AppSizes.iconTileSm,
          ),
          title: tr('Create your own'),
          subtitle: tr('Any prayer, fast or practice'),
          chevron: true,
          onTap: () => Navigator.of(context).pop(_blank(t)),
          semanticLabel: tr('Create your own'),
        ),
      ],
    );
  }
}

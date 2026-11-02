/// ============================================================
/// PRAYER SETUP — "Set up Prayer": tradition → prayers → times
/// ============================================================
///
/// What: pick a tradition (Islam, Christianity, Hinduism, Buddhism, Judaism,
/// or start from scratch); its prayers appear with the core ones ticked and
/// extras (Jumuah, Tahajjud, Ramadan fast …) unticked, each with its window;
/// choose "Automatic" (sun-based windows, asks for the precise
/// location with a reason first) or "I'll set the times myself"; Continue
/// saves them.
/// Why: a complete first day in three taps, without assuming one faith —
/// and nothing is final: every prayer stays editable.
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
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_flows.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_location_sheets.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_school_picker.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_tradition_grid.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class PrayerSetupScreen extends ConsumerStatefulWidget {
  const PrayerSetupScreen({super.key});

  @override
  ConsumerState<PrayerSetupScreen> createState() => _PrayerSetupScreenState();
}

class _PrayerSetupScreenState extends ConsumerState<PrayerSetupScreen> {
  PrayerTradition? _tradition;
  PrayerSchool? _school;
  List<PrayerPreset> _presets = const [];
  final Set<int> _picked = {};
  bool _manual = false;
  bool _saving = false;

  void _pick(PrayerTradition t) {
    // The school chosen before for this tradition stays chosen.
    final school = PrayerSchool.fromKey(
      ref.read(prayerPrefsProvider).schoolOf(t.key),
    );
    final presets = PrayerPresets.of(
      t,
      ref.read(clockProvider).now(),
      school: school,
    );
    setState(() {
      _tradition = t;
      _school = school;
      _presets = presets;
      _picked
        ..clear()
        ..addAll([
          for (var i = 0; i < presets.length; i++)
            if (presets[i].core) i,
        ]);
      // Sun-based by default only where the tradition times by the sun.
      _manual = !t.solar && !presets.any((p) => p.draft.usesSun);
    });
  }

  /// A school (or "Not sure") picked: its own starting set.
  void _setSchool(PrayerSchool? school) {
    final t = _tradition;
    if (t == null) return;
    final presets = PrayerPresets.of(
      t,
      ref.read(clockProvider).now(),
      school: school,
    );
    setState(() {
      _school = school;
      _presets = presets;
      _picked
        ..clear()
        ..addAll([
          for (var i = 0; i < presets.length; i++)
            if (presets[i].core) i,
        ]);
    });
  }

  Future<void> _continue() async {
    final t = _tradition;
    if (t == null || _saving) return;
    setState(() => _saving = true);
    final drafts = [
      for (var i = 0; i < _presets.length; i++)
        if (_picked.contains(i)) _presets[i].draft,
    ];
    final wantsPlace =
        !_manual &&
        drafts.any((d) => d.usesSun) &&
        !ref.read(prayerPrefsProvider).hasLocation;
    if (wantsPlace) await showPrayerLocationSheet(context, ref);
    if (!mounted) return;
    await savePrayerSetup(ref, t, drafts, manual: _manual, school: _school);
    if (!mounted) return;
    if (t == PrayerTradition.custom || drafts.isEmpty) {
      context.pushReplacement(AppRoutes.newPrayer);
    } else {
      context.canPop() ? context.pop() : context.go(AppRoutes.prayers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tradition;
    return FFScaffold(
      body: Column(
        children: [
          FFNavHeader(
            leading: const FFBackButton(),
            title: tr('Set up Prayer'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  tr(
                    'Pick a starting set. You can change every name, time and reminder later.',
                  ),
                  style: context.text.body.copyWith(color: context.ff.inkMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrayerTraditionGrid(selected: t, onPick: _pick),
                if (t != null && PrayerSchool.of(t).isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.section),
                  PrayerSchoolPicker(
                    tradition: t,
                    selected: _school,
                    onChanged: _setSchool,
                  ),
                ],
                if (t != null && _presets.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.section),
                  _times(context),
                  const SizedBox(height: AppSpacing.section),
                  _prayers(context),
                ],
              ],
            ),
          ),
          if (t != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              child: FFPrimaryButton(
                label: t == PrayerTradition.custom
                    ? tr('Add my first prayer')
                    : tr('Continue'),
                loading: _saving,
                onPressed: _picked.isEmpty && t != PrayerTradition.custom
                    ? null
                    : () => unawaited(_continue()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _times(BuildContext context) {
    final prefs = ref.watch(prayerPrefsProvider);
    final usesSun = _presets.any((p) => p.draft.usesSun);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(tr('Times')),
        const SizedBox(height: AppSpacing.sm),
        if (usesSun)
          FFSegmented<bool>(
            segments: [
              FFSegment(value: false, label: tr('Automatic')),
              FFSegment(value: true, label: tr('Manual')),
            ],
            value: _manual,
            onChanged: (v) => setState(() => _manual = v),
          ),
        if (usesSun && !_manual) ...[
          const SizedBox(height: AppSpacing.sm),
          FFGroupedList(
            children: [
              FFListRow(
                leading: FFIconTile.soft(
                  icon: FontAwesomeIcons.locationCrosshairs,
                  colors: PrayerStyle.module,
                  size: AppSizes.iconTileSm,
                ),
                title: prefs.hasLocation
                    ? prefs.placeLabel
                    : tr('Set your location'),
                subtitle: prefs.hasLocation
                    ? null
                    : tr('Prayer windows follow the sun where you are'),
                chevron: true,
                onTap: () => unawaited(showPrayerLocationSheet(context, ref)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _prayers(BuildContext context) {
    final ff = context.ff;
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final sunFor = ref.watch(prayerSunProvider);
    final today = ref.watch(clockProvider).now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(tr('Prayers')),
        const SizedBox(height: AppSpacing.sm),
        FFGroupedList(
          children: [
            for (var i = 0; i < _presets.length; i++)
              () {
                final draft = _manual
                    ? PrayerPresets.manual([_presets[i].draft]).first
                    : _presets[i].draft;
                final window = PrayerSchedule.windowOn(
                  draft,
                  today,
                  sunFor(today),
                  nextSun: sunFor(today.add(const Duration(days: 1))),
                  prevSun: sunFor(today.subtract(const Duration(days: 1))),
                );
                final on = _picked.contains(i);
                return FFListRow(
                  leading: Icon(
                    on
                        ? FontAwesomeIcons.solidSquareCheck
                        : FontAwesomeIcons.square,
                    size: 20,
                    color: on ? PrayerStyle.of(draft) : ff.inkFaint,
                  ),
                  title: draft.displayName,
                  subtitleLines: 3,
                  subtitle: [
                    [
                      PrayerFormat.window(window, use24h: use24h),
                      ?PrayerFormat.repeat(draft),
                      if (!_presets[i].core) tr('Optional'),
                    ].join(' · '),
                    if (_presets[i].hint.isNotEmpty) _presets[i].hint,
                  ].join('\n'),
                  onTap: () =>
                      setState(() => on ? _picked.remove(i) : _picked.add(i)),
                  semanticLabel: draft.displayName,
                );
              }(),
          ],
        ),
      ],
    );
  }
}

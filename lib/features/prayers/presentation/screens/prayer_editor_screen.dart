/// ============================================================
/// PRAYER EDITOR — new / edit a prayer, fast or practice
/// ============================================================
///
/// What: name and type (Salah, Nafl, Fasting, Dhikr, Recitation,
/// Meditation, Service, Other), the window (PrayerTimeSection), the
/// congregation's time (PrayerJamaatSection, prayers only), days,
/// reminders and priority, place, colour, goal and notes
/// (PrayerDetailsSection); an existing prayer also gets Pause, Archive and
/// Delete (the shared lifecycle actions: confirmation + Undo).
/// Why: the user's field list in one scroll; the draft lives here until
/// Save, so backing out never half-saves. A new prayer starts from what
/// was picked in the + sheet ([initial]: a tradition's prayer, or a blank
/// one of that tradition), else a blank "Other" of the tradition in use;
/// picking "Fasting" / "Dhikr" pre-fills sensible windows and reminders.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/tradition_profile.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/editor/prayer_calendar_section.dart';
import 'package:focusflow/features/prayers/presentation/widgets/editor/prayer_details_section.dart';
import 'package:focusflow/features/prayers/presentation/widgets/editor/prayer_jamaat_section.dart';
import 'package:focusflow/features/prayers/presentation/widgets/editor/prayer_time_section.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class PrayerEditorScreen extends ConsumerStatefulWidget {
  const PrayerEditorScreen({this.prayerId, this.initial, super.key});

  /// Null = a new prayer.
  final String? prayerId;

  /// The unsaved draft a new prayer starts from (the + sheet's pick).
  final Prayer? initial;

  @override
  ConsumerState<PrayerEditorScreen> createState() => _PrayerEditorScreenState();
}

class _PrayerEditorScreenState extends ConsumerState<PrayerEditorScreen> {
  Prayer? _draft;
  bool _missing = false;
  bool _saving = false;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.prayerId;
    final now = ref.read(clockProvider).now();
    Prayer? p;
    if (id == null) {
      p =
          widget.initial ??
          Prayer.draft(
            now: now,
            tradition: PrayerTradition.fromKey(
              ref.read(prayerPrefsProvider).tradition,
            ),
            kind: PrayerKind.custom,
          ).copyWith(remindBefore: 0);
    } else {
      p = await ref.read(prayersRepositoryProvider).getPrayer(id);
    }
    if (!mounted) return;
    setState(() {
      _draft = p;
      _missing = p == null;
      _name.text = p?.name ?? '';
    });
  }

  void _set(Prayer p) => setState(() => _draft = p);

  /// Picking a kind fills the defaults that kind needs.
  void _kind(PrayerKind k) {
    final d = _draft!;
    var next = d.copyWith(
      kind: k,
      // A fast or a counting practice has no congregation time.
      clearJamaat: !PrayerJamaatSection.appliesTo(k),
    );
    final profile = PrayerTraditionProfile.of(d.tradition);
    if (k.isFast && !d.kind.isFast) {
      final (start, end) = profile.fastWindow;
      next = next.copyWith(
        start: start,
        end: end,
        remindBefore: 30,
        remindBeforeEnd: 0,
      );
    }
    if (k.counts && d.targetCount == null) {
      next = next.copyWith(
        targetCount: profile.defaultGoal,
        clearRemindBefore: true,
      );
    }
    _set(next);
  }

  /// Back to where the editor was opened from — or the Prayer page when it
  /// was opened directly (a deep link has nothing to pop).
  void _close() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.prayers);

  Future<void> _save() async {
    final d = _draft;
    if (d == null || _saving) return;
    setState(() => _saving = true);
    final p = d.copyWith(name: _name.text.trim());
    await ref.read(prayersRepositoryProvider).save(p);
    if (mounted) _close();
  }

  Future<void> _archive(Prayer p, {required bool delete}) async {
    final done = delete
        ? await deleteItems(context, ref, [p.ref], title: p.displayName)
        : await archiveItems(context, ref, [p.ref], title: p.displayName);
    if (done && mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final isNew = widget.prayerId == null;
    final profile = PrayerTraditionProfile.of(
      d?.tradition ??
          PrayerTradition.fromKey(ref.read(prayerPrefsProvider).tradition),
    );
    return FFScaffold(
      body: Column(
        children: [
          FFNavHeader(
            leading: FFBackButton(label: tr('Cancel')),
            title: isNew ? profile.newTitle : profile.editTitle,
            trailing: [
              if (d != null)
                FFTextButton(
                  label: tr('Save'),
                  onPressed: _saving ? null : () => unawaited(_save()),
                ),
            ],
          ),
          Expanded(
            child: _missing
                ? Center(
                    child: FFEmptyState.compact(
                      colors: PrayerStyle.module,
                      icon: FontAwesomeIcons.handsPraying,
                      title: tr('This prayer is gone'),
                      body: tr('It was deleted, maybe on another device.'),
                    ),
                  )
                : d == null
                ? const FFLoadingView()
                : _form(context, d),
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, Prayer d) {
    final text = context.text;
    final ff = context.ff;
    final now = ref.watch(clockProvider).now();
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final sunFor = ref.watch(prayerSunProvider);
    final profile = PrayerTraditionProfile.of(d.tradition);
    // This tradition's kinds, and the one the practice has if it is another.
    final kinds = [
      ...profile.kinds,
      if (!profile.kinds.contains(d.kind)) d.kind,
    ];
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        TextField(
          controller: _name,
          autofocus: widget.prayerId == null,
          textCapitalization: TextCapitalization.sentences,
          style: text.largeTitle.copyWith(fontSize: 24),
          decoration: InputDecoration(
            hintText: profile.nameHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final k in kinds)
              FFChip(
                label: profile.kindShort(k),
                selected: d.kind == k,
                onTap: () => _kind(k),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        PrayerTimeSection(
          draft: d,
          onChanged: _set,
          sunFor: sunFor,
          today: DateUtilsX.dateOnly(now),
          use24h: use24h,
        ),
        if (PrayerJamaatSection.appliesTo(d.kind)) ...[
          const SizedBox(height: AppSpacing.section),
          PrayerJamaatSection(
            draft: d,
            onChanged: _set,
            sunFor: sunFor,
            today: DateUtilsX.dateOnly(now),
            use24h: use24h,
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        PrayerCalendarSection(
          draft: d,
          onChanged: _set,
          now: now,
          hijriAdjust: ref.watch(prayerPrefsProvider).hijriAdjust,
        ),
        const SizedBox(height: AppSpacing.sm),
        PrayerDetailsSection(draft: d, onChanged: _set, now: now),
        if (widget.prayerId != null) ...[
          const SizedBox(height: AppSpacing.section),
          FFGroupedList(
            children: [
              FFListRow.toggle(
                title: tr('Paused'),
                subtitle: tr('No reminders, not counted in progress'),
                value: d.isPaused,
                onChanged: (v) {
                  _set(d.copyWith(isPaused: v));
                  unawaited(
                    ref.read(prayersRepositoryProvider).setPaused(d.id, v),
                  );
                },
              ),
              FFListRow(
                title: tr('Archive'),
                leading: Icon(
                  FontAwesomeIcons.boxArchive,
                  size: 16,
                  color: ff.inkMuted,
                ),
                onTap: () => unawaited(_archive(d, delete: false)),
              ),
              FFListRow(
                title: tr('Delete'),
                destructive: true,
                leading: Icon(
                  FontAwesomeIcons.trashCan,
                  size: 16,
                  color: ff.danger,
                ),
                onTap: () => unawaited(_archive(d, delete: true)),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: tr('Save'),
          loading: _saving,
          onPressed: () => unawaited(_save()),
        ),
      ],
    );
  }
}

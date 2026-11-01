/// ============================================================
/// PRAYER LOG SHEET — how today's prayer went
/// ============================================================
///
/// What: tap a prayer row → this sheet: the status (on time / late / made
/// up / missed / excused — fasts read fasted / broken / …), where it was
/// prayed (its usual place, Home, the tradition's house of worship, Work,
/// or typed), "In congregation" (not for fasts and counting practices),
/// then Save; "Clear mark" when it was marked, and "Edit prayer".
/// Why: the one-tap "Mark prayed" covers the usual case; this covers the
/// rest — and lets a missed prayer be logged as made up later.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

/// What the sheet resolved to.
sealed class PrayerLogChoice {
  const PrayerLogChoice();
}

class PrayerLogSave extends PrayerLogChoice {
  const PrayerLogSave(this.status, this.place, this.congregation);

  final PrayerStatus status;
  final String? place;
  final bool congregation;
}

class PrayerLogClear extends PrayerLogChoice {
  const PrayerLogClear();
}

class PrayerLogEdit extends PrayerLogChoice {
  const PrayerLogEdit();
}

/// The tradition's house of worship (null for "your own practice").
String? placeOfWorship(PrayerTradition t) => switch (t) {
  PrayerTradition.islam => tr('Mosque'),
  PrayerTradition.christianity => tr('Church'),
  PrayerTradition.hinduism || PrayerTradition.buddhism => tr('Temple'),
  PrayerTradition.judaism => tr('Synagogue'),
  PrayerTradition.custom => null,
};

Future<PrayerLogChoice?> showPrayerLogSheet(
  BuildContext context, {
  required PrayerSlot slot,
  required DateTime now,
  required bool use24h,
}) => showFFBottomSheet<PrayerLogChoice>(
  context,
  builder: (_) => _LogSheet(slot: slot, now: now, use24h: use24h),
);

class _LogSheet extends StatefulWidget {
  const _LogSheet({
    required this.slot,
    required this.now,
    required this.use24h,
  });

  final PrayerSlot slot;
  final DateTime now;
  final bool use24h;

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  late PrayerStatus _status =
      widget.slot.status ?? widget.slot.markAt(widget.now);
  late String? _place = widget.slot.log?.place;
  late bool _congregation = widget.slot.log?.congregation ?? false;

  Prayer get _p => widget.slot.prayer;

  Future<void> _typePlace() async {
    final typed = await showTextInputSheet(
      context,
      title: tr('Where did you pray?'),
      initial: _place ?? '',
    );
    if (typed != null && mounted) setState(() => _place = typed);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final kind = _p.kind;
    final praying = !kind.isFast && !kind.counts;
    final usual = _p.place.trim();
    final places = <String>{
      if (usual.isNotEmpty) usual,
      tr('Home'),
      ?placeOfWorship(_p.tradition),
      tr('Work'),
      if (_place != null && _place!.isNotEmpty) _place!,
    }.toList();
    final selectedPlace = _place ?? (usual.isEmpty ? null : usual);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          _p.displayName,
          subtitle: PrayerFormat.window(
            widget.slot.window,
            use24h: widget.use24h,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FFGroupedList(
          children: [
            for (final s in [
              PrayerStatus.onTime,
              PrayerStatus.late,
              PrayerStatus.madeUp,
              PrayerStatus.missed,
              PrayerStatus.excused,
            ])
              FFListRow(
                title: s.labelFor(kind),
                leading: Icon(
                  s == _status
                      ? FontAwesomeIcons.solidCircleCheck
                      : FontAwesomeIcons.circle,
                  size: 18,
                  color: s == _status ? ff.primary : ff.inkFaint,
                ),
                onTap: () => setState(() => _status = s),
                semanticLabel: s.labelFor(kind),
              ),
          ],
        ),
        if (praying && _status.done) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(tr('Where'), style: text.meta.copyWith(color: ff.inkMuted)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final place in places)
                FFChip(
                  label: place,
                  icon: PrayerStyle.placeIcon(place, _p.tradition),
                  selected: place == selectedPlace,
                  onTap: () => setState(() => _place = place),
                ),
              FFChip(
                label: tr('Other…'),
                icon: FontAwesomeIcons.pen,
                onTap: _typePlace,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FFGroupedList(
            children: [
              FFListRow.toggle(
                leading: FFIconTile.soft(
                  icon: FontAwesomeIcons.users,
                  colors: PrayerStyle.module,
                  size: AppSizes.iconTileSm,
                ),
                title: tr('In congregation'),
                value: _congregation,
                onChanged: (v) => setState(() => _congregation = v),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: tr('Save'),
          onPressed: () => Navigator.of(context).pop(
            PrayerLogSave(
              _status,
              praying ? selectedPlace : null,
              praying && _congregation,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (widget.slot.status != null)
              Expanded(
                child: FFTextButton(
                  label: tr('Clear mark'),
                  icon: FontAwesomeIcons.rotateLeft,
                  onPressed: () =>
                      Navigator.of(context).pop(const PrayerLogClear()),
                ),
              ),
            Expanded(
              child: FFTextButton(
                label: tr('Edit prayer'),
                icon: FontAwesomeIcons.pen,
                onPressed: () =>
                    Navigator.of(context).pop(const PrayerLogEdit()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

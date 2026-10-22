/// ============================================================
/// ACCOUNT EDITORS — sheets behind the PROFILE rows (screen 36)
/// ============================================================
///
/// * [showDisplayNameSheet] — free text, returns the new name.
/// * [showFocusGoalSheet] — 1–50 tasks a day with − / + steppers (the
///   number drives the Home hero ring).
/// * [showTimeZoneSheet] — "Follow device" or any IANA zone (searchable).
/// Every sheet returns null when dismissed; the caller saves.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';

/// Display name editor. Returns the trimmed name (may be empty).
Future<String?> showDisplayNameSheet(BuildContext context, String initial) =>
    showFFBottomSheet<String>(
      context,
      builder: (_) => _NameSheet(initial: initial),
    );

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});

  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(tr('Display name'), style: context.text.title),
      const SizedBox(height: AppSpacing.sm),
      Text(
        tr('Used in greetings on Home. It stays on your devices.'),
        style: context.text.bodySmall,
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(hintText: tr('Your name'), counterText: ''),
      ),
      const SizedBox(height: AppSpacing.lg),
      FFPrimaryButton(label: tr('Save'), onPressed: _save),
    ],
  );
}

/// Daily focus goal editor (1–50 tasks).
Future<int?> showFocusGoalSheet(BuildContext context, int initial) =>
    showFFBottomSheet<int>(
      context,
      builder: (_) => _GoalSheet(initial: initial),
    );

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.initial});

  final int initial;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  static const _min = 1;
  static const _max = 50;
  late int _goal = widget.initial.clamp(_min, _max);

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Daily focus goal'), style: text.title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          tr(
            'How many tasks you aim to finish each day. It fills the ring on Home.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FFRoundIconButton(
              icon: FontAwesomeIcons.minus,
              semanticLabel: tr('Fewer tasks'),
              onPressed: _goal > _min ? () => setState(() => _goal--) : null,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  children: [
                    Text('$_goal', style: text.bigStat),
                    Text(
                      tr('{count, plural, one {task} other {tasks}}', {
                        'count': _goal,
                      }),
                      style: text.meta,
                    ),
                  ],
                ),
              ),
            ),
            FFRoundIconButton(
              icon: FontAwesomeIcons.plus,
              semanticLabel: tr('More tasks'),
              onPressed: _goal < _max ? () => setState(() => _goal++) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: tr('Save'),
          onPressed: () => Navigator.of(context).pop(_goal),
        ),
      ],
    );
  }
}

/// Result of the time zone picker: [zone] null = follow the device.
class TimeZonePick {
  const TimeZonePick(this.zone);

  final String? zone;
}

Future<TimeZonePick?> showTimeZoneSheet(
  BuildContext context, {
  required String? current,
  required String deviceZone,
  required List<String> zones,
}) => showFFBottomSheet<TimeZonePick>(
  context,
  builder: (_) => FFBottomSheet(
    scrollable: false,
    child: _ZoneSheet(current: current, deviceZone: deviceZone, zones: zones),
  ),
);

class _ZoneSheet extends StatefulWidget {
  const _ZoneSheet({
    required this.current,
    required this.deviceZone,
    required this.zones,
  });

  final String? current;
  final String deviceZone;
  final List<String> zones;

  @override
  State<_ZoneSheet> createState() => _ZoneSheetState();
}

class _ZoneSheetState extends State<_ZoneSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final q = _query.trim().toLowerCase().replaceAll(' ', '_');
    final matches = q.isEmpty
        ? widget.zones
        : [
            for (final z in widget.zones)
              if (z.toLowerCase().contains(q)) z,
          ];
    Widget check(bool on) => on
        ? Icon(FontAwesomeIcons.check, size: 15, color: ff.primary)
        : const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Time zone'), style: context.text.title),
        const SizedBox(height: AppSpacing.md),
        FFSearchField(
          hint: tr('Search city or region'),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: matches.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return FFListRow(
                  title: tr('Follow device'),
                  subtitle: widget.deviceZone,
                  trailing: check(widget.current == null),
                  onTap: () =>
                      Navigator.of(context).pop(const TimeZonePick(null)),
                );
              }
              final zone = matches[i - 1];
              return FFListRow(
                title: zone.replaceAll('_', ' '),
                trailing: check(widget.current == zone),
                onTap: () => Navigator.of(context).pop(TimeZonePick(zone)),
              );
            },
          ),
        ),
      ],
    );
  }
}

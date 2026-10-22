/// ============================================================
/// NOTIFICATION PICKERS — the sheets behind screen 31's rows
/// ============================================================
///
/// What:
///   * [showNotificationTimeSheet] — iOS-style time wheel in a FocusFlow
///     sheet ("Set 8:00 AM" + optional "Turn off …"). Used by the digest
///     rows and the quiet-hours pills.
///   * [showNotificationOptionSheet] — single-choice list with a check
///     (default snooze, lock screen, badge, weekly report day).
/// Both resolve to a [SheetChoice] (value null = "off"), or null when the
/// sheet is dismissed.
/// Why: the prompt asks for wheel / list sheets in FocusFlow style rather
/// than Material dialogs; the 12/24 h setting is respected.
/// ============================================================
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, TextField;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_style.dart';

/// A sheet result: a `null` future = dismissed; `SheetChoice(null)` = off.
@immutable
class SheetChoice<T> {
  const SheetChoice(this.value);

  final T? value;
}

/// Wheel time picker seeded with [minutes]. [offLabel] adds a secondary
/// "Turn off …" action that resolves to `SheetChoice(null)`.
Future<SheetChoice<int>?> showNotificationTimeSheet(
  BuildContext context, {
  required String title,
  required int minutes,
  required bool use24h,
  String? subtitle,
  String? offLabel,
}) => showFFBottomSheet<SheetChoice<int>>(
  context,
  wrap: false,
  builder: (_) => _TimeSheet(
    title: title,
    subtitle: subtitle,
    initial: minutes,
    use24h: use24h,
    offLabel: offLabel,
  ),
);

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.title,
    required this.initial,
    required this.use24h,
    this.subtitle,
    this.offLabel,
  });

  final String title;
  final String? subtitle;
  final int initial;
  final bool use24h;
  final String? offLabel;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _minutes = widget.initial;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final label = NotificationLabels.time(_minutes, use24h: widget.use24h);
    return FFBottomSheet(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FFPrimaryButton(
            label: tr('Set {label}', {'label': label}),
            icon: FontAwesomeIcons.solidClock,
            onPressed: () => Navigator.of(context).pop(SheetChoice(_minutes)),
          ),
          if (widget.offLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FFSecondaryButton(
              label: widget.offLabel!,
              icon: FontAwesomeIcons.bellSlash,
              onPressed: () =>
                  Navigator.of(context).pop(const SheetChoice<int>(null)),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetTitle(widget.title, subtitle: widget.subtitle),
          FFCard(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.sm,
            ),
            child: SizedBox(
              height: AppSizes.wheelPicker,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: ff.isDark ? Brightness.dark : Brightness.light,
                  primaryColor: ff.primary,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: context.text.title.copyWith(
                      color: ff.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: widget.use24h,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    widget.initial ~/ 60,
                    widget.initial % 60,
                  ),
                  onDateTimeChanged: (t) =>
                      setState(() => _minutes = t.hour * 60 + t.minute),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice of [showNotificationOptionSheet]; a null [value] is "off".
@immutable
class NotificationOption<T> {
  const NotificationOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T? value;
  final String label;
  final String? subtitle;
}

/// Single-choice list; resolves to the tapped option's value.
Future<SheetChoice<T>?> showNotificationOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<NotificationOption<T>> options,
  required T? selected,
  String? subtitle,
}) => showFFBottomSheet<SheetChoice<T>>(
  context,
  builder: (sheetContext) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _SheetTitle(title, subtitle: subtitle),
      FFGroupedList(
        dividerIndent: AppSpacing.lg,
        children: [
          for (final o in options)
            _OptionRow(
              option: o,
              selected: o.value == selected,
              onTap: () => Navigator.of(sheetContext).pop(SheetChoice(o.value)),
            ),
        ],
      ),
    ],
  ),
);

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final NotificationOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: FFListRow(
        title: option.label,
        subtitle: option.subtitle,
        onTap: onTap,
        trailing: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: context.reduceMotion ? Duration.zero : AppMotion.fast,
          child: Icon(
            FontAwesomeIcons.check,
            size: AppSizes.tileGlyph,
            color: context.ff.primary,
          ),
        ),
      ),
    );
  }
}

/// "Repeat until done": Off and the usual intervals, plus any number of
/// minutes of the user's own. Resolves to the interval in minutes (0 = off).
Future<SheetChoice<int>?> showRepeatIntervalSheet(
  BuildContext context, {
  required int current,
}) => showFFBottomSheet<SheetChoice<int>>(
  context,
  builder: (sheetContext) => _RepeatIntervalSheet(
    current: current,
    onPick: (m) => Navigator.of(sheetContext).pop(SheetChoice(m)),
  ),
);

class _RepeatIntervalSheet extends StatefulWidget {
  const _RepeatIntervalSheet({required this.current, required this.onPick});

  final int current;
  final ValueChanged<int> onPick;

  /// The ready-made choices (minutes); 0 = off.
  static const List<int> presets = [0, 5, 10, 15, 30, 60, 120];

  @override
  State<_RepeatIntervalSheet> createState() => _RepeatIntervalSheetState();
}

class _RepeatIntervalSheetState extends State<_RepeatIntervalSheet> {
  late final TextEditingController _custom = TextEditingController(
    text: _RepeatIntervalSheet.presets.contains(widget.current)
        ? ''
        : '${widget.current}',
  );

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  int? get _minutes {
    final m = int.tryParse(_custom.text.trim());
    if (m == null || m < 1 || m > AppSettings.maxRepeatIntervalMinutes) {
      return null;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: keyboard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetTitle(
            tr('Repeat until done'),
            subtitle: tr(
              'Show a reminder again every… until you mark it done or snooze it',
            ),
          ),
          FFGroupedList(
            dividerIndent: AppSpacing.lg,
            children: [
              for (final m in _RepeatIntervalSheet.presets)
                _OptionRow(
                  option: NotificationOption(
                    value: m,
                    label: NotificationLabels.repeat(m),
                  ),
                  selected: m == widget.current,
                  onTap: () => widget.onPick(m),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(tr('Custom interval'), style: context.text.meta),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ff.surface,
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    border: Border.all(color: ff.divider),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: TextField(
                      controller: _custom,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        final m = _minutes;
                        if (m != null) widget.onPick(m);
                      },
                      style: context.text.body.copyWith(color: ff.ink),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: tr('Minutes (1–{maxRepeatIntervalMinutes})', {
                          'maxRepeatIntervalMinutes':
                              AppSettings.maxRepeatIntervalMinutes,
                        }),
                        hintStyle: context.text.body.copyWith(
                          color: ff.inkFaint,
                        ),
                        suffixText: tr('min'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FFPrimaryButton(
                label: tr('Set'),
                expand: false,
                height: AppSizes.secondaryButton,
                onPressed: _minutes == null
                    ? null
                    : () => widget.onPick(_minutes!),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.text.sectionTitle),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(subtitle!, style: context.text.meta),
          ],
        ],
      ),
    );
  }
}

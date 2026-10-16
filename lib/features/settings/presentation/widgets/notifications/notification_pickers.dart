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
            label: 'Set $label',
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

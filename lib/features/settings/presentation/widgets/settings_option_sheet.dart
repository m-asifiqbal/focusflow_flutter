/// ============================================================
/// SETTINGS OPTION SHEET — one-call single-choice picker for sub-pages
/// ============================================================
///
/// What: [pickSetting] shows the shared single-choice sheet (the one of
/// Settings › Notifications) and returns the picked value, or null when
/// the sheet is dismissed.
/// Why: every sub-page row that opens a list of choices looks the same,
/// and callers don't repeat the SheetChoice unwrapping.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_pickers.dart';

/// A choice: [value] with its [label] and optional [subtitle].
typedef SettingOption<T> = ({T value, String label, String? subtitle});

/// Shorthand for a [SettingOption] without subtitle.
SettingOption<T> option<T>(T value, String label, [String? subtitle]) =>
    (value: value, label: label, subtitle: subtitle);

/// Shows [options]; the one equal to [selected] is checked.
Future<T?> pickSetting<T extends Object>(
  BuildContext context, {
  required String title,
  required List<SettingOption<T>> options,
  required T? selected,
  String? subtitle,
}) async {
  final c = await showNotificationOptionSheet<T>(
    context,
    title: title,
    subtitle: subtitle,
    selected: selected,
    options: [
      for (final o in options)
        NotificationOption<T>(
          value: o.value,
          label: o.label,
          subtitle: o.subtitle,
        ),
    ],
  );
  return c?.value;
}

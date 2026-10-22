/// ============================================================
/// REMINDER ALERT OPTIONS — choices of the editor's ALERT section
/// ============================================================
///
/// What: the alert sounds (stored as `Reminder.sound` keys) and the
/// default snooze lengths offered by the reminder editor (screen 13),
/// with their labels.
/// Why: one catalogue for the editor, Settings › Notifications and the
/// notification planner, so a stored key always has a readable label.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';

/// One alert sound.
typedef ReminderSound = ({String key, String label});

abstract final class ReminderAlertOptions {
  /// Sounds, default first. Unknown stored keys show capitalised. A getter
  /// so the labels follow the active language.
  static List<ReminderSound> get sounds => [
    (key: 'chime', label: tr('Chime')),
    (key: 'bell', label: tr('Bell')),
    (key: 'gentle', label: tr('Gentle')),
    (key: 'pulse', label: tr('Pulse')),
    (key: 'silent', label: tr('Silent')),
  ];

  /// Snooze lengths (minutes).
  static const List<int> snoozeMinutes = [5, 10, 15, 30, 60];

  /// "Chime" for `chime`.
  static String soundLabel(String key) {
    for (final s in sounds) {
      if (s.key == key) return s.label;
    }
    if (key.isEmpty) return sounds.first.label;
    return key[0].toUpperCase() + key.substring(1);
  }

  /// "10 min", "1 hour".
  static String snoozeLabel(int minutes) => switch (minutes) {
    final m when m >= 60 && m % 60 == 0 => tr(
      '{count, plural, one {# hour} other {# hours}}',
      {'count': m ~/ 60},
    ),
    final m => tr('{m} min', {'m': m}),
  };
}

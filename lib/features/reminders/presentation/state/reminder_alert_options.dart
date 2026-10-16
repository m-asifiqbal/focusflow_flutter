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

/// One alert sound.
typedef ReminderSound = ({String key, String label});

abstract final class ReminderAlertOptions {
  /// Sounds, default first. Unknown stored keys show capitalised.
  static const List<ReminderSound> sounds = [
    (key: 'chime', label: 'Chime'),
    (key: 'bell', label: 'Bell'),
    (key: 'gentle', label: 'Gentle'),
    (key: 'pulse', label: 'Pulse'),
    (key: 'silent', label: 'Silent'),
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
    60 => '1 hour',
    final m when m > 60 && m % 60 == 0 => '${m ~/ 60} hours',
    final m => '$m min',
  };
}

/// ============================================================
/// FOCUS SESSION — one completed focus-timer run (Insights › Focus hours)
/// ============================================================
library;

import 'package:flutter/foundation.dart';

@immutable
class FocusSession {
  const FocusSession({
    required this.id,
    this.taskId,
    required this.startedAt,
    required this.durationMinutes,
  });

  final String id;

  /// Task the session was for (null after the task is deleted forever).
  final String? taskId;
  final DateTime startedAt;
  final int durationMinutes;

  DateTime get endedAt => startedAt.add(Duration(minutes: durationMinutes));

  @override
  bool operator ==(Object other) =>
      other is FocusSession &&
      other.id == id &&
      other.taskId == taskId &&
      other.startedAt == startedAt &&
      other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(id, taskId, startedAt, durationMinutes);

  @override
  String toString() => 'FocusSession($startedAt, $durationMinutes min)';
}

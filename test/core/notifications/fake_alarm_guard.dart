/// A recording [AlarmGuard] for tests: what the engine reported, in order.
library;

import 'package:focusflow/core/notifications/alarm_guard.dart';

class GuardReport {
  const GuardReport({
    required this.enabled,
    required this.pending,
    this.nextAt,
    this.lastAt,
  });

  final bool enabled;
  final int pending;
  final DateTime? nextAt;
  final DateTime? lastAt;

  @override
  String toString() =>
      'GuardReport(enabled: $enabled, pending: $pending, '
      'nextAt: $nextAt, lastAt: $lastAt)';
}

class FakeAlarmGuard implements AlarmGuard {
  final List<GuardReport> reports = [];
  bool? running;

  GuardReport? get last => reports.isEmpty ? null : reports.last;

  @override
  Future<void> sync({
    required bool enabled,
    required int pending,
    DateTime? nextAt,
    DateTime? lastAt,
  }) async {
    reports.add(
      GuardReport(
        enabled: enabled,
        pending: pending,
        nextAt: nextAt,
        lastAt: lastAt,
      ),
    );
  }

  @override
  Future<bool?> isRunning() async => running;
}

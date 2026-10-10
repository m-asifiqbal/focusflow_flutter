/// ============================================================
/// CLOCK — injectable "now" (fake it in tests: purge job, streaks, overdue)
/// ============================================================
library;

class Clock {
  const Clock();

  DateTime now() => DateTime.now();

  /// Local calendar day (midnight) for [at] (default: now).
  DateTime today([DateTime? at]) {
    final t = at ?? now();
    return DateTime(t.year, t.month, t.day);
  }
}

/// A clock frozen at (or advanced from) a fixed instant — tests only.
class FakeClock extends Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;

  void advance(Duration by) => _now = _now.add(by);
}

/// Account activity contract — the "Days active" stat on Account &
/// profile (screen 36). Pure Dart; implemented over the database in
/// features/auth/data.
library;

abstract interface class AccountActivityRepository {
  /// Live count of distinct local days on which anything was created, a
  /// task was completed, a habit was logged or a focus session started.
  Stream<int> watchDaysActive();
}

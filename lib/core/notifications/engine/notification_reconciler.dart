/// ============================================================
/// NOTIFICATION RECONCILER — make the OS schedule equal the plan
/// ============================================================
///
/// One `reconcile()` pass:
///   1. Deliveries: ledger entries whose time has passed and that the OS no
///      longer lists were shown → one inbox entry each (createdAt = fire
///      time) and the reminder's `lastFiredAt` is stamped. They leave the
///      ledger first (saved before the inbox writes), so a pass running at
///      the same time in the other isolate cannot record them again.
///      Entries past their time that the OS still holds (a late inexact
///      alarm, the engine's own wake-up a moment early) are *due*: left
///      alone and carried over until the OS shows them — unless their
///      source no longer wants them (checked in, completed, archived,
///      switched off), then they are cancelled.
///      Entries the OS still lists but will never show are *lost*: after
///      [giveUpAfter], on a fresh process (`rearm`) after
///      [missedAfterExact] / [missedAfterInexact], or right away for an
///      exact alarm whose grant was revoked (Android drops the app's
///      alarms on revoke / force-stop, but the plugin's pending list is
///      stored data and keeps naming them, so it is not trusted then).
///      A lost reminder is recorded in the inbox and shown now as
///      "Missed" ([catchUpWindow]); a lost nudge / digest only goes to the
///      inbox.
///   2. Desired = the planner's output (empty when notifications are off or
///      the OS permission is not granted).
///   3. Cancel every OS-pending or ledger id that is neither desired nor
///      due; schedule every desired notification that is new, changed
///      (fingerprint — includes exact vs inexact, so granting / revoking
///      "Alarms & reminders" re-schedules) or missing from the OS.
///      Unchanged ones are left alone — except on a fresh process
///      (`rearm`), which renews every one of them.
///   4. Persist the new ledger (a merge, see notification_ledger.dart) and
///      set the app-icon badge.
///
/// Plain Dart over [NotificationGateway] + [LedgerStore] + repositories, so
/// it runs the same in the app, in the background action isolate and in
/// unit tests (fake gateway).
/// ============================================================
library;

import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/planning/digest_planner.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/notification_planner.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/notifications_center/domain/repository/inbox_repository.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:timezone/timezone.dart' as tz;

/// What one pass did (for tests and debug logs; no item text).
class ReconcileResult {
  const ReconcileResult({
    this.delivered = 0,
    this.scheduled = 0,
    this.cancelled = 0,
    this.pending = 0,
    this.caughtUp = 0,
    this.badge,
    this.nextFireAt,
  });

  final int delivered;
  final int scheduled;

  /// Notifications the OS never delivered (their alarm was lost) that were
  /// shown late, as "Missed", instead of being dropped.
  final int caughtUp;
  final int cancelled;

  /// Notifications in the ledger after the pass.
  final int pending;
  final int? badge;

  /// When the engine should look again: the soonest scheduled fire time
  /// (to record the delivery and roll the window forward), or
  /// [NotificationReconciler.dueRecheck] from now while due requests wait
  /// for the OS.
  final DateTime? nextFireAt;

  @override
  String toString() =>
      'Reconcile(delivered $delivered, scheduled $scheduled, '
      'cancelled $cancelled, pending $pending, caught up $caughtUp, '
      'badge $badge)';
}

class NotificationReconciler {
  NotificationReconciler({
    required this.gateway,
    required this.ledger,
    required this.inbox,
    required this.reminders,
  });

  final NotificationGateway gateway;
  final LedgerStore ledger;
  final InboxRepository inbox;
  final RemindersRepository reminders;

  /// A request the OS still lists this long after its fire time is given
  /// up: recorded in the inbox (so the user still learns about it) and
  /// cancelled, so a stale alert never pops up hours late (e.g. alarms
  /// cleared by a force-stop while the plugin still lists them).
  static const Duration giveUpAfter = Duration(hours: 6);

  /// While due requests wait for the OS, look again this often.
  static const Duration dueRecheck = Duration(minutes: 1);

  /// On a *fresh process* (see `rearm` of [reconcile]) a request the OS
  /// still lists this long after its fire time was never delivered: a
  /// delivered one-shot request leaves the plugin's list at once. Exact
  /// alarms are on time to the second; inexact ones may wait for Doze's
  /// next window.
  static const Duration missedAfterExact = Duration(minutes: 3);
  static const Duration missedAfterInexact = Duration(minutes: 20);

  /// A lost reminder is still worth showing (as "Missed") this long
  /// after its time; later it only goes to the inbox.
  static const Duration catchUpWindow = Duration(hours: 24);

  /// Runs one pass for [input]. [allowed] = OS permission granted.
  ///
  /// [rearm] = the first pass of a fresh process (app launch, background
  /// task). Android drops every alarm of a force-stopped app (swiping it
  /// away on many OEM builds does that) but the plugin's own list of
  /// pending requests lives in storage and keeps naming them, so without
  /// this the plan would look "unchanged" and those reminders would never
  /// fire again. With [rearm]:
  ///   • every planned request is handed to the OS again (same id =
  ///     replaced, so a healthy alarm is simply renewed);
  ///   • a request that is past its time yet still listed as pending was
  ///     lost, not late: it is shown now as "Missed" (reminders, within
  ///     [catchUpWindow]) instead of silently disappearing.
  Future<ReconcileResult> reconcile(
    PlannerInput input, {
    required bool allowed,
    required tz.Location location,
    bool rearm = false,
  }) async {
    final now = input.now;
    final pending = await gateway.pendingIds();
    final previous = await ledger.load();
    final exact = await _exactAllowed();
    final options = DeliveryOptions(
      lockScreen: input.settings.lockScreenVisibility,
      exact: exact,
    );

    // 1. Deliveries (shown) vs. due (past their time, OS still holds them)
    //    vs. lost (past their time and the alarm is gone).
    final kept = <LedgerEntry>[];
    final due = <LedgerEntry>[];
    final shown = <LedgerEntry>[];
    final lost = <LedgerEntry>[];
    final stale = <int>{};
    for (final e in previous) {
      if (e.fireAt.isAfter(now)) {
        kept.add(e);
      } else if (!pending.contains(e.id)) {
        shown.add(e);
      } else {
        final age = now.difference(e.fireAt);
        final neverCame =
            age >=
            (rearm
                ? (e.exact ? missedAfterExact : missedAfterInexact)
                : giveUpAfter);
        // Revoked exact alarm: the OS dropped it; the plugin still lists it.
        if (neverCame || (e.exact && !exact)) {
          lost.add(e);
          stale.add(e.id);
        } else {
          due.add(e);
        }
      }
    }
    var caughtUp = 0;
    if (shown.isNotEmpty || lost.isNotEmpty) {
      // Out of the ledger before the inbox writes (see header); a delivery
      // the other isolate already claimed is not recorded twice.
      final claimed = await ledger.claimDeliveries([
        ...shown,
        ...lost,
      ], now: now);
      for (final id in stale) {
        await gateway.cancel(id);
      }
      final lostIds = {for (final e in lost) e.deliveryKey};
      for (final e in claimed) {
        await _deliver(e);
        if (allowed && lostIds.contains(e.deliveryKey)) {
          if (await _catchUp(input, e, options)) caughtUp++;
        }
      }
    }

    // 2. Desired.
    final desired = allowed
        ? NotificationPlanner.plan(input, maxCount: input.maxScheduled)
        : const <PlannedNotification>[];
    final desiredIds = {for (final n in desired) n.id};
    final known = {for (final e in kept) e.id: e};
    // A desired request with the same id replaces a due one (rescheduled).
    final waiting = [
      for (final e in due)
        if (allowed &&
            !desiredIds.contains(e.id) &&
            NotificationPlanner.stillWanted(input, e.key))
          e,
    ];
    final waitingIds = {for (final e in waiting) e.id};

    // 3. Cancel what is no longer wanted, schedule what changed.
    var cancelled = 0;
    for (final id in {...pending.difference(stale), ...known.keys}) {
      if (desiredIds.contains(id) || waitingIds.contains(id)) continue;
      await gateway.cancel(id);
      cancelled++;
    }
    var scheduled = 0;
    final next = <LedgerEntry>[];
    for (final n in desired) {
      final entry = LedgerEntry.of(n, variant: options.variant, exact: exact);
      final old = known[n.id];
      final unchanged =
          !rearm &&
          old != null &&
          old.fingerprint == entry.fingerprint &&
          pending.contains(n.id);
      if (!unchanged) {
        try {
          await gateway.schedule(n, location, options);
          scheduled++;
        } catch (e) {
          // One bad request (e.g. OS limit) must not stop the rest.
          AppLogger.w('Scheduling ${n.category.name} #${n.id} failed: $e');
          continue;
        }
      }
      next.add(entry);
    }
    await ledger.commit(previous, [...waiting, ...next], now: now);

    // 4. Badge (now, for today); scheduled ones carry their own.
    final mode = input.settings.badgeMode;
    final badge = input.settings.notificationsEnabled && allowed
        ? DigestPlanner.badgeOn(input.tasks, input.today, mode)
        : null;
    await gateway.setBadge(badge ?? 0);

    // Wake at the next fire time, or soon while due ones wait for the OS.
    DateTime? wake = next.isEmpty ? null : next.first.fireAt;
    if (waiting.isNotEmpty) {
      final recheck = now.add(dueRecheck);
      if (wake == null || recheck.isBefore(wake)) wake = recheck;
    }
    return ReconcileResult(
      delivered: shown.length + lost.length,
      scheduled: scheduled,
      cancelled: cancelled,
      pending: next.length + waiting.length,
      caughtUp: caughtUp,
      badge: badge,
      nextFireAt: wake,
    );
  }

  /// Shows the "Missed" copy of a lost reminder [e] right now. Only for
  /// reminders / task alerts that still want to fire and were due within
  /// [catchUpWindow]; quiet hours make it silent (it still lands in the
  /// tray, it just does not wake anyone). Returns whether it was shown.
  Future<bool> _catchUp(
    PlannerInput input,
    LedgerEntry e,
    DeliveryOptions options,
  ) async {
    final now = input.now;
    if (now.difference(e.fireAt) > catchUpWindow) return false;
    final base = NotificationPlanner.missed(input, e.key, at: now);
    if (base == null) return false;
    final quiet = input.quietHours;
    final night =
        quiet != null &&
        base.category != NotificationCategory.alarm &&
        quiet.containsMinute(input.calendar.minuteOfDay(now));
    // Its own id: the lost alarm's id may already belong to the next
    // occurrence of a repeating reminder.
    final missed = base.copyWith(
      id: notificationIdForKey('missed:${e.key}'),
      sound: night ? PlannedNotification.silentSound : null,
    );
    try {
      await gateway.showNow(missed, options);
      return true;
    } catch (err) {
      AppLogger.w('Showing a missed notification failed: $err');
      return false;
    }
  }

  /// Exact alarms allowed (Android 12+ grant; always on elsewhere).
  Future<bool> _exactAllowed() async {
    try {
      return await gateway.exactAlarmPermission() !=
          ExactAlarmPermission.denied;
    } catch (e) {
      AppLogger.w('Exact alarm state unavailable: $e');
      return true;
    }
  }

  /// Forgets the ledger and cancels everything (Erase local data).
  Future<void> clearAll() async {
    for (final id in await gateway.pendingIds()) {
      await gateway.cancel(id);
    }
    await ledger.save(const []);
    await gateway.setBadge(0);
  }

  Future<void> _deliver(LedgerEntry e) async {
    if (!e.inbox) return; // a repeat of one already recorded
    try {
      await inbox.add(
        kind: e.kind,
        title: e.title,
        body: e.body,
        ref: e.ref,
        actions: e.actions,
        at: e.fireAt,
      );
      final id = e.reminderId;
      if (id != null) {
        final r = await reminders.getReminder(id);
        final last = r?.lastFiredAt;
        if (r != null && (last == null || last.isBefore(e.fireAt))) {
          await reminders.markFired(id, e.fireAt);
        }
      }
    } catch (err) {
      AppLogger.w('Recording a delivered notification failed: $err');
    }
  }
}

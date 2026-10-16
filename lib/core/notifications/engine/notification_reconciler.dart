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
///      switched off), then they are cancelled. Only after [giveUpAfter]
///      is a stuck request recorded and cancelled — or right away when it
///      was an exact alarm and exact alarms have since been revoked
///      (Android cancels the app's exact alarms on revoke, but the plugin's
///      pending list still shows them, so it is not trusted then).
///   2. Desired = the planner's output (empty when notifications are off or
///      the OS permission is not granted).
///   3. Cancel every OS-pending or ledger id that is neither desired nor
///      due; schedule every desired notification that is new, changed
///      (fingerprint — includes exact vs inexact, so granting / revoking
///      "Alarms & reminders" re-schedules) or missing from the OS.
///      Unchanged ones are left alone.
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
    this.badge,
    this.nextFireAt,
  });

  final int delivered;
  final int scheduled;
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
      'cancelled $cancelled, pending $pending, badge $badge)';
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

  /// Runs one pass for [input]. [allowed] = OS permission granted.
  Future<ReconcileResult> reconcile(
    PlannerInput input, {
    required bool allowed,
    required tz.Location location,
  }) async {
    final now = input.now;
    final pending = await gateway.pendingIds();
    final previous = await ledger.load();
    final exact = await _exactAllowed();

    // 1. Deliveries (shown) vs. due (past their time, OS still holds them).
    final kept = <LedgerEntry>[];
    final due = <LedgerEntry>[];
    final shown = <LedgerEntry>[];
    final stale = <int>{};
    for (final e in previous) {
      if (e.fireAt.isAfter(now)) {
        kept.add(e);
      } else if (!pending.contains(e.id)) {
        shown.add(e);
      } else if (e.exact && !exact) {
        // Revoked exact alarm: the OS dropped it; the plugin still lists it.
        shown.add(e);
        stale.add(e.id);
      } else if (now.difference(e.fireAt) < giveUpAfter) {
        due.add(e);
      } else {
        shown.add(e);
        stale.add(e.id);
      }
    }
    if (shown.isNotEmpty) {
      // Out of the ledger before the inbox writes (see header); a delivery
      // the other isolate already claimed is not recorded twice.
      final claimed = await ledger.claimDeliveries(shown, now: now);
      for (final id in stale) {
        await gateway.cancel(id);
      }
      for (final e in claimed) {
        await _deliver(e);
      }
    }

    // 2. Desired.
    final desired = allowed
        ? NotificationPlanner.plan(input)
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
    final options = DeliveryOptions(
      lockScreen: input.settings.lockScreenVisibility,
      exact: exact,
    );
    var scheduled = 0;
    final next = <LedgerEntry>[];
    for (final n in desired) {
      final entry = LedgerEntry.of(n, variant: options.variant, exact: exact);
      final old = known[n.id];
      final unchanged =
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
      delivered: shown.length,
      scheduled: scheduled,
      cancelled: cancelled,
      pending: next.length + waiting.length,
      badge: badge,
      nextFireAt: wake,
    );
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

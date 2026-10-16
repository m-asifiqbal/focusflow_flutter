/// ============================================================
/// INBOX REPOSITORY (contract) — Notification centre storage
/// ============================================================
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';

abstract interface class InboxRepository {
  /// Adds an entry (createdAt = [at] or now). Returns its id.
  Future<String> add({
    required InboxKind kind,
    required String title,
    String body = '',
    ItemRef? ref,
    List<String> actions = const [],
    DateTime? at,
  });

  /// Not-dismissed entries (optionally one [kind]), newest first.
  Stream<List<InboxEntry>> watch({InboxKind? kind});

  /// Unread, not-dismissed entries (bell dot / badge).
  Stream<int> watchUnreadCount();

  Future<void> markRead(String id);

  /// Marks every unread entry (optionally of one [kind]) as read.
  Future<void> markAllRead({InboxKind? kind});

  /// Swipe-to-dismiss (hidden, kept for undo until cleared).
  Future<void> dismiss(String id);

  /// Undo of [dismiss].
  Future<void> undismiss(String id);

  /// Hard-deletes entries older than [age]. Returns how many were removed.
  Future<int> clearOlderThan(Duration age);
}

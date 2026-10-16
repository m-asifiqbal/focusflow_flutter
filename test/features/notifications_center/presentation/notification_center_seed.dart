/// Seeds the inbox of mockup 27 (Wednesday 14 June 2023, 10:00): three
/// unread entries today (bank reminder, overdue digest, water nudge) and
/// three read ones earlier. Run inside `tester.runAsync`.
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

final inboxNow = DateTime(2023, 6, 14, 10);

/// Ids of the seeded items.
class InboxSeed {
  InboxSeed(this.reminderId, this.bankEntryId);
  final String reminderId;
  final String bankEntryId;
}

Future<InboxSeed> seedInboxMockup(TestHarness h) async {
  final reminders = h.read(remindersRepositoryProvider);
  final inbox = h.read(inboxRepositoryProvider);
  final reminderId = await reminders.save(
    Reminder.draft(triggerAt: inboxNow, title: 'Call the bank about card'),
  );
  final read = <String>[];
  Future<String> add(
    InboxKind kind,
    String title,
    String body,
    DateTime at, {
    ItemRef? ref,
    List<String> actions = const [],
    bool isRead = false,
  }) async {
    final id = await inbox.add(
      kind: kind,
      title: title,
      body: body,
      ref: ref,
      actions: actions,
      at: at,
    );
    if (isRead) read.add(id);
    return id;
  }

  await add(
    InboxKind.habit,
    'New badge: 30-day reader',
    'You read every day for a month',
    DateTime(2023, 6, 12, 20),
    isRead: true,
  );
  await add(
    InboxKind.sync,
    'Backup complete',
    '113 items synced to Google Drive · 2.4 MB',
    DateTime(2023, 6, 13, 9),
    isRead: true,
  );
  await add(
    InboxKind.security,
    'Weak password detected',
    'Figma password is only 8 characters',
    DateTime(2023, 6, 13, 18),
    isRead: true,
  );
  await add(
    InboxKind.habit,
    'Drink Water — 6/8',
    "2 glasses to go. You're on a 12-day streak!",
    DateTime(2023, 6, 14, 7, 45),
  );
  await add(
    InboxKind.task,
    '2 tasks are overdue',
    'Submit tax documents, Renew gym membership',
    DateTime(2023, 6, 14, 8),
    actions: const [InboxActions.reschedule, InboxActions.view],
  );
  final bank = await add(
    InboxKind.reminder,
    'Call the bank about card',
    'Due at 10:00 AM',
    inboxNow,
    ref: ItemRef(ItemType.reminder, reminderId),
    actions: const [InboxActions.done, InboxActions.snooze],
  );
  for (final id in read) {
    await inbox.markRead(id);
  }
  h.clock.set(inboxNow);
  return InboxSeed(reminderId, bank);
}

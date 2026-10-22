/// ============================================================
/// NOTIFICATION CENTER PROVIDERS — screen 27 state
/// ============================================================
///
/// What:
///   inboxFilterProvider     the selected chip (null = All)
///   inboxEntriesProvider    live inbox entries of one kind (StreamProvider)
///   inboxSectionsProvider   the same split into one group per day
///   inboxSnoozeMinutesProvider  the "Snooze 10m" length (Settings default)
/// Why: CLAUDE.md rule 5 — lists are StreamProviders over repository
/// streams, so a notification fired (or acted on) anywhere shows up here.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/notifications_center/presentation/state/inbox_sections.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The selected filter chip; null shows every kind.
class InboxFilter extends AutoDisposeNotifier<InboxKind?> {
  @override
  InboxKind? build() => null;

  void select(InboxKind? kind) => state = kind;
}

final inboxFilterProvider =
    NotifierProvider.autoDispose<InboxFilter, InboxKind?>(InboxFilter.new);

/// Not-dismissed entries of [kind] (null = all), newest first.
final inboxEntriesProvider = StreamProvider.autoDispose
    .family<List<InboxEntry>, InboxKind?>(
      (ref, kind) => ref.watch(inboxRepositoryProvider).watch(kind: kind),
    );

/// [inboxEntriesProvider] grouped by day (the labels — "Today",
/// "Yesterday" — follow the clock in the screen, so they roll over at
/// midnight without regrouping).
final inboxSectionsProvider = Provider.autoDispose
    .family<AsyncValue<InboxSections>, InboxKind?>(
      (ref, kind) =>
          ref.watch(inboxEntriesProvider(kind)).whenData(InboxSections.of),
    );

/// Snooze length of the inline "Snooze" button (Settings › Notifications).
final inboxSnoozeMinutesProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(settingsProvider.select((s) => s.defaultSnoozeMinutes)),
);

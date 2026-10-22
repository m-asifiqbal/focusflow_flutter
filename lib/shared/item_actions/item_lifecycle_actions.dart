/// ============================================================
/// ITEM LIFECYCLE ACTIONS — archive / delete / restore with Undo
/// ============================================================
///
/// The one place every screen goes through for destructive item actions,
/// so the rules from the master prompt §3 hold everywhere:
///   - every destructive action shows the Undo snackbar (5 s);
///   - delete asks for confirmation first (screen 28), offering
///     "Archive instead";
///   - "Delete forever" is confirmation-only (it cannot be undone);
///   - restoring a reminder whose time passed offers to reschedule it
///     (restore_reschedule.dart).
///
/// Works for any mix of modules (multi-select in Archive/Trash/Pinned…).
/// Call these *before* popping an editor: the snackbar is shown on the
/// app-level ScaffoldMessenger, so it stays visible after the pop.
///
/// ```dart
/// if (await deleteItems(context, ref, [note.ref])) context.pop();
/// ```
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_dialog.dart';
import 'package:focusflow/core/widgets/ff_snackbar.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/item_actions/restore_reschedule.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// What happened to the items — the verb of the snackbar message.
enum LifecycleVerb {
  archived,
  deleted,
  restored,
  deletedForever,
  pinned,
  unpinned,
}

/// "\"Shopping List\" archived" (single item with a [title]), "Note
/// archived", "3 notes archived", "3 items archived". One whole text per
/// verb and shape: word order differs between languages.
String lifecycleMessage(
  List<ItemRef> refs,
  LifecycleVerb verb, {
  String? title,
}) {
  if (refs.length == 1) {
    final t = title?.trim() ?? '';
    if (t.isNotEmpty) {
      final a = {'title': t};
      return switch (verb) {
        LifecycleVerb.archived => tr('"{title}" archived', a),
        LifecycleVerb.deleted => tr('"{title}" deleted', a),
        LifecycleVerb.restored => tr('"{title}" restored', a),
        LifecycleVerb.deletedForever => tr('"{title}" deleted forever', a),
        LifecycleVerb.pinned => tr('"{title}" pinned', a),
        LifecycleVerb.unpinned => tr('"{title}" unpinned', a),
      };
    }
    final a = {'type': refs.first.type.label};
    return switch (verb) {
      LifecycleVerb.archived => tr('{type} archived', a),
      LifecycleVerb.deleted => tr('{type} deleted', a),
      LifecycleVerb.restored => tr('{type} restored', a),
      LifecycleVerb.deletedForever => tr('{type} deleted forever', a),
      LifecycleVerb.pinned => tr('{type} pinned', a),
      LifecycleVerb.unpinned => tr('{type} unpinned', a),
    };
  }
  final types = refs.map((r) => r.type).toSet();
  final a = {
    'count': refs.length,
    'things': types.length == 1 ? types.first.nouns : tr('items'),
  };
  return switch (verb) {
    LifecycleVerb.archived => tr('{count} {things} archived', a),
    LifecycleVerb.deleted => tr('{count} {things} deleted', a),
    LifecycleVerb.restored => tr('{count} {things} restored', a),
    LifecycleVerb.deletedForever => tr('{count} {things} deleted forever', a),
    LifecycleVerb.pinned => tr('{count} {things} pinned', a),
    LifecycleVerb.unpinned => tr('{count} {things} unpinned', a),
  };
}

/// Singular / plural nouns for the delete dialog ("note"/"notes").
(String, String) _nouns(List<ItemRef> refs) {
  final types = refs.map((r) => r.type).toSet();
  if (types.length != 1) return (tr('item'), tr('items'));
  final t = types.first;
  return (t.noun, t.nouns);
}

void _undoSnack(
  BuildContext context, {
  required String message,
  required IconData icon,
  required Future<void> Function() undo,
}) {
  showUndoSnackbar(context, message: message, icon: icon, onUndo: () => undo());
}

/// Archives [refs] (hidden from lists, search and notifications; restorable
/// from Library › Archive). Returns true when something was archived.
/// [title] (single item) names it in the snackbar: "\"Shopping List\" archived".
Future<bool> archiveItems(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> refs, {
  String? title,
}) async {
  if (refs.isEmpty) return false;
  final items = ref.read(itemsRepositoryProvider);
  await items.archive(refs);
  if (!context.mounted) return true;
  _undoSnack(
    context,
    message: lifecycleMessage(refs, LifecycleVerb.archived, title: title),
    icon: FontAwesomeIcons.boxArchive,
    undo: () => items.unarchive(refs),
  );
  return true;
}

/// Asks for confirmation (screen 28), then moves [refs] to Recently
/// Deleted — or archives them when the user picks "Archive instead".
/// Returns true when the items left the list (deleted or archived).
Future<bool> deleteItems(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> refs, {
  bool offerArchive = true,
  String? title,
}) async {
  if (refs.isEmpty) return false;
  final (noun, plural) = _nouns(refs);
  final choice = await confirmDelete(
    context,
    count: refs.length,
    noun: noun,
    pluralNoun: plural,
    offerArchive: offerArchive,
  );
  if (!context.mounted) return false;
  switch (choice) {
    case DeleteChoice.cancel:
      return false;
    case DeleteChoice.archive:
      return archiveItems(context, ref, refs, title: title);
    case DeleteChoice.delete:
      final items = ref.read(itemsRepositoryProvider);
      await items.moveToTrash(refs);
      if (!context.mounted) return true;
      _undoSnack(
        context,
        message: lifecycleMessage(refs, LifecycleVerb.deleted, title: title),
        icon: FontAwesomeIcons.trashCan,
        undo: () => items.restoreFromTrash(refs),
      );
      return true;
  }
}

/// Unarchives [refs] back to their lists (Archive screen 23). Vault items
/// need the vault unlocked first.
Future<bool> restoreFromArchive(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> refs, {
  String? title,
}) async {
  if (refs.isEmpty || !await _vaultGate(context, refs)) return false;
  if (!context.mounted) return false;
  final items = ref.read(itemsRepositoryProvider);
  // Undo puts each item's original archive date back (not "now").
  final before = await _datesOf(items, refs, (s) => s.archivedAt);
  await items.unarchive(refs);
  if (!context.mounted) return true;
  _undoSnack(
    context,
    message: lifecycleMessage(refs, LifecycleVerb.restored, title: title),
    icon: FontAwesomeIcons.rotateLeft,
    undo: () async {
      for (final e in before.entries) {
        await items.archive(e.value, at: e.key);
      }
    },
  );
  // Prompt 23: a restored reminder whose time passed asks to reschedule.
  await offerRescheduleAfterRestore(context, ref, refs);
  return true;
}

/// Restores [refs] from Recently Deleted (screen 24). Vault items need the
/// vault unlocked first.
Future<bool> restoreFromTrash(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> refs, {
  String? title,
}) async {
  if (refs.isEmpty || !await _vaultGate(context, refs)) return false;
  if (!context.mounted) return false;
  final items = ref.read(itemsRepositoryProvider);
  // Undo keeps the original deletion date: the 30 days don't restart.
  final before = await _datesOf(items, refs, (s) => s.deletedAt);
  await items.restoreFromTrash(refs);
  if (!context.mounted) return true;
  _undoSnack(
    context,
    message: lifecycleMessage(refs, LifecycleVerb.restored, title: title),
    icon: FontAwesomeIcons.rotateLeft,
    undo: () async {
      for (final e in before.entries) {
        await items.moveToTrash(e.value, at: e.key);
      }
    },
  );
  // Prompt 23: a restored reminder whose time passed asks to reschedule.
  await offerRescheduleAfterRestore(context, ref, refs);
  return true;
}

/// Permanently deletes [refs] after a "Delete forever?" confirmation.
/// There is no Undo — the confirmation is the safety net.
Future<bool> deleteItemsForever(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> refs, {
  String? title,
}) async {
  if (refs.isEmpty) return false;
  final (noun, plural) = _nouns(refs);
  final choice = await confirmDelete(
    context,
    count: refs.length,
    noun: noun,
    pluralNoun: plural,
    permanent: true,
  );
  if (choice != DeleteChoice.delete) return false;
  await ref.read(itemsRepositoryProvider).deleteForever(refs);
  if (context.mounted) {
    showFFToast(
      context,
      lifecycleMessage(refs, LifecycleVerb.deletedForever, title: title),
      icon: FontAwesomeIcons.trashCan,
    );
  }
  return true;
}

/// Pins [refs] — or unpins them when every one is already pinned
/// (multi-select "Pin" / "Unpin") — with an Undo snackbar that puts each
/// item's previous pin state back. Returns true when something changed.
Future<bool> togglePinItems(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> refs,
) async {
  if (refs.isEmpty) return false;
  final items = ref.read(itemsRepositoryProvider);
  final pinned = <ItemRef>[];
  final unpinned = <ItemRef>[];
  for (final r in refs) {
    final s = await items.get(r);
    if (s == null) continue;
    (s.isPinned ? pinned : unpinned).add(r);
  }
  if (pinned.isEmpty && unpinned.isEmpty) return false;
  final pin = unpinned.isNotEmpty;
  final changed = pin ? unpinned : pinned;
  await items.setPinned(changed, pin);
  if (!context.mounted) return true;
  _undoSnack(
    context,
    message: lifecycleMessage(
      changed,
      pin ? LifecycleVerb.pinned : LifecycleVerb.unpinned,
    ),
    icon: FontAwesomeIcons.thumbtack,
    undo: () => items.setPinned(changed, !pin),
  );
  return true;
}

/// Groups [refs] by a lifecycle date of their current summary (missing
/// items and null dates are skipped).
Future<Map<DateTime, List<ItemRef>>> _datesOf(
  ItemsRepository items,
  List<ItemRef> refs,
  DateTime? Function(ItemSummary) date,
) async {
  final out = <DateTime, List<ItemRef>>{};
  for (final r in refs) {
    final s = await items.get(r);
    final d = s == null ? null : date(s);
    if (d != null) out.putIfAbsent(d, () => []).add(r);
  }
  return out;
}

Future<bool> _vaultGate(BuildContext context, List<ItemRef> refs) async {
  if (!refs.any((r) => r.type == ItemType.vault)) return true;
  return ensureVaultUnlocked(context);
}

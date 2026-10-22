/// ============================================================
/// NOTE LOCK FLOWS — lock, unlock, change PIN, remove lock (per note)
/// ============================================================
///
/// What: every locked note has its own PIN, chosen by the user when they
/// lock it (the lock icon in the editor's top bar, or "Lock with a PIN" in
/// the note's long-press / More actions):
///   * [lockNoteWithPin]  — Set + Confirm PIN, then the note is locked.
///   * [verifyNotePin]    — asks for the note's PIN (true = open).
///   * [changeNotePin]    — verify, then choose a new PIN.
///   * [removeNoteLock]   — verify, then the note is a normal note again.
///   * [showNoteLockOptions] — the editor icon of a locked note: Change /
///     Remove.
/// A note locked before notes had their own PIN (no verifier stored) still
/// opens with the Vault PIN — [verifyNotePin] falls back to
/// `ensureVaultUnlocked` — and "Change note PIN" moves it to its own PIN.
/// Why: CLAUDE.md rule 5 — the sheet only collects digits; hashing and the
/// write live in the service / repository. PINs are never logged or stored.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/providers/note_lock_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_pin_sheet.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Asks for the PIN of [note]; true when it was entered correctly (or the
/// note is not locked). [title] / [subtitle] tailor the sheet's text.
Future<bool> verifyNotePin(
  BuildContext context,
  WidgetRef ref,
  Note note, {
  String? title,
  String? subtitle,
}) async {
  if (!note.isLocked) return true;
  final verifier = await ref
      .read(notesRepositoryProvider)
      .lockVerifier(note.id);
  if (!context.mounted) return false;
  // Locked before notes had their own PIN: the Vault PIN still opens it.
  if (verifier == null) return ensureVaultUnlocked(context);
  final service = ref.read(notePinServiceProvider);
  final pin = await showNotePinSheet(
    context,
    mode: NotePinMode.verify,
    title: title,
    subtitle: subtitle,
    guardKey: note.id,
    verify: (pin) => service.verify(pin, verifier),
  );
  return pin != null;
}

/// Lets the user choose a PIN for [note] and locks it with it. True when the
/// note is locked afterwards.
Future<bool> lockNoteWithPin(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final pin = await showNotePinSheet(context, mode: NotePinMode.create);
  if (pin == null || !context.mounted) return false;
  final verifier = await ref.read(notePinServiceProvider).createVerifier(pin);
  await ref.read(notesRepositoryProvider).lockWithPin(note.id, verifier);
  if (!context.mounted) return true;
  showFFToast(
    context,
    tr('Note locked with its own PIN'),
    icon: FontAwesomeIcons.lock,
  );
  return true;
}

/// Verify the current PIN, then choose a new one.
Future<void> changeNotePin(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  if (!await verifyNotePin(
    context,
    ref,
    note,
    title: tr('Enter current PIN'),
    subtitle: tr('To change the PIN of this note.'),
  )) {
    return;
  }
  if (!context.mounted) return;
  final pin = await showNotePinSheet(
    context,
    mode: NotePinMode.create,
    title: tr('Set a new PIN'),
  );
  if (pin == null || !context.mounted) return;
  final verifier = await ref.read(notePinServiceProvider).createVerifier(pin);
  await ref.read(notesRepositoryProvider).lockWithPin(note.id, verifier);
  if (!context.mounted) return;
  showFFToast(context, tr('Note PIN changed'), icon: FontAwesomeIcons.lock);
}

/// Verify the PIN, then unlock the note for good.
Future<void> removeNoteLock(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  if (!await verifyNotePin(
    context,
    ref,
    note,
    title: tr('Enter PIN to remove the lock'),
    subtitle: tr('The note will open without a PIN.'),
  )) {
    return;
  }
  await ref.read(notesRepositoryProvider).setLocked(note.id, false);
  if (!context.mounted) return;
  showFFToast(
    context,
    tr('Note lock removed'),
    icon: FontAwesomeIcons.lockOpen,
  );
}

/// The editor's lock icon on a locked note: Change PIN · Remove lock.
Future<void> showNoteLockOptions(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  void Function()? picked;
  await showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: tr('Note lock'),
        icon: FontAwesomeIcons.lock,
        colors: ActionTints.lock,
        meta: note.displayTitle,
      ),
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.lock,
          label: tr('Change note PIN'),
          colors: ActionTints.lock,
          onTap: () =>
              picked = () => unawaited(changeNotePin(context, ref, note)),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.lockOpen,
          label: tr('Remove note lock'),
          colors: ActionTints.lock,
          onTap: () =>
              picked = () => unawaited(removeNoteLock(context, ref, note)),
        ),
      ],
    ),
  );
  if (context.mounted) picked?.call();
}

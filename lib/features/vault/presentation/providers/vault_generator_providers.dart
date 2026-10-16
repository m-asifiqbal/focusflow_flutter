/// ============================================================
/// VAULT GENERATOR PROVIDERS — "Recently generated" (screen 21)
/// ============================================================
///
/// [vaultGeneratorHistoryProvider] streams the last 10 generated values
/// from the repository (stored sealed with the vault key) and opens them
/// in memory with the session key; while locked it yields nothing.
/// Entries that cannot be opened (e.g. a key from before a wipe) are
/// skipped.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// One decrypted history entry.
@immutable
class GeneratorHistoryEntry {
  const GeneratorHistoryEntry({
    required this.id,
    required this.value,
    required this.mode,
    required this.createdAt,
  });

  final String id;
  final String value;

  /// `password` · `passphrase` · `pin`.
  final String mode;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is GeneratorHistoryEntry &&
      other.id == id &&
      other.value == value &&
      other.mode == mode &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, value, mode, createdAt);

  @override
  String toString() => 'GeneratorHistoryEntry($id, <redacted>)';
}

/// Newest first, at most 10; empty while the vault is locked.
final vaultGeneratorHistoryProvider =
    StreamProvider.autoDispose<List<GeneratorHistoryEntry>>((ref) {
      final key = ref.watch(vaultSessionProvider.select((s) => s.key));
      if (key == null || key.isDestroyed) return Stream.value(const []);
      return ref
          .watch(vaultRepositoryProvider)
          .watchGeneratorHistory()
          .asyncMap((rows) async {
            final out = <GeneratorHistoryEntry>[];
            for (final r in rows) {
              if (key.isDestroyed) return const <GeneratorHistoryEntry>[];
              try {
                final value = await VaultCipher.openString(
                  key.secretKey,
                  r.encryptedValue,
                  aad: VaultAad.generator,
                );
                out.add(
                  GeneratorHistoryEntry(
                    id: r.id,
                    value: value,
                    mode: r.mode,
                    createdAt: r.createdAt,
                  ),
                );
              } on Object {
                // Sealed with another key — not shown.
              }
            }
            return out;
          });
    });

/// ============================================================
/// VAULT EDITOR CONTROLLER — `vaultEditorProvider(args)` (screen 20)
/// ============================================================
///
/// Loads the item (decrypting its payload with the open session key) or
/// starts a blank one, applies every edit in memory and saves through
/// [VaultItemService] (seal + strength + fingerprint + password history).
/// Watches the session key: when the vault locks the draft is dropped and
/// the editor shows its locked state. Every edit counts as vault activity
/// (auto-lock timer). Nothing here logs.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_generator_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_editor_state.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

class VaultEditorController
    extends AutoDisposeFamilyAsyncNotifier<VaultEditorState, VaultEditorArgs> {
  @override
  Future<VaultEditorState> build(VaultEditorArgs arg) async {
    final key = ref.watch(vaultSessionProvider.select((s) => s.key));
    if (key == null || key.isDestroyed) throw const VaultLockedException();
    final id = arg.id;
    if (id == null) {
      // "Save to new vault item" from the Generator parks its value here.
      // Taken after a microtask: a provider may not modify another one
      // during the synchronous part of its build.
      await Future<void>.value();
      final generated = ref.read(vaultEditorPrefillProvider.notifier).take();
      return VaultEditorState(
        type: arg.type,
        payload: generated == null
            ? VaultPayload.empty
            : VaultPayload.empty.copyWith(password: generated),
        dirty: generated != null,
      );
    }
    final record = await ref.read(vaultRepositoryProvider).getItem(id);
    if (record == null || record.isDeleted) throw const VaultItemNotFound();
    final VaultPayload payload;
    try {
      payload = await VaultPayloadCodec.open(
        key,
        record.encryptedPayload,
        itemId: record.id,
      );
    } on Object {
      throw const VaultItemUndecryptable();
    }
    return VaultEditorState(
      original: record,
      previous: payload,
      type: record.type,
      title: record.title,
      iconKey: record.iconKey,
      colorHex: record.colorHex,
      folderId: record.folderId,
      tags: [for (final t in record.tags) t.name],
      isFavorite: record.isFavorite,
      expiryDays: record.expiryDays,
      payload: payload,
    );
  }

  VaultEditorState? get _s => state.valueOrNull;

  void _set(VaultEditorState Function(VaultEditorState s) f) {
    final s = _s;
    if (s == null || s.saving) return;
    ref.read(vaultSessionProvider.notifier).touch();
    state = AsyncData(f(s).copyWith(dirty: true));
  }

  void _payload(VaultPayload Function(VaultPayload p) f) =>
      _set((s) => s.copyWith(payload: f(s.payload)));

  void setType(VaultItemType type) => _set((s) => s.copyWith(type: type));

  void setTitle(String v) =>
      _set((s) => s.copyWith(title: v, clearTitleError: v.trim().isNotEmpty));

  /// Brand key (null = automatic) and letter-avatar colour.
  void setIcon(String? iconKey, {String? colorHex}) => _set(
    (s) => s.copyWith(
      iconKey: iconKey,
      clearIcon: iconKey == null,
      colorHex: colorHex,
      clearColor: colorHex == null,
    ),
  );

  void setUsername(String v) => _payload((p) => p.copyWith(username: v));
  void setPassword(String v) => _payload((p) => p.copyWith(password: v));
  void setUrl(String v) => _payload((p) => p.copyWith(url: v));
  void setNotes(String v) => _payload((p) => p.copyWith(notes: v));
  void setCardholder(String v) => _payload((p) => p.copyWith(cardholder: v));
  void setCardNumber(String v) => _payload((p) => p.copyWith(cardNumber: v));
  void setCardExpiry(String v) => _payload((p) => p.copyWith(cardExpiry: v));
  void setCardCvv(String v) => _payload((p) => p.copyWith(cardCvv: v));
  void setCardPin(String v) => _payload((p) => p.copyWith(cardPin: v));
  void setWifiSsid(String v) => _payload((p) => p.copyWith(wifiSsid: v));
  void setWifiSecurity(String v) =>
      _payload((p) => p.copyWith(wifiSecurity: v));

  /// 2FA secret: a Base32 key or an `otpauth://` URI (empty clears it).
  /// A scanned URI with an issuer also fills an empty title.
  void setTotp(String v) {
    final value = v.trim();
    _set((s) {
      final issuer = TotpConfig.parse(value)?.issuer;
      return s.copyWith(
        payload: value.isEmpty
            ? s.payload.copyWith(clearTotp: true)
            : s.payload.copyWith(totpSecret: value),
        title: s.title.trim().isEmpty && issuer != null && issuer.isNotEmpty
            ? issuer
            : null,
      );
    });
  }

  void setFolder(String? folderId) => _set(
    (s) => s.copyWith(folderId: folderId, clearFolder: folderId == null),
  );

  void setTags(List<String> tags) => _set(
    (s) => s.copyWith(
      tags: {
        for (final t in tags)
          if (t.trim().isNotEmpty) t.trim().replaceFirst(RegExp('^#+'), ''),
      }.toList(),
    ),
  );

  void setFavorite(bool v) => _set((s) => s.copyWith(isFavorite: v));

  /// Days (null = off).
  void setExpiry(int? days) =>
      _set((s) => s.copyWith(expiryDays: days, clearExpiry: days == null));

  void addCustomField(VaultCustomField f) =>
      _payload((p) => p.copyWith(customFields: [...p.customFields, f]));

  void updateCustomField(int index, VaultCustomField f) => _payload(
    (p) => p.copyWith(
      customFields: [
        for (var i = 0; i < p.customFields.length; i++)
          i == index ? f : p.customFields[i],
      ],
    ),
  );

  void removeCustomField(int index) => _payload(
    (p) => p.copyWith(customFields: [...p.customFields]..removeAt(index)),
  );

  /// Encrypts and stores the item. Returns its id, or null when the title
  /// is missing (sets [VaultEditorState.titleError]).
  /// Throws [VaultLockedException] when the vault locked meanwhile.
  Future<String?> save() async {
    final s = _s;
    if (s == null || s.saving) return null;
    if (s.title.trim().isEmpty) {
      state = AsyncData(s.copyWith(titleError: 'Add a title'));
      return null;
    }
    final key = ref.read(vaultSessionProvider).requireKey();
    state = AsyncData(s.copyWith(saving: true));
    try {
      final id = await ref
          .read(vaultItemServiceProvider)
          .save(
            key: key,
            draft: s.draft,
            payload: s.payload,
            existing: s.original,
            previous: s.previous,
          );
      final now = _s;
      if (now != null) {
        state = AsyncData(now.copyWith(saving: false, dirty: false));
      }
      return id;
    } on Object {
      final now = _s;
      if (now != null) state = AsyncData(now.copyWith(saving: false));
      rethrow;
    }
  }
}

final vaultEditorProvider = AsyncNotifierProvider.autoDispose
    .family<VaultEditorController, VaultEditorState, VaultEditorArgs>(
      VaultEditorController.new,
    );

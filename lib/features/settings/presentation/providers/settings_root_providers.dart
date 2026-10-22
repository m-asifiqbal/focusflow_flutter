/// ============================================================
/// SETTINGS ROOT PROVIDERS — live values behind screen 30's rows
/// ============================================================
///
/// What: the non-settings data the Settings root shows next to its rows
/// (storage size, app version, the vault's biometric label) and the search
/// query + results. Item counts (pinned, tags & folders, archive, trash)
/// come from the Library's live [libraryCountsProvider].
/// Why: keeps platform calls (package info, file sizes, local_auth) out of
/// the widgets, and lets tests override each one.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/settings/data/storage_repository_impl.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';
import 'package:focusflow/features/settings/domain/repository/storage_repository.dart';
import 'package:focusflow/features/settings/domain/services/settings_index.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => FileStorageRepository(),
);

/// On-device footprint; refresh with `ref.invalidate(storageUsageProvider)`.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>(
  (ref) => ref.watch(storageRepositoryProvider).measure(),
);

/// "v1.0.0 (24)" from the platform build.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber.isEmpty ? '' : ' (${info.buildNumber})';
  return 'v${info.version}$build';
});

/// The vault unlock method shown on "Vault security": the device's
/// biometric name when biometrics are on, otherwise "PIN only".
final vaultUnlockLabelProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final on = ref.watch(settingsProvider.select((s) => s.vaultBiometrics));
  // The label is translated: recompute it when the language changes.
  ref.watch(settingsProvider.select((s) => s.languageCode));
  if (!on) return tr('PIN only');
  final auth = ref.watch(biometricAuthProvider);
  final kind = await auth.kind();
  return biometricLabel(kind, defaultTargetPlatform);
});

/// "Face ID" on iOS, "Face unlock" on Android, etc.
String biometricLabel(BiometricKind kind, TargetPlatform platform) {
  final ios = platform == TargetPlatform.iOS;
  return switch (kind) {
    BiometricKind.face => ios ? tr('Face ID') : tr('Face unlock'),
    BiometricKind.fingerprint => ios ? tr('Touch ID') : tr('Fingerprint'),
    BiometricKind.generic => tr('Biometrics'),
    BiometricKind.none => tr('PIN only'),
  };
}

/// Text in the "Search settings…" field.
class SettingsQueryController extends AutoDisposeNotifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;

  void clear() => state = '';
}

final settingsQueryProvider =
    NotifierProvider.autoDispose<SettingsQueryController, String>(
      SettingsQueryController.new,
    );

/// Index rows matching the query (empty when the query is blank). The index
/// titles are translated, so the result is rebuilt when the language changes.
final settingsSearchResultsProvider = Provider.autoDispose<List<SettingsEntry>>(
  (ref) {
    ref.watch(settingsProvider.select((s) => s.languageCode));
    return searchSettings(SettingsIndex.all, ref.watch(settingsQueryProvider));
  },
);

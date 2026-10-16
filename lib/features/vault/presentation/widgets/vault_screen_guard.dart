/// ============================================================
/// VAULT SCREEN GUARD — screenshot blocking while a vault screen is shown
/// ============================================================
///
/// Turns ScreenProtection on while mounted and Settings › Vault security ›
/// Block screenshots is on (default), follows the setting live, and turns
/// it off again when the vault screen goes away.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/vault/data/datasource/screen_protection.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class VaultScreenGuard extends ConsumerStatefulWidget {
  const VaultScreenGuard({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<VaultScreenGuard> createState() => _VaultScreenGuardState();
}

class _VaultScreenGuardState extends ConsumerState<VaultScreenGuard> {
  // Read eagerly: dispose() may be the first use, when ref is gone.
  late final ScreenProtection _protection;
  bool _on = false;

  /// Guards currently blocking (list + pushed detail + editor are
  /// mounted together): protection is only lifted when the last one goes.
  static int _active = 0;

  void _apply(bool block) {
    if (block == _on) return;
    _on = block;
    _active += block ? 1 : -1;
    if (block && _active == 1) unawaited(_protection.enable());
    if (!block && _active == 0) unawaited(_protection.disable());
  }

  @override
  void initState() {
    super.initState();
    _protection = ref.read(screenProtectionProvider);
    _apply(ref.read(settingsProvider).vaultBlockScreenshots);
  }

  @override
  void dispose() {
    _apply(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select((s) => s.vaultBlockScreenshots),
      (_, block) => _apply(block),
    );
    return widget.child;
  }
}

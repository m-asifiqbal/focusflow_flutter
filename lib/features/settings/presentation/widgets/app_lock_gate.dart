/// ============================================================
/// APP LOCK GATE — cross-feature contract (implemented by features/settings)
/// ============================================================
///
/// Wraps the whole navigator (app.dart). When Settings › App lock is on it
/// covers the app with [AppLockScreen] on launch and after the app spent
/// [AppLockController.grace] or longer in the background, and asks the OS
/// (biometrics / device passcode) right away. When "Hide content in app
/// switcher" is on it paints [PrivacyCover] while the app is inactive and
/// turns on the native protection ([PrivacyScreen]).
///
/// The navigator stays mounted underneath (no lost state) but is hidden
/// from hit-testing, semantics and tickers while locked.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/settings/domain/services/device_authenticator.dart';
import 'package:focusflow/features/settings/presentation/providers/app_lock_providers.dart';
import 'package:focusflow/features/settings/presentation/widgets/app_lock/app_lock_screen.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  /// Painting the app-switcher cover.
  bool _covered = false;

  AppLockController get _lock => ref.read(appLockControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyPrivacy(ref.read(settingsProvider).hideInAppSwitcher);
      if (ref.read(appLockControllerProvider).locked) _lock.unlock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _applyPrivacy(bool on) {
    ref
        .read(privacyScreenProvider)
        .setEnabled(on, coverColor: context.ff.canvas);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authenticating = ref.read(appLockControllerProvider).authenticating;
    switch (state) {
      case AppLifecycleState.inactive:
        // The OS prompt itself makes the app inactive: don't cover it.
        if (!authenticating && ref.read(settingsProvider).hideInAppSwitcher) {
          setState(() => _covered = true);
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _lock.onBackground();
      case AppLifecycleState.resumed:
        if (_covered) setState(() => _covered = false);
        // Other screens (e.g. the vault) may toggle the same native flag.
        _applyPrivacy(ref.read(settingsProvider).hideInAppSwitcher);
        // Prompt only when this resume just locked the app (a real
        // background stint); otherwise the lock screen's button is enough.
        if (_lock.onResume()) _lock.unlock();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select((s) => s.hideInAppSwitcher),
      (_, on) => _applyPrivacy(on),
    );
    final lock = ref.watch(appLockControllerProvider);
    final hidden = lock.locked || _covered;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        TickerMode(
          enabled: !hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: IgnorePointer(ignoring: hidden, child: widget.child),
          ),
        ),
        if (lock.locked)
          Positioned.fill(
            child: _LockLayer(
              busy: lock.authenticating,
              message: lock.message,
              onUnlock: _lock.unlock,
            ),
          ),
        if (_covered) const Positioned.fill(child: PrivacyCover()),
      ],
    );
  }
}

class _LockLayer extends ConsumerWidget {
  const _LockLayer({
    required this.busy,
    required this.message,
    required this.onUnlock,
  });

  final bool busy;
  final String? message;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind =
        ref.watch(appLockBiometricProvider).valueOrNull ?? BiometricKind.none;
    return AppLockScreen(
      methodLabel: kind.label,
      busy: busy,
      message: message,
      onUnlock: onUnlock,
    );
  }
}

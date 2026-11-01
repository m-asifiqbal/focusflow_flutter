/// ============================================================
/// HOME SYNC BUTTON — the floating Google Drive sync button on Home
/// ============================================================
///
/// What: a small frosted-glass circle in the bottom start corner of Home,
/// just above the tab bar, tinted with the accent. Shown only while a
/// Google account with Drive is connected (the app is complete without
/// one). It says what sync is doing:
///   * idle — the sync arrows;
///   * syncing — the arrows turn, with a progress ring while uploading;
///   * just finished — a tick for a moment;
///   * failed / needs the backup PIN — a small warning mark.
/// Tap = Sync now (the same path as Settings, so the backup-PIN question
/// comes first when needed); long-press = Backup & Sync.
/// Why: pull-to-refresh syncs too, but nobody sees it — the button makes
/// "did my changes go up?" answerable at a glance. Everything reads
/// [syncStatusProvider], so a background or on-open sync shows here too.
/// Costs: one blur on a 52-pt circle; the spin controller only runs while
/// syncing (and never under reduce motion).
/// ============================================================
library;

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/widgets/backup_prompts.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Whether Home shows the sync button: a Drive account is connected and
/// Backup & Sync › "Sync button on Home" is on.
final homeSyncVisibleProvider = Provider.autoDispose<bool>((ref) {
  if (!ref.watch(settingsProvider.select((s) => s.homeSyncButton))) {
    return false;
  }
  final account = ref.watch(cloudAccountProvider);
  return account != null && account.hasDrive;
});

class HomeSyncButton extends ConsumerStatefulWidget {
  const HomeSyncButton({super.key});

  /// Diameter of the glass circle.
  static const double size = 52;

  /// How long the tick stays after a sync.
  static const Duration doneHold = Duration(milliseconds: 1800);

  @override
  ConsumerState<HomeSyncButton> createState() => _HomeSyncButtonState();
}

class _HomeSyncButtonState extends ConsumerState<HomeSyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _justDone = false;
  Timer? _doneTimer;

  @override
  void dispose() {
    _doneTimer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  void _onStatus(SyncStatus? before, SyncStatus now) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (now.isBusy && !reduce) {
      if (!_spin.isAnimating) unawaited(_spin.repeat());
    } else if (_spin.isAnimating) {
      // Finish the turn instead of freezing mid-angle.
      unawaited(_spin.animateTo(1).then((_) => _spin.value = 0));
    }
    if ((before?.isBusy ?? false) && now.phase == SyncPhase.done) {
      _doneTimer?.cancel();
      setState(() => _justDone = true);
      _doneTimer = Timer(HomeSyncButton.doneHold, () {
        if (mounted) setState(() => _justDone = false);
      });
    }
  }

  Future<void> _sync() async {
    if (ref.read(syncStatusProvider).isBusy) return;
    FFHaptics.light(context);
    await syncNowWithPrompt(context, ref);
    if (!mounted) return;
    final status = ref.read(syncStatusProvider);
    if (status.phase == SyncPhase.error) {
      showFFToast(
        context,
        status.message ?? tr('Sync failed'),
        icon: FontAwesomeIcons.triangleExclamation,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncStatusProvider, _onStatus);
    final status = ref.watch(syncStatusProvider);
    final ff = context.ff;
    final busy = status.isBusy;
    final failed =
        !busy && (status.phase == SyncPhase.error || status.needsBackupPin);
    final ink = ff.isDark ? ff.primary : ff.primaryStrong;
    final label = busy
        ? tr('Syncing with Google Drive')
        : failed
        ? tr('Sync failed — tap to try again')
        : tr('Sync with Google Drive');

    final IconData icon;
    if (_justDone && !busy) {
      icon = FontAwesomeIcons.check;
    } else {
      icon = FontAwesomeIcons.arrowsRotate;
    }
    final glyph = AnimatedSwitcher(
      duration: context.motion(AppMotion.fast),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: Tween(
          begin: 0.5,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: a, child: child),
      ),
      child: RotationTransition(
        key: ValueKey(icon),
        turns: icon == FontAwesomeIcons.check
            ? const AlwaysStoppedAnimation(0)
            : _spin,
        child: Icon(icon, size: 19, color: _justDone ? ff.success : ink),
      ),
    );

    return Semantics(
      button: true,
      label: label,
      hint: tr('Long-press for Backup & Sync'),
      onTap: () => unawaited(_sync()),
      excludeSemantics: true,
      child: FFPressable(
        onTap: () => unawaited(_sync()),
        onLongPress: () => context.push(AppRoutes.settingsBackup),
        scale: 0.92,
        child: SizedBox.square(
          dimension: HomeSyncButton.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _Glass(ink: ink)),
              // The upload's progress, as a thin ring on the glass edge.
              if (busy)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: CircularProgressIndicator(
                      value: status.progress,
                      strokeWidth: 2,
                      color: ink,
                      backgroundColor: ink.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              Center(child: glyph),
              if (failed)
                PositionedDirectional(
                  top: 2,
                  end: 2,
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ff.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: ff.surface, width: 1.5),
                    ),
                    child: Icon(
                      FontAwesomeIcons.exclamation,
                      size: 8,
                      color: ff.surface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The frosted, accent-tinted circle (a cheaper solid pane under reduced
/// effects).
class _Glass extends StatelessWidget {
  const _Glass({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final reduced = FFEffects.reducedOf(context);
    final alpha = reduced ? 0.96 : 1.0;
    final fill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: ff.isDark
          ? [
              Color.alphaBlend(
                ff.primary.withValues(alpha: 0.16),
                ff.tabBar.withValues(alpha: 0.62 * alpha),
              ),
              ff.tabBar.withValues(alpha: 0.78 * alpha),
            ]
          : [
              Color.alphaBlend(
                Colors.white.withValues(alpha: 0.5),
                ff.surface.withValues(alpha: 0.55 * alpha),
              ),
              Color.alphaBlend(
                ff.primarySoft.withValues(alpha: 0.8),
                ff.surface.withValues(alpha: 0.5 * alpha),
              ),
            ],
    );
    final pane = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: fill,
        border: Border.all(
          color: ff.isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
    return DecoratedBox(
      // The shadow sits outside the clip so the glass floats.
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -6,
            color: ink.withValues(alpha: ff.isDark ? 0.35 : 0.28),
          ),
        ],
      ),
      child: ClipOval(
        child: reduced
            ? pane
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: pane,
              ),
      ),
    );
  }
}

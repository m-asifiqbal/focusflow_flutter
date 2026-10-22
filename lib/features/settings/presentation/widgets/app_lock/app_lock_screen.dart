/// ============================================================
/// APP LOCK SCREEN — what covers FocusFlow while it is locked
/// ============================================================
///
/// What: [AppLockScreen] — lock glyph, "FocusFlow is locked", an
/// "Unlock with Face ID" button (re-opens the OS prompt) and the reason
/// the last attempt failed. [PrivacyCover] — the plain branded cover shown
/// while the app is inactive (app switcher) when "Hide content in app
/// switcher" is on.
/// Why: both sit above the navigator in AppLockGate, so they bring their
/// own Material ancestor and never show item content.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({
    required this.methodLabel,
    required this.onUnlock,
    this.busy = false,
    this.message,
    super.key,
  });

  /// "Face ID", "Fingerprint", "Passcode"…
  final String methodLabel;
  final VoidCallback onUnlock;
  final bool busy;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Material(
      color: ff.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const _LockGlyph(),
              const SizedBox(height: AppSpacing.xxl),
              Semantics(
                header: true,
                child: Text(
                  tr('{name} is locked', {'name': AppInfo.name}),
                  textAlign: TextAlign.center,
                  style: context.text.title,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr('Unlock with {methodLabel} to continue.', {
                  'methodLabel': methodLabel,
                }),
                textAlign: TextAlign.center,
                style: context.text.body.copyWith(color: ff.inkMuted),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.meta.copyWith(color: ff.danger),
                ),
              ],
              const Spacer(flex: 4),
              FFPrimaryButton(
                label: tr('Unlock with {methodLabel}', {
                  'methodLabel': methodLabel,
                }),
                icon: FontAwesomeIcons.lockOpen,
                onPressed: busy ? null : onUnlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockGlyph extends StatelessWidget {
  const _LockGlyph();

  static const double _size = 88;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ff.primarySoft,
          borderRadius: BorderRadius.circular(_size * 0.32),
        ),
        child: Icon(FontAwesomeIcons.lock, size: 34, color: ff.primary),
      ),
    );
  }
}

/// Opaque, content-free cover for the app switcher.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.ff.canvas,
    child: const Center(child: _LockGlyph()),
  );
}

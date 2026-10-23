/// ============================================================
/// SIGN IN SCREEN — Welcome / Sign in (screen 02, `/sign-in`)
/// ============================================================
///
/// What: app tile, "Welcome to FocusFlow", a benefits card and three
/// stacked buttons — Continue with Google, Continue with Apple (iOS only)
/// and Use offline — over a legal footnote.
/// Why: the account choice decides whether Drive backup/sync is
/// available; the app is fully usable offline, so offline is a first-class
/// option rather than a "skip".
///
/// Behaviour: the pressed button shows a spinner and the others are
/// disabled ([signInControllerProvider]); cancelling a provider sheet is
/// silent; failures show a snackbar. After Google sign-in a Drive backup
/// shows the "Backup found" sheet (Start fresh records a baseline so old
/// backups aren't merged automatically), and with "Encrypt backups" on but
/// no backup PIN the user picks how backups are protected. With
/// `?intent=restore` every account choice ends in the restore picker, and
/// "Restore from a backup file" gets there without an account.
/// ============================================================
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/notifiers/sign_in_controller.dart';
import 'package:focusflow/features/auth/presentation/widgets/sign_in_benefits_card.dart';
import 'package:focusflow/features/auth/presentation/widgets/sign_in_button.dart';
import 'package:focusflow/features/auth/presentation/widgets/sign_in_sheets.dart';
import 'package:focusflow/features/backup/presentation/widgets/backup_prompts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({this.restoreIntent = false, super.key});

  /// Came from "Restore from Google Drive": go to the restore picker
  /// right after Google sign-in.
  final bool restoreIntent;

  SignInController _controller(WidgetRef ref) =>
      ref.read(signInControllerProvider.notifier);

  Future<void> _google(BuildContext context, WidgetRef ref) async {
    final controller = _controller(ref);
    final outcome = await controller.google(restoreIntent: restoreIntent);
    if (!context.mounted) return;
    switch (outcome) {
      case SignInRestore():
        context.go(AppRoutes.settingsBackupRestore);
      case SignInBackupFound(:final newest):
        final restore = await showBackupFoundSheet(context, newest);
        if (!context.mounted) return;
        if (restore ?? false) {
          // Let the sheet finish closing before the whole stack changes.
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) context.go(AppRoutes.settingsBackupRestore);
          return;
        }
        // Start fresh: existing backups are not merged automatically.
        // Dismissed: nothing decided — merging stays on hold and Backup &
        // Sync asks again.
        if (restore == false && !await controller.startFresh()) {
          if (context.mounted) {
            showUndoSnackbar(
              context,
              message: tr(
                'Couldn\'t reach Google Drive. Choose again in Settings › Backup.',
              ),
              icon: FontAwesomeIcons.circleInfo,
            );
          }
        }
        if (context.mounted) await _connectDrive(context, ref);
      case SignInDone():
        await _connectDrive(context, ref);
      case _:
        _handle(context, outcome);
    }
  }

  /// Drive just got connected: with "Encrypt backups" on and no backup
  /// PIN yet, ask how backups should be protected before the first one
  /// (dismissing leaves a banner in Backup & Sync), then leave.
  Future<void> _connectDrive(BuildContext context, WidgetRef ref) async {
    if (await backupEncryptionUnresolved(ref) && context.mounted) {
      await resolveBackupEncryption(context, ref);
    }
    if (context.mounted) _leave(context);
  }

  Future<void> _apple(BuildContext context, WidgetRef ref) async {
    final outcome = await _controller(ref).apple(restoreIntent: restoreIntent);
    if (context.mounted) _handle(context, outcome);
  }

  Future<void> _offline(BuildContext context, WidgetRef ref) async {
    final name = await showOfflineNameSheet(context);
    if (name == null || !context.mounted) return;
    final outcome = await _controller(
      ref,
    ).offline(name: name, restoreIntent: restoreIntent);
    if (context.mounted) _handle(context, outcome);
  }

  Future<void> _fromFile(BuildContext context, WidgetRef ref) async {
    final outcome = await _controller(ref).restoreFromFile();
    if (context.mounted) _handle(context, outcome);
  }

  void _handle(BuildContext context, SignInOutcome outcome) {
    switch (outcome) {
      case SignInCancelled():
        return;
      case SignInFailed(:final message):
        showUndoSnackbar(
          context,
          message: message,
          icon: FontAwesomeIcons.triangleExclamation,
        );
      case SignInDone(:final appleNoDrive):
        if (appleNoDrive) {
          showUndoSnackbar(
            context,
            message: tr(
              'Signed in with Apple. Connect Google later in Settings › Backup for Drive backup.',
            ),
            icon: FontAwesomeIcons.circleInfo,
          );
        }
        _leave(context);
      case SignInRestore():
        context.go(AppRoutes.settingsBackupRestore);
      case SignInBackupFound():
        _leave(context);
    }
  }

  /// Back to where the user came from (Settings › Account / Backup), or
  /// Home at first launch.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(signInControllerProvider);
    final controller = ref.watch(signInControllerProvider.notifier);
    final ff = context.ff;
    final text = context.text;
    VoidCallback? tap(SignInMethod m, VoidCallback action) =>
        busy == null ? action : null;

    return FFScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          38,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExcludeSemantics(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: ff.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: ff.heroShadow,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    FontAwesomeIcons.bolt,
                    size: 28,
                    color: ff.onGradient,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Semantics(
              header: true,
              child: Text(
                tr('Welcome to {name}', {'name': AppInfo.name}),
                style: text.largeTitle.copyWith(fontSize: 31),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              restoreIntent
                  ? tr(
                      'Sign in with Google to restore your backup from Drive, or restore from a backup file.',
                    )
                  : tr(
                      'Sign in to keep your workspace safe and synced. You can also start offline and connect later.',
                    ),
              style: text.body.copyWith(fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const SignInBenefitsCard(),
            const SizedBox(height: AppSpacing.xxxl),
            SignInButton(
              kind: SignInButtonKind.google,
              label: tr('Continue with Google'),
              loading: busy == SignInMethod.google,
              onPressed: tap(SignInMethod.google, () => _google(context, ref)),
            ),
            if (controller.appleAvailable) ...[
              const SizedBox(height: 14),
              SignInButton(
                kind: SignInButtonKind.apple,
                label: tr('Continue with Apple'),
                loading: busy == SignInMethod.apple,
                onPressed: tap(SignInMethod.apple, () => _apple(context, ref)),
              ),
            ],
            const SizedBox(height: 14),
            SignInButton(
              kind: SignInButtonKind.offline,
              label: tr('Use offline (local only)'),
              loading: busy == SignInMethod.offline,
              onPressed: tap(
                SignInMethod.offline,
                () => _offline(context, ref),
              ),
            ),
            if (restoreIntent) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: FFTextButton(
                  label: tr('Restore from a backup file'),
                  onPressed: busy == null
                      ? () => _fromFile(context, ref)
                      : null,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: _LegalFootnote(),
            ),
          ],
        ),
      ),
    );
  }
}

// Private-use characters that stand in for the links inside the sentence.
const _termsMark = '\uE000';
const _privacyMark = '\uE001';

/// [sentence] with each marker character replaced by its span.
List<InlineSpan> _withLinks(String sentence, Map<String, InlineSpan> links) {
  final out = <InlineSpan>[];
  var start = 0;
  for (var i = 0; i < sentence.length; i++) {
    final link = links[sentence[i]];
    if (link == null) continue;
    if (i > start) out.add(TextSpan(text: sentence.substring(start, i)));
    out.add(link);
    start = i + 1;
  }
  if (start < sentence.length) {
    out.add(TextSpan(text: sentence.substring(start)));
  }
  return out;
}

/// "By continuing you agree to our Terms and Privacy Policy. …"
class _LegalFootnote extends StatefulWidget {
  const _LegalFootnote();

  @override
  State<_LegalFootnote> createState() => _LegalFootnoteState();
}

class _LegalFootnoteState extends State<_LegalFootnote> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _open(AppInfo.termsUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open(AppInfo.privacyUrl);

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object {
      // No browser — nothing to do.
    }
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = context.text.meta.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.6,
      color: ff.inkFaint,
    );
    final link = style.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: ff.inkFaint,
    );
    return Text.rich(
      TextSpan(
        style: style,
        // One sentence (word order differs per language): the two links are
        // marked inside the translated text and swapped for tappable spans.
        children: _withLinks(
          tr(
            'By continuing you agree to our {terms} and {privacy}. We only request access to the app\'s own Drive folder.',
            {'terms': _termsMark, 'privacy': _privacyMark},
          ),
          {
            _termsMark: TextSpan(
              text: tr('Terms'),
              style: link,
              recognizer: _terms,
            ),
            _privacyMark: TextSpan(
              text: tr('Privacy Policy'),
              style: link,
              recognizer: _privacy,
            ),
          },
        ),
      ),
      textAlign: TextAlign.center,
    );
  }
}

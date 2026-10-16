/// Temporary screen used while a feature is being built. Feature agents
/// replace every `PlaceholderScreen` in their `<feature>_routes.dart`.
///
/// Debug builds show "Continue to app" on root-level placeholders (no back
/// stack — e.g. onboarding / sign-in before they exist) so the finished
/// screens can be reached and tested. It marks onboarding as seen, picks
/// offline mode and goes Home.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_buttons.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen(this.title, {this.detail, super.key});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();
    final launchFlow = !ref.watch(
      settingsProvider.select((s) => s.onboardingSeen),
    );
    return Scaffold(
      backgroundColor: context.ff.canvas,
      appBar: canPop ? AppBar(title: Text(title)) : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.text.largeTitle),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(detail!, style: context.text.meta),
              ],
              if (kDebugMode && launchFlow) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'This screen is not built yet.',
                  style: context.text.meta,
                ),
                const SizedBox(height: AppSpacing.lg),
                FFPrimaryButton(
                  label: 'Continue to app',
                  onPressed: () async {
                    await ref
                        .read(settingsProvider.notifier)
                        .update(
                          (s) => s.copyWith(
                            onboardingSeen: true,
                            accountMode: AccountMode.offline,
                          ),
                        );
                    if (context.mounted) context.go(AppRoutes.home);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

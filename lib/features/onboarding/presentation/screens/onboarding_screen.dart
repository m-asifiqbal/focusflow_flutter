/// ============================================================
/// ONBOARDING SCREEN — first-run introduction (screen 01)
/// ============================================================
///
/// What: Skip · 3-page PageView (hero + title + body) · page dots ·
/// "Get Started" (advances; "Continue" on the last page → Sign in) ·
/// "Already have a backup? Restore" (→ Sign in with intent=restore).
/// Why: leaving onboarding by any route marks it as seen, so it never
/// shows again; the sign-in screen decides what comes next.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:focusflow/features/onboarding/presentation/widgets/onboarding_pages.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _leave(String location) async {
    await ref.read(onboardingControllerProvider.notifier).finish();
    if (mounted) context.go(location);
  }

  void _next() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    if (controller.isLast) {
      _leave(AppRoutes.signIn);
      return;
    }
    final target = ref.read(onboardingControllerProvider) + 1;
    if (context.reduceMotion) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: AppMotion.slow,
        curve: AppMotion.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final page = ref.watch(onboardingControllerProvider);
    final last = page == OnboardingController.pageCount - 1;
    // Short screens (or large text) tighten the vertical rhythm.
    final compact = MediaQuery.sizeOf(context).height < 760;
    return FFScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screen,
              0,
              AppSpacing.screen - AppSpacing.xs,
              0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FFTextButton(
                label: tr('Skip'),
                semanticLabel: tr('Skip introduction'),
                style: context.text.button.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ff.primary,
                ),
                onPressed: () => _leave(AppRoutes.signIn),
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: ref
                  .read(onboardingControllerProvider.notifier)
                  .setPage,
              children: [
                for (final p in onboardingPages) OnboardingPageView(page: p),
              ],
            ),
          ),
          SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxxl),
          _Dots(count: onboardingPages.length, index: page),
          SizedBox(
            height: compact ? AppSpacing.xl : AppSpacing.xxxl + AppSpacing.xs,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.screen,
            ),
            child: FFPrimaryButton(
              label: last ? tr('Continue') : tr('Get Started'),
              onPressed: _next,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RestoreLink(onTap: () => _leave(AppRoutes.signInRestore)),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Active pill 28×8 + 8×8 dots.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final duration = context.reduceMotion ? Duration.zero : AppMotion.normal;
    return Semantics(
      label: tr('Page {v} of {count}', {'v': index + 1, 'count': count}),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: AppMotion.curve,
              margin: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xs + 1,
              ),
              width: i == index
                  ? AppSpacing.xxl + AppSpacing.xs
                  : AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: BoxDecoration(
                color: i == index ? ff.primary : ff.highlight,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}

// Private-use character that stands in for the "Restore" word.
const _restoreMark = '\uE000';

/// [sentence] with the marker replaced by [restore].
List<InlineSpan> _withRestore(String sentence, InlineSpan restore) {
  final at = sentence.indexOf(_restoreMark);
  if (at < 0) return [TextSpan(text: sentence)];
  return [
    if (at > 0) TextSpan(text: sentence.substring(0, at)),
    restore,
    if (at + 1 < sentence.length) TextSpan(text: sentence.substring(at + 1)),
  ];
}

/// "Already have a backup? Restore" — the whole line is the tap target.
class _RestoreLink extends StatelessWidget {
  const _RestoreLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = context.text.body.copyWith(height: 1.3);
    return Semantics(
      button: true,
      label: tr('Already have a backup? {restore}', {'restore': tr('Restore')}),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Text.rich(
                TextSpan(
                  // One sentence: the word "Restore" is marked inside the
                  // translated text so it keeps its colour in any word order.
                  children: _withRestore(
                    tr('Already have a backup? {restore}', {
                      'restore': _restoreMark,
                    }),
                    TextSpan(
                      text: tr('Restore'),
                      style: TextStyle(
                        color: ff.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

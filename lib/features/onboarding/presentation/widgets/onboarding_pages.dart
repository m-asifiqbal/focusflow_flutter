/// ============================================================
/// ONBOARDING PAGES — copy + illustration of the 3 intro pages
/// ============================================================
///
/// 1) All-in-one (module chips around the bolt tile) · 2) Private by
/// design (vault + encryption) · 3) Sync everywhere (Drive backup).
/// Chip positions are measured from design/01_onboarding.png (pt inside
/// the 342×330 hero box).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/onboarding/presentation/widgets/onboarding_hero.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.titleLead,
    required this.titleAccent,
    required this.body,
    required this.icon,
    required this.chips,
  });

  final String titleLead;

  /// Second title line, in the primary colour.
  final String titleAccent;
  final String body;
  final IconData icon;
  final List<HeroChip> chips;
}

const _p1 = Offset(30, 30);
const _p2 = Offset(231, 9);
const _p3 = Offset(10, 200);
const _p4 = Offset(216, 195);
const _p5 = Offset(121, 280);

/// A getter, not a top-level final: the copy is translated when it is read,
/// so it follows the language the user picks (a final would freeze it).
List<OnboardingPageData> get onboardingPages => [
  OnboardingPageData(
    titleLead: tr('Everything you need,'),
    titleAccent: tr('in one calm place.'),
    body: tr(
      'Notes, tasks, reminders, habits and a secure password vault — '
      'organised, synced and private.',
    ),
    icon: FontAwesomeIcons.bolt,
    chips: [
      HeroChip(
        label: tr('Notes'),
        icon: ModuleStyle.notes.icon,
        colors: ModuleStyle.notes.colors,
        position: _p1,
      ),
      HeroChip(
        label: tr('Tasks'),
        icon: ModuleStyle.tasks.icon,
        colors: ModuleStyle.tasks.colors,
        position: _p2,
      ),
      HeroChip(
        label: tr('Habits'),
        icon: ModuleStyle.habits.icon,
        colors: ModuleStyle.habits.colors,
        position: _p3,
      ),
      HeroChip(
        label: tr('Reminders'),
        icon: ModuleStyle.reminders.icon,
        colors: ModuleStyle.reminders.colors,
        position: _p4,
      ),
      HeroChip(
        label: tr('Vault'),
        icon: ModuleStyle.vault.icon,
        colors: ModuleStyle.vault.colors,
        position: _p5,
      ),
    ],
  ),
  OnboardingPageData(
    titleLead: tr('Private by design,'),
    titleAccent: tr('yours alone.'),
    body: tr(
      'Your data is encrypted on this device and the vault adds AES-256 on '
      'top. No ads, no tracking, no account required.',
    ),
    icon: FontAwesomeIcons.shieldHalved,
    chips: [
      HeroChip(
        label: tr('AES-256'),
        icon: FontAwesomeIcons.lock,
        colors: ModuleStyle.vault.colors,
        position: _p1,
      ),
      HeroChip(
        label: tr('Biometric'),
        icon: FontAwesomeIcons.fingerprint,
        colors: ModuleStyle.habits.colors,
        position: _p2,
      ),
      HeroChip(
        label: tr('Offline'),
        icon: FontAwesomeIcons.mobileScreen,
        colors: ModuleStyle.notes.colors,
        position: _p3,
      ),
      HeroChip(
        label: tr('No tracking'),
        icon: FontAwesomeIcons.solidEyeSlash,
        colors: ModuleStyle.reminders.colors,
        position: const Offset(206, 195),
      ),
      HeroChip(
        label: tr('Your keys'),
        icon: FontAwesomeIcons.key,
        colors: ModuleStyle.tasks.colors,
        position: const Offset(112, 280),
      ),
    ],
  ),
  OnboardingPageData(
    titleLead: tr('Sync everywhere,'),
    titleAccent: tr('back up safely.'),
    body: tr(
      'Optional Google Drive backup keeps everything safe and in sync '
      'across your devices — or stay fully offline.',
    ),
    icon: FontAwesomeIcons.cloudArrowUp,
    chips: [
      HeroChip(
        label: tr('Drive'),
        icon: FontAwesomeIcons.googleDrive,
        colors: ModuleStyle.tasks.colors,
        position: _p1,
      ),
      HeroChip(
        label: tr('Daily'),
        icon: FontAwesomeIcons.solidClock,
        colors: ModuleStyle.notes.colors,
        position: _p2,
      ),
      HeroChip(
        label: tr('Encrypted'),
        icon: FontAwesomeIcons.lock,
        colors: ModuleStyle.vault.colors,
        position: const Offset(0, 200),
      ),
      HeroChip(
        label: tr('Restore'),
        icon: FontAwesomeIcons.arrowsRotate,
        colors: ModuleStyle.reminders.colors,
        position: const Offset(222, 195),
      ),
      HeroChip(
        label: tr('Devices'),
        icon: FontAwesomeIcons.mobileScreen,
        colors: ModuleStyle.habits.colors,
        position: const Offset(116, 280),
      ),
    ],
  ),
];

/// Hero (flexible) · two-line title · body.
class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({required this.page, super.key});

  final OnboardingPageData page;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    // Headlines stop growing at 1.15× so the illustration keeps room at
    // large text sizes; the body text scales fully.
    final titleScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);
    final title = context.text.largeTitle.copyWith(height: 1.12);
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxHeight < 520;
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.screen,
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    top: compact ? AppSpacing.sm : AppSpacing.xxl,
                  ),
                  child: Center(
                    child: OnboardingHero(icon: page.icon, chips: page.chips),
                  ),
                ),
              ),
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxxl),
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${page.titleLead}\n'),
                      TextSpan(
                        text: page.titleAccent,
                        style: TextStyle(color: ff.primary),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  textScaler: titleScaler,
                  style: title,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Text(
                  page.body,
                  textAlign: TextAlign.center,
                  style: context.text.body,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

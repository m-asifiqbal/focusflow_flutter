/// ============================================================
/// REMINDERS LIST STATES — loading / error / empty (screen 12, 29)
/// ============================================================
///
/// What: skeleton rows while the first query runs, an error card with
/// Retry, the full empty state (no reminders at all, screen 29) and a
/// compact per-chip / per-day empty state.
/// Why: the screen file stays layout only.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';

const EdgeInsetsGeometry _gutter = EdgeInsetsDirectional.fromSTEB(
  AppSpacing.screen,
  AppSpacing.xl,
  AppSpacing.screen,
  0,
);

class RemindersLoadingState extends StatelessWidget {
  const RemindersLoadingState({super.key});

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: _gutter, child: FFSkeletonList(count: 4));
}

class RemindersErrorState extends StatelessWidget {
  const RemindersErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: _gutter,
    child: FFEmptyState.compact(
      colors: ModuleStyle.reminders.colors,
      icon: FontAwesomeIcons.triangleExclamation,
      title: tr('Couldn\'t load reminders'),
      body: tr('Something went wrong reading your reminders. Try again.'),
      ctaLabel: tr('Retry'),
      ctaIcon: FontAwesomeIcons.arrowRotateRight,
      onCta: onRetry,
    ),
  );
}

/// Empty timeline. [hasAny] = the user has reminders elsewhere (another
/// day / chip), which gets the compact variant.
class RemindersEmptyState extends StatelessWidget {
  const RemindersEmptyState({
    required this.scope,
    required this.hasAny,
    required this.onAdd,
    this.dayLabel,
    super.key,
  });

  final RemindersScope scope;
  final bool hasAny;
  final VoidCallback onAdd;

  /// "Today" / "Tomorrow" / "Wed, Oct 14" for the Today chip.
  final String? dayLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ModuleStyle.reminders.colors;
    if (!hasAny) {
      return Padding(
        padding: _gutter,
        child: FFEmptyState(
          colors: colors,
          icon: FontAwesomeIcons.solidBell,
          title: tr('No reminders yet'),
          body: tr(
            'Add a reminder and FocusFlow will nudge you at the right time — it works offline too.',
          ),
          ctaLabel: tr('Add reminder'),
          ctaIcon: FontAwesomeIcons.plus,
          onCta: onAdd,
        ),
      );
    }
    final (title, body) = switch (scope) {
      RemindersScope.upcoming => (
        tr('Nothing coming up'),
        tr('Every reminder is done or turned off.'),
      ),
      RemindersScope.recurring => (
        tr('No repeating reminders'),
        tr('Set Repeat on a reminder to see it here.'),
      ),
      RemindersScope.location => (
        tr('No location reminders'),
        tr('Reminders that fire when you arrive or leave a place show here.'),
      ),
      RemindersScope.snoozed => (
        tr('Nothing snoozed'),
        tr('Snoozed reminders show here until they fire again.'),
      ),
      _ => (
        tr('Nothing scheduled'),
        tr('{day} is clear. Enjoy the free time, or add a reminder.', {
          'day': dayLabel ?? tr('This day'),
        }),
      ),
    };
    return Padding(
      padding: _gutter,
      child: FFEmptyState.compact(
        colors: colors,
        icon: FontAwesomeIcons.solidBell,
        title: title,
        body: body,
        ctaLabel: tr('Add reminder'),
        ctaIcon: FontAwesomeIcons.plus,
        onCta: onAdd,
      ),
    );
  }
}

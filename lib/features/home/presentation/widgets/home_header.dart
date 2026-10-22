/// ============================================================
/// HOME HEADER — avatar, date overline, greeting, search + bell
/// ============================================================
///
/// What: "TUESDAY, JUNE 13" over "Good morning, Asif" next to the avatar
/// (initial on the accent gradient), with round Search and Bell buttons;
/// the bell carries a red dot while the notification center has unread
/// entries.
/// Why: the name comes from settings (or the signed-in account) and the
/// greeting follows the time of day (minute clock), so it stays current.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/widgets/profile_avatar.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:go_router/go_router.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final now = ref.watch(minuteClockProvider);
    final name = ref.watch(homeDisplayNameProvider);
    final unread = ref.watch(homeUnreadProvider).valueOrNull ?? 0;
    final first = HomeRules.firstName(name);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        HomeDimens.headerTop,
        AppSpacing.screen,
        // Breathing room under the fixed toolbar (scrolled content slides
        // beneath it, so it must not touch the edge).
        AppSpacing.md,
      ),
      child: Row(
        children: [
          ProfileAvatar(
            initial: first.isEmpty ? null : first,
            size: HomeDimens.avatar,
            semanticLabel: first.isEmpty
                ? tr('Profile')
                : tr('Profile, {first}', {'first': first}),
            onTap: () => context.push(AppRoutes.settingsAccount),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormats.of('EEEE, MMMM d').format(now).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.sectionLabel.copyWith(
                    fontSize: HomeDimens.overline,
                    letterSpacing: 0.6,
                    color: ff.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Semantics(
                  header: true,
                  child: Text(
                    HomeRules.greeting(now, name),
                    // Wraps rather than truncating at large text sizes.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.title.copyWith(
                      fontSize: HomeDimens.greeting,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The mockup's greeting runs right up to the Search button.
          const SizedBox(width: AppSpacing.xs),
          FFRoundIconButton(
            icon: FontAwesomeIcons.magnifyingGlass,
            semanticLabel: tr('Search'),
            onPressed: () => context.push(AppRoutes.search),
          ),
          const SizedBox(width: HomeDimens.headerButtonGap),
          FFRoundIconButton(
            icon: FontAwesomeIcons.solidBell,
            semanticLabel: unread > 0
                ? tr('Notifications, {unread} unread', {'unread': unread})
                : tr('Notifications'),
            badge: unread > 0,
            onPressed: () => context.push(AppRoutes.notificationCenter),
          ),
        ],
      ),
    );
  }
}

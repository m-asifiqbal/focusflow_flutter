/// ============================================================
/// NOTIFICATION CENTER SCREEN — screen 27 (`/notifications`)
/// ============================================================
///
/// What: back · "Notifications" · "Read all"; kind filter chips; TODAY and
/// EARLIER cards of inbox rows with unread dots and inline actions; swipe
/// to dismiss (Undo); tap opens the item. Empty: "You're all caught up".
/// Why: the in-app inbox of everything the notification engine and the
/// security / sync alerts delivered (live over [inboxSectionsProvider]).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/notifications_center/presentation/inbox_flows.dart';
import 'package:focusflow/features/notifications_center/presentation/notifiers/inbox_actions_controller.dart';
import 'package:focusflow/features/notifications_center/presentation/providers/notification_center_providers.dart';
import 'package:focusflow/features/notifications_center/presentation/state/inbox_sections.dart';
import 'package:focusflow/features/notifications_center/presentation/widgets/inbox_group.dart';
import 'package:focusflow/features/notifications_center/presentation/widgets/inbox_kind_style.dart';
import 'package:focusflow/features/notifications_center/presentation/widgets/inbox_row.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  /// Rows swiped away whose stream update hasn't arrived yet (a dismissed
  /// [Dismissible] must leave the tree immediately).
  final Set<String> _hidden = {};

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(inboxFilterProvider);
    final sections = ref.watch(inboxSectionsProvider(kind));
    final unread = sections.valueOrNull?.unread ?? 0;
    return MinuteTicker(
      child: FFScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FFNavHeader(
              leading: const FFBackButton(),
              title: 'Notifications',
              trailing: [
                FFNavAction(
                  label: 'Read all',
                  enabled: unread > 0,
                  onPressed: () => ref
                      .read(inboxActionsControllerProvider)
                      .markAllRead(kind),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FFChipBar<InboxKind?>(
              items: [
                for (final (k, label) in inboxFilters)
                  FFChipItem(value: k, label: label),
              ],
              selected: kind,
              onSelected: ref.read(inboxFilterProvider.notifier).select,
            ),
            Expanded(
              child: sections.when(
                data: (s) => _list(context, s, kind),
                loading: () => const _InboxSkeleton(),
                error: (_, _) => Center(
                  child: FFEmptyState.compact(
                    colors: ModuleStyle.reminders.colors,
                    icon: FontAwesomeIcons.triangleExclamation,
                    title: "Couldn't load notifications",
                    body: 'Something went wrong reading your inbox.',
                    ctaLabel: 'Try again',
                    ctaIcon: FontAwesomeIcons.arrowRotateRight,
                    onCta: () => ref.invalidate(inboxEntriesProvider(kind)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, InboxSections s, InboxKind? kind) {
    bool visible(InboxEntry e) => !_hidden.contains(e.id);
    final today = s.today.where(visible).toList();
    final earlier = s.earlier.where(visible).toList();
    if (today.isEmpty && earlier.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.screen),
          child: FFEmptyState(
            colors: ModuleStyle.notes.colors,
            icon: FontAwesomeIcons.solidBell,
            title: "You're all caught up",
            body: kind == null
                ? 'Reminders, overdue tasks, habit nudges and security or '
                      'sync alerts will show up here.'
                : 'Nothing here right now.',
          ),
        ),
      );
    }
    final now = ref.watch(minuteClockProvider);
    final use24h = ref.watch(settingsProvider.select((x) => x.use24HourTime));
    final snooze = ref.watch(inboxSnoozeMinutesProvider);
    // The opened item grows out of its row (open-container transition).
    Widget row(InboxEntry e) => FFOpenOriginTracker(
      radius: 0,
      child: InboxRow(
        entry: e,
        timeLabel: InboxTimeLabel.of(e.createdAt, now, use24h: use24h),
        timeSemantic: InboxTimeLabel.semantic(e.createdAt, now, use24h: use24h),
        actionLabel: (a) => inboxActionLabel(a, snooze),
        onTap: () => openInboxEntry(context, ref, e),
        onAction: (a) =>
            runInboxAction(context, ref, e, a, snoozeMinutes: snooze),
      ),
    );
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.grouped,
        AppSpacing.xxl,
        AppSpacing.grouped,
        AppSpacing.xxxl,
      ),
      children: [
        if (today.isNotEmpty)
          InboxGroup(
            label: 'Today',
            entries: today,
            rowBuilder: row,
            onDismiss: _dismiss,
          ),
        if (today.isNotEmpty && earlier.isNotEmpty)
          const SizedBox(height: AppSpacing.section),
        if (earlier.isNotEmpty)
          InboxGroup(
            label: 'Earlier',
            entries: earlier,
            rowBuilder: row,
            onDismiss: _dismiss,
          ),
      ],
    );
  }

  Future<void> _dismiss(InboxEntry e) async {
    setState(() => _hidden.add(e.id));
    await dismissInboxEntry(
      context,
      ref,
      e,
      onUndo: () {
        if (mounted) setState(() => _hidden.remove(e.id));
      },
    );
  }
}

/// Loading placeholder: one card of three row skeletons.
class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return FFShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.grouped,
          AppSpacing.xxl,
          AppSpacing.grouped,
          0,
        ),
        children: [
          const FFSkeleton(width: 60, height: 12),
          const SizedBox(height: AppSpacing.md),
          FFCard(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  const Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        FFSkeleton(
                          width: InboxRow.tile,
                          height: InboxRow.tile,
                          radius: AppRadii.tile,
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(child: FFSkeleton(height: 14)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

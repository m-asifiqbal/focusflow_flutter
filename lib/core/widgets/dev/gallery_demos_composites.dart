/// ============================================================
/// GALLERY DEMOS · COMPOSITES — lists, sheets, dialogs, data viz, nav
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/dev/gallery_demos.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

List<GalleryDemo> get compositeDemos => [
  GalleryDemo('FFCard', (_) => const _CardDemo()),
  GalleryDemo('FFGroupedList', (_) => const _GroupedDemo()),
  GalleryDemo('FFStatTile', (_) => const _StatsDemo()),
  GalleryDemo('FFWeekStrip', (_) => const _WeekDemo()),
  GalleryDemo('FFHeatmap', (_) => const _HeatmapDemo()),
  GalleryDemo('FFSwipeActions', (_) => const _SwipeDemo()),
  GalleryDemo('Banners', (_) => const _BannersDemo()),
  GalleryDemo('FFEmptyState', (_) => const _EmptyDemo()),
  GalleryDemo('FFSkeleton', (_) => const _SkeletonDemo()),
  GalleryDemo('FFActionSheet', (_) => const _ActionSheetDemo()),
  GalleryDemo('FFDialog', (_) => const _DialogDemo()),
  GalleryDemo('FFSnackbar', (_) => const _SnackbarDemo()),
  GalleryDemo('FFBottomNav', (_) => const _BottomNavDemo()),
];

void _noop() {}

/// Sample data for the actions sheet (screen 09).
FFActionSheetData demoActionSheetData({VoidCallback? onAny}) {
  final tap = onAny ?? _noop;
  return FFActionSheetData(
    header: FFActionSheetHeader(
      title: 'Mobile App Design Trends 2024',
      meta: 'Note · Ideas · Edited today',
      icon: ModuleStyle.notes.icon,
      colors: ModuleStyle.notes.colors,
    ),
    actions: [
      FFActionItem(
        icon: FontAwesomeIcons.thumbtack,
        label: 'Pin to top',
        colors: ModuleStyle.notes.colors,
        onTap: tap,
      ),
      FFActionItem(
        icon: FontAwesomeIcons.solidStar,
        label: 'Add to favourites',
        colors: ModuleStyle.vault.colors,
        onTap: tap,
      ),
      FFActionItem(
        icon: FontAwesomeIcons.solidCopy,
        label: 'Duplicate',
        colors: ModuleStyle.tasks.colors,
        onTap: tap,
      ),
      FFActionItem(
        icon: FontAwesomeIcons.palette,
        label: 'Change colour',
        colors: TagPalette.design,
        onTap: tap,
      ),
      FFActionItem(
        icon: FontAwesomeIcons.solidBell,
        label: 'Set reminder',
        colors: ModuleStyle.reminders.colors,
        onTap: tap,
      ),
    ],
    onArchive: tap,
    onDelete: tap,
  );
}

class _CardDemo extends StatelessWidget {
  const _CardDemo();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FFCard(
            onTap: _noop,
            semanticLabel: 'Open note',
            color: NoteColors.background('D1FAE5', context.ff.brightness),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FFTag('Ideas'),
                const SizedBox(height: AppSpacing.sm),
                Text('Mobile App Design', style: context.text.cardTitle),
                Text('Minimalism, organic…', style: context.text.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.cardGap),
        Expanded(
          child: FFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FFTag('Work'),
                const SizedBox(height: AppSpacing.sm),
                Text('Weekend Shopping', style: context.text.cardTitle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupedDemo extends StatelessWidget {
  const _GroupedDemo();

  @override
  Widget build(BuildContext context) {
    FFIconTile tile(IconData i, ModuleColors c) =>
        FFIconTile(icon: i, colors: c, size: 32, iconSize: 14);
    return GalleryState<bool>(
      initial: true,
      builder: (context, hide, set) => FFGroupedList(
        label: 'General',
        footer: 'Applies to every module.',
        children: [
          FFListRow(
            leading: tile(FontAwesomeIcons.globe, TagPalette.travel),
            title: 'Language',
            value: 'English',
            onTap: _noop,
          ),
          FFListRow(
            leading: tile(FontAwesomeIcons.house, ModuleStyle.notes.colors),
            title: 'Notifications & Reminders',
            value: 'Weekdays only',
            onTap: _noop,
          ),
          FFListRow.toggle(
            leading: tile(FontAwesomeIcons.eyeSlash, TagPalette.design),
            title: 'Hide content in app switcher',
            value: hide,
            onChanged: set,
          ),
          FFListRow(
            leading: tile(FontAwesomeIcons.trashCan, ModuleStyle.scan.colors),
            title: 'Recently Deleted',
            subtitle: 'Auto-deletes after 30 days',
            value: '5',
            onTap: _noop,
          ),
          FFListRow(
            title: 'Backup & Sync',
            value: 'Google Drive',
            valueColor: context.ff.primary,
            onTap: _noop,
          ),
          FFListRow(title: 'Sign out', destructive: true, onTap: _noop),
        ],
      ),
    );
  }
}

class _StatsDemo extends StatelessWidget {
  const _StatsDemo();

  @override
  Widget build(BuildContext context) {
    const tiles = [
      FFStatTile(value: '7', label: 'Today', colors: TagPalette.work),
      FFStatTile(value: '2', label: 'Overdue', colors: TagPalette.high),
      FFStatTile(value: '14', label: 'Upcoming', colors: TagPalette.ideas),
      FFStatTile(value: '38', label: 'Done'),
    ];
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FFCard(
          gradient: context.ff.primaryGradient,
          radius: AppRadii.hero,
          child: const Row(
            children: [
              Expanded(
                child: FFStatTile.glass(value: '4/7', label: 'Tasks'),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FFStatTile.glass(value: '2/4', label: 'Habits'),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FFStatTile.glass(value: '3', label: 'Reminders'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekDemo extends StatelessWidget {
  const _WeekDemo();

  @override
  Widget build(BuildContext context) {
    final start = DateTime(2023, 6, 12);
    final days = [for (var i = 0; i < 7; i++) DateTime(2023, 6, 12 + i)];
    bool items(DateTime d) => d.day.isOdd;
    return GalleryState<DateTime>(
      initial: DateTime(2023, 6, 13),
      builder: (context, sel, set) => Column(
        children: [
          FFWeekStrip(
            days: days,
            selected: sel,
            onSelected: set,
            hasItems: items,
            today: start.add(const Duration(days: 1)),
            padding: EdgeInsetsDirectional.zero,
          ),
          FFCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: FFWeekStrip(
              days: days,
              selected: sel,
              onSelected: set,
              hasItems: items,
              today: start.add(const Duration(days: 1)),
              style: FFWeekStripStyle.circle,
              accent: ModuleStyle.reminders.solid,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapDemo extends StatelessWidget {
  const _HeatmapDemo();

  @override
  Widget build(BuildContext context) {
    final end = DateTime(2023, 6, 13);
    final values = <DateTime, double>{
      for (var i = 0; i < 115; i++)
        DateTime(2023, 6, 13 - i): ((i * 37) % 11) / 10,
    };
    final c = ModuleStyle.tasks.solid;
    return FFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FFHeatmap(values: values, end: end, color: c, onTap: (_) {}),
          const SizedBox(height: AppSpacing.md),
          FFHeatmapLegend(color: c),
        ],
      ),
    );
  }
}

class _SwipeDemo extends StatelessWidget {
  const _SwipeDemo();

  @override
  Widget build(BuildContext context) {
    Widget row(String title) => FFSwipeActions(
      startAction: FFSwipeAction.complete(onTap: _noop),
      endActions: [
        FFSwipeAction.archive(onTap: _noop),
        FFSwipeAction.delete(onTap: _noop),
      ],
      child: FFCard(
        child: Row(
          children: [
            FFCheckCircle(checked: false, onChanged: (_) {}),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.cardTitle,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        row('Submit tax documents'),
        const SizedBox(height: AppSpacing.cardGap),
        row('Renew gym membership'),
      ],
    );
  }
}

class _BannersDemo extends StatelessWidget {
  const _BannersDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const FFInfoBanner(
          icon: FontAwesomeIcons.circleInfo,
          text:
              'Archived items are hidden from lists, search and reminders '
              'but kept safe & synced.',
        ),
        const SizedBox(height: AppSpacing.md),
        FFInfoBanner.danger(
          icon: FontAwesomeIcons.trashCan,
          text: 'Items are deleted forever after 30 days.',
          actionLabel: 'Empty',
          onAction: _noop,
        ),
        const SizedBox(height: AppSpacing.md),
        FFErrorBanner(message: 'Couldn’t load your notes.', onRetry: _noop),
        const SizedBox(height: AppSpacing.md),
        const SizedBox(height: 90, child: FFLoadingView(message: 'Loading…')),
      ],
    );
  }
}

class _EmptyDemo extends StatelessWidget {
  const _EmptyDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FFEmptyState(
          colors: ModuleStyle.reminders.colors,
          icon: ModuleStyle.reminders.icon,
          title: 'All clear for today',
          body:
              'No reminders scheduled. Add one and we’ll nudge you at the '
              'right moment — even offline.',
          ctaLabel: 'Add a reminder',
          onCta: _noop,
          hint: 'Try: "Remind me to stretch every 2 hours"',
          onHint: _noop,
        ),
        const SizedBox(height: AppSpacing.lg),
        FFCard(
          child: FFEmptyState.compact(
            colors: ModuleStyle.tasks.colors,
            icon: ModuleStyle.tasks.icon,
            title: 'No tasks today',
            body: 'Enjoy the calm, or plan tomorrow.',
            ctaLabel: 'Add task',
            onCta: _noop,
          ),
        ),
      ],
    );
  }
}

class _SkeletonDemo extends StatelessWidget {
  const _SkeletonDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        FFSkeletonList(count: 2),
        SizedBox(height: AppSpacing.md),
        FFSkeletonList(count: 3, kind: FFSkeletonKind.row),
      ],
    );
  }
}

class _ActionSheetDemo extends StatelessWidget {
  const _ActionSheetDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSecondaryButton(
          label: 'Open item actions',
          onPressed: () => showFFActionSheet(context, demoActionSheetData()),
        ),
        const SizedBox(height: AppSpacing.sm),
        FFSecondaryButton(
          label: 'Open multi-select actions',
          variant: FFSecondaryVariant.outlined,
          onPressed: () => showFFActionSheet(
            context,
            FFActionSheetData(
              header: const FFActionSheetHeader.selection(3),
              actions: [
                FFActionItem(
                  icon: FontAwesomeIcons.tag,
                  label: 'Edit tags',
                  colors: TagPalette.travel,
                  onTap: _noop,
                ),
              ],
              onArchive: _noop,
              onDelete: _noop,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FFSecondaryButton(
          label: 'Open plain bottom sheet',
          variant: FFSecondaryVariant.surface,
          onPressed: () => showFFBottomSheet<void>(
            context,
            builder: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What’s next?',
                  textAlign: TextAlign.center,
                  style: ctx.text.title,
                ),
                const SizedBox(height: AppSpacing.lg),
                const FFSearchField(hint: 'Try “Pay rent tomorrow 9am”'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FFActionSheet(data: demoActionSheetData()),
      ],
    );
  }
}

class _DialogDemo extends StatelessWidget {
  const _DialogDemo();

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFDialog(
          icon: FontAwesomeIcons.trashCan,
          iconColor: ff.danger,
          iconBackground: ff.dangerSoft,
          title: 'Delete 2 notes?',
          message:
              'They’ll move to Recently Deleted and be removed permanently '
              'after 30 days.',
          actions: [
            FFDangerButton(label: 'Delete', onPressed: _noop),
            FFSecondaryButton(label: 'Archive instead', onPressed: _noop),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            FFTextButton(
              label: 'confirmDelete',
              onPressed: () => confirmDelete(context, count: 2, noun: 'note'),
            ),
            FFTextButton(
              label: 'Delete forever',
              onPressed: () => confirmDelete(
                context,
                count: 1,
                noun: 'note',
                permanent: true,
              ),
            ),
            FFTextButton(
              label: 'showFFConfirm',
              onPressed: () => showFFConfirm(
                context,
                title: 'Discard changes?',
                message: 'Your edits to this note will be lost.',
                confirmLabel: 'Discard',
                destructive: true,
              ),
            ),
            FFTextButton(
              label: 'showFFTextConfirm',
              onPressed: () => showFFTextConfirm(
                context,
                title: 'Erase all data?',
                message: 'Everything on this device will be removed.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SnackbarDemo extends StatelessWidget {
  const _SnackbarDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSnackbar(
          message: '"Shopping List" archived',
          icon: FontAwesomeIcons.boxArchive,
          actionLabel: 'Undo',
          onAction: _noop,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            FFTextButton(
              label: 'Undo snackbar',
              onPressed: () => showUndoSnackbar(
                context,
                message: '"Shopping List" archived',
                icon: FontAwesomeIcons.boxArchive,
                onUndo: _noop,
              ),
            ),
            FFTextButton(
              label: 'Toast',
              onPressed: () => showFFToast(
                context,
                'Copied to clipboard',
                icon: FontAwesomeIcons.solidCopy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomNavDemo extends StatelessWidget {
  const _BottomNavDemo();

  @override
  Widget build(BuildContext context) {
    return GalleryState<int>(
      initial: 1,
      builder: (context, i, set) => MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: FFBottomNav(currentIndex: i, onTap: set, onFab: _noop),
      ),
    );
  }
}

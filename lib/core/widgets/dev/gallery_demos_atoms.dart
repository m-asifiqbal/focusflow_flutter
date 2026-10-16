/// ============================================================
/// GALLERY DEMOS · ATOMS — headers, buttons, inputs, chips, tiles, rings
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

List<GalleryDemo> get atomDemos => [
  GalleryDemo('FFLargeHeader', (_) => const _LargeHeaderDemo()),
  GalleryDemo('FFNavHeader', (_) => const _NavHeaderDemo()),
  GalleryDemo('FFRoundIconButton', (_) => const _RoundButtonsDemo()),
  GalleryDemo('FFSearchField', (_) => const _SearchDemo()),
  GalleryDemo('FFChipBar', (_) => const _ChipsDemo()),
  GalleryDemo('Buttons', (_) => const _ButtonsDemo()),
  GalleryDemo('FFIconTile', (_) => const _TilesDemo()),
  GalleryDemo('FFTag · FFBadge · FFDot', (_) => const _TagsDemo()),
  GalleryDemo('FFSwitch · FFCheckCircle', (_) => const _ControlsDemo()),
  GalleryDemo('FFProgressRing', (_) => const _RingsDemo()),
  GalleryDemo('FFSegmented', (_) => const _SegmentedDemo()),
  GalleryDemo('FFAvatar · FFColorSwatchRow', (_) => const _AvatarDemo()),
  GalleryDemo('FFHighlightedText', (_) => const _HighlightDemo()),
  GalleryDemo('Section headers', (_) => const _SectionDemo()),
];

void _noop() {}

class _LargeHeaderDemo extends StatelessWidget {
  const _LargeHeaderDemo();

  @override
  Widget build(BuildContext context) {
    return FFLargeHeader(
      title: 'Notes',
      subtitle: '48 notes · 3 pinned',
      padding: EdgeInsetsDirectional.zero,
      actions: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.tableCellsLarge,
          semanticLabel: 'Grid view',
          onPressed: _noop,
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.ellipsis,
          semanticLabel: 'More',
          onPressed: _noop,
        ),
      ],
    );
  }
}

class _NavHeaderDemo extends StatelessWidget {
  const _NavHeaderDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FFNavHeader(
          padding: EdgeInsetsDirectional.zero,
          leading: FFBackButton(onPressed: _noop),
          title: 'Ideas',
          subtitle: 'Auto-saved',
          subtitleIcon: FontAwesomeIcons.cloudArrowUp,
          trailing: [
            FFRoundIconButton(
              icon: FontAwesomeIcons.thumbtack,
              semanticLabel: 'Pin',
              onPressed: _noop,
            ),
            FFRoundIconButton(
              icon: FontAwesomeIcons.ellipsis,
              semanticLabel: 'More',
              onPressed: _noop,
            ),
          ],
        ),
        FFNavHeader(
          padding: EdgeInsetsDirectional.zero,
          leading: FFNavAction(label: 'Cancel', onPressed: _noop),
          title: 'Edit Task',
          trailing: [
            FFNavAction(
              label: 'Save',
              onPressed: _noop,
              emphasized: true,
              enabled: false,
            ),
          ],
        ),
        FFNavHeader(
          padding: EdgeInsetsDirectional.zero,
          leading: FFBackButton(label: 'Settings', onPressed: _noop),
          title: 'Notifications',
        ),
      ],
    );
  }
}

class _RoundButtonsDemo extends StatelessWidget {
  const _RoundButtonsDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.magnifyingGlass,
          semanticLabel: 'Search',
          onPressed: _noop,
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.solidBell,
          semanticLabel: 'Notifications',
          badge: true,
          onPressed: _noop,
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.plus,
          semanticLabel: 'Add',
          variant: FFRoundIconButtonVariant.accent,
          onPressed: _noop,
        ),
        _VaultBox(
          child: FFRoundIconButton(
            icon: FontAwesomeIcons.lock,
            semanticLabel: 'Lock vault',
            variant: FFRoundIconButtonVariant.dark,
            onPressed: _noop,
          ),
        ),
      ],
    );
  }
}

class _SearchDemo extends StatelessWidget {
  const _SearchDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FFSearchField(
          hint: 'Search notes…',
          onFilter: _noop,
          filterActive: true,
        ),
        const SizedBox(height: AppSpacing.md),
        FFSearchField(hint: 'Search everything', readOnly: true, onTap: _noop),
        const SizedBox(height: AppSpacing.md),
        _VaultBox(
          child: FFSearchField(
            hint: 'Search 24 accounts…',
            vault: true,
            trailing: Icon(
              FontAwesomeIcons.lock,
              size: 15,
              color: context.ff.vaultAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipsDemo extends StatelessWidget {
  const _ChipsDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryState<String>(
          initial: 'all',
          builder: (context, value, set) => FFChipBar<String>(
            padding: EdgeInsetsDirectional.zero,
            selected: value,
            onSelected: set,
            items: const [
              FFChipItem(value: 'all', label: 'All', count: 37),
              FFChipItem(
                value: 'notes',
                label: 'Notes',
                icon: FontAwesomeIcons.solidNoteSticky,
                count: 15,
              ),
              FFChipItem(value: 'work', label: 'Work'),
              FFChipItem(value: 'personal', label: 'Personal'),
              FFChipItem(value: 'travel', label: 'Travel'),
            ],
          ),
        ),
        GalleryState<int>(
          initial: 0,
          builder: (context, value, set) => FFChipBar<int>(
            padding: EdgeInsetsDirectional.zero,
            selected: value,
            onSelected: set,
            items: [
              FFChipItem(
                value: 0,
                label: 'Today',
                icon: FontAwesomeIcons.solidSun,
                activeColor: ModuleStyle.reminders.solid,
              ),
              const FFChipItem(
                value: 1,
                label: 'Upcoming',
                icon: FontAwesomeIcons.solidCalendar,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ButtonsDemo extends StatelessWidget {
  const _ButtonsDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFPrimaryButton(
          label: 'Add a reminder',
          icon: FontAwesomeIcons.plus,
          onPressed: _noop,
        ),
        const SizedBox(height: AppSpacing.md),
        const FFPrimaryButton(label: 'Saving', onPressed: null, loading: true),
        const SizedBox(height: AppSpacing.md),
        const FFPrimaryButton(label: 'Disabled', onPressed: null),
        const SizedBox(height: AppSpacing.md),
        FFSecondaryButton(label: 'Archive instead', onPressed: _noop),
        const SizedBox(height: AppSpacing.md),
        FFSecondaryButton(
          label: 'Restore all',
          icon: FontAwesomeIcons.boxOpen,
          variant: FFSecondaryVariant.surface,
          onPressed: _noop,
        ),
        const SizedBox(height: AppSpacing.md),
        FFSecondaryButton(
          label: 'Outlined',
          variant: FFSecondaryVariant.outlined,
          onPressed: _noop,
        ),
        const SizedBox(height: AppSpacing.md),
        FFDangerButton(label: 'Delete', onPressed: _noop),
        const SizedBox(height: AppSpacing.md),
        FFSoftDangerButton(
          label: 'Delete all',
          icon: FontAwesomeIcons.trashCan,
          onPressed: _noop,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            FFTextButton(label: 'View Monthly', onPressed: _noop),
            FFTextButton(label: 'Disabled', onPressed: null),
          ],
        ),
      ],
    );
  }
}

class _TilesDemo extends StatelessWidget {
  const _TilesDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final m in AppModule.values)
          FFIconTile(
            icon: ModuleStyle.of(m).icon,
            colors: ModuleStyle.of(m).colors,
          ),
        FFIconTile.soft(
          icon: ModuleStyle.tasks.icon,
          colors: ModuleStyle.tasks.colors,
          size: 46,
        ),
        FFIconTile(
          icon: FontAwesomeIcons.thumbtack,
          colors: ModuleStyle.notes.colors,
          style: FFIconTileStyle.tint,
        ),
        FFIconTile(
          icon: ModuleStyle.vault.icon,
          colors: ModuleStyle.vault.colors,
          size: 64,
        ),
        FFIconTile(
          icon: FontAwesomeIcons.globe,
          colors: TagPalette.travel,
          size: 32,
        ),
      ],
    );
  }
}

class _TagsDemo extends StatelessWidget {
  const _TagsDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const FFTag('Work'),
        const FFTag('Finance'),
        const FFTag('Personal'),
        const FFTag('High'),
        const FFTag('Groceries'),
        const FFBadge('3 left'),
        const FFBadge('Strong', colors: TagPalette.ideas),
        const FFBadge('Breached', colors: TagPalette.high),
        FFBadge('Connected', icon: FontAwesomeIcons.check),
        const FFDot(),
        FFDot(color: ModuleStyle.reminders.solid, size: 8),
      ],
    );
  }
}

class _ControlsDemo extends StatelessWidget {
  const _ControlsDemo();

  @override
  Widget build(BuildContext context) {
    return GalleryState<bool>(
      initial: true,
      builder: (context, on, set) => Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FFSwitch(value: on, onChanged: set, semanticLabel: 'Demo switch'),
          FFSwitch(value: !on, onChanged: (v) => set(!v)),
          FFCheckCircle(
            checked: on,
            onChanged: set,
            semanticLabel: 'Complete task',
          ),
          FFCheckCircle(
            checked: !on,
            onChanged: (v) => set(!v),
            color: ModuleStyle.tasks.solid,
          ),
        ],
      ),
    );
  }
}

class _RingsDemo extends StatelessWidget {
  const _RingsDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      children: [
        FFProgressRing(
          progress: 0.75,
          color: ModuleStyle.tasks.solid,
          child: Icon(
            FontAwesomeIcons.droplet,
            size: 18,
            color: ModuleStyle.tasks.solid,
          ),
        ),
        FFProgressRing(
          progress: 1,
          color: ModuleStyle.notes.solid,
          child: Icon(
            FontAwesomeIcons.bookOpen,
            size: 18,
            color: ModuleStyle.notes.solid,
          ),
        ),
        FFProgressRing(
          progress: 0.4,
          size: 96,
          stroke: 9,
          child: Text('40%', style: context.text.stat),
        ),
      ],
    );
  }
}

class _SegmentedDemo extends StatelessWidget {
  const _SegmentedDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GalleryState<int>(
          initial: 1,
          builder: (context, v, set) => FFSegmented<int>(
            value: v,
            onChanged: set,
            segments: const [
              FFSegment(value: 0, label: 'Week'),
              FFSegment(value: 1, label: 'Month'),
              FFSegment(value: 2, label: 'Agenda'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _VaultBox(
          child: GalleryState<int>(
            initial: 0,
            builder: (context, v, set) => FFSegmented<int>(
              value: v,
              onChanged: set,
              vault: true,
              segments: const [
                FFSegment(value: 0, label: 'Password'),
                FFSegment(value: 1, label: 'Passphrase'),
                FFSegment(value: 2, label: 'PIN'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarDemo extends StatelessWidget {
  const _AvatarDemo();

  @override
  Widget build(BuildContext context) {
    final colors = [for (final h in NoteColors.hexes) parseHex(h)!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FFAvatar(initial: 'Asif', semanticLabel: 'Profile', onTap: _noop),
            const SizedBox(width: AppSpacing.md),
            const FFAvatar(initial: 'B', size: 64),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GalleryState<Color?>(
          initial: colors[1],
          builder: (context, v, set) => FFColorSwatchRow(
            colors: colors,
            selected: v,
            onSelected: set,
            labels: const ['White', 'Mint', 'Amber', 'Blue', 'Pink', 'Violet'],
          ),
        ),
      ],
    );
  }
}

class _HighlightDemo extends StatelessWidget {
  const _HighlightDemo();

  @override
  Widget build(BuildContext context) {
    return FFHighlightedText(
      'Mobile app design trends: minimalism and organic shapes',
      query: 'design shapes',
      style: context.text.body.copyWith(color: context.ff.ink),
      maxLines: 2,
    );
  }
}

class _SectionDemo extends StatelessWidget {
  const _SectionDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FFSectionHeader(
          title: 'Up Next',
          actionLabel: 'All Reminders',
          onAction: _noop,
        ),
        const FFSectionHeader(
          title: 'Today’s Tasks',
          trailing: FFBadge('3 left'),
        ),
        const SizedBox(height: AppSpacing.md),
        FFSectionLabel(
          'Overdue · 2',
          actionLabel: 'Reschedule all',
          actionColor: context.ff.danger,
          onAction: _noop,
        ),
        const FFSectionLabel('Collections'),
        const FFDividerInset(indent: 0),
      ],
    );
  }
}

/// Dark vault canvas behind vault-variant demos.
class _VaultBox extends StatelessWidget {
  const _VaultBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return VaultTheme(
      child: Builder(
        builder: (context) => DecoratedBox(
          decoration: BoxDecoration(
            color: context.ff.vaultCanvas,
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

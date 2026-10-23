/// ============================================================
/// IMPORT REVIEW WIDGETS — preview, progress and summary of an import
/// ============================================================
///
/// * [ImportPreviewView] — what the file holds, at a glance: the total, a
///   composition bar split by module colour (Notes green, Tasks blue,
///   Reminders orange, Habits indigo, Medicines pink, Vault amber), legend
///   chips, then one row per module with its own share bar; skipped rows
///   in an amber banner.
/// * [ImportProgressView] — the live count and an animated bar.
/// * [ImportSummaryView] — coloured result tiles (imported green,
///   duplicates amber, failed red) over a stacked result bar, then what
///   couldn't be imported.
/// Bars grow in (instant with reduce motion); colours are module / status
/// tokens, so dark mode works for free.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';

/// One kind of item in the file: colours/icon, label, count.
typedef ImportPart = (ModuleStyle, String, int);

/// A rounded bar made of coloured segments that grow in from the start.
class ImportSegmentBar extends StatelessWidget {
  const ImportSegmentBar({
    required this.segments,
    this.height = AppSpacing.md,
    super.key,
  });

  /// (colour, weight); zero weights are left out.
  final List<(Color, int)> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (final s in segments)
        if (s.$2 > 0) s,
    ];
    if (parts.isEmpty) return SizedBox(height: height);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
      duration: context.motion(AppMotion.slow * 3),
      curve: AppMotion.curve,
      builder: (context, t, _) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: SizedBox(
          height: height,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: t,
              // Full height: the segments are empty boxes.
              heightFactor: 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (color, weight)) in parts.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      flex: weight,
                      child: ColoredBox(color: color),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ImportPreviewView extends StatelessWidget {
  const ImportPreviewView({
    required this.source,
    required this.fileName,
    required this.parts,
    required this.total,
    required this.problems,
    required this.hasLogins,
    required this.isBackup,
    required this.onImport,
    required this.onCancel,
    super.key,
  });

  final String source;
  final String? fileName;
  final List<ImportPart> parts;
  final int total;
  final List<String> problems;
  final bool hasLogins;
  final bool isBackup;
  final VoidCallback onImport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final shown = [
      for (final p in parts)
        if (p.$3 > 0) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFCard(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FFIconTile(
                    icon: FontAwesomeIcons.fileImport,
                    colors: ModuleStyle.notes.colors,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Detected · {source}', {'source': source}),
                          style: context.text.cardTitle,
                        ),
                        if (fileName != null)
                          Text(
                            fileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.meta,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TweenAnimationBuilder<double>(
                tween: Tween(end: total.toDouble()),
                duration: context.motion(AppMotion.slow * 3),
                builder: (context, v, _) => Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${v.round()} ',
                        style: context.text.bigStat,
                      ),
                      TextSpan(
                        text: tr(
                          '{count, plural, one {item found} other {items found}}',
                          {'count': total},
                        ),
                        style: context.text.body.copyWith(color: ff.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ImportSegmentBar(
                segments: [for (final (s, _, n) in shown) (s.solid, n)],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (s, label, n) in shown)
                    _Chip(color: s.solid, text: '$label · $n'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        FFGroupedList(
          label: tr('What will be imported'),
          children: [
            for (final (style, label, n) in shown)
              FFListRow(
                leading: FFIconTile(
                  icon: style.icon,
                  colors: style.colors,
                  size: AppSizes.iconTileSm,
                ),
                title: label,
                subtitle: total == 0
                    ? null
                    : tr('{percent} of the file', {
                        'percent': '${(n * 100 / total).round()}%',
                      }),
                trailing: _CountPill(color: style.solid, count: n),
              ),
          ],
        ),
        if (problems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          FFInfoBanner(
            icon: FontAwesomeIcons.triangleExclamation,
            colors: ModuleStyle.vault.colors,
            text: [
              tr(
                '{count, plural, one {# row will be skipped:} other {# rows will be skipped:}}',
                {'count': problems.length},
              ),
              ...problems.take(4),
            ].join('\n'),
          ),
        ],
        if (!isBackup) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                FontAwesomeIcons.circleInfo,
                size: AppSpacing.md,
                color: ff.inkFaint,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tr(
                    'Items you already have (same title and date) are skipped.',
                  ),
                  style: context.text.caption,
                ),
              ),
            ],
          ),
        ],
        if (hasLogins) ...[
          const SizedBox(height: AppSpacing.lg),
          FFInfoBanner(
            icon: FontAwesomeIcons.lock,
            text: tr(
              'Passwords are encrypted into your vault as they are imported. Delete the CSV file afterwards.',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FFPrimaryButton(
          label: isBackup
              ? tr('Restore {total} items…', {'total': total})
              : tr('Import {count, plural, one {# item} other {# items}}', {
                  'count': total,
                }),
          icon: FontAwesomeIcons.fileImport,
          onPressed: total == 0 ? null : onImport,
        ),
        const SizedBox(height: AppSpacing.sm),
        FFTextButton(label: tr('Cancel'), onPressed: onCancel),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
        Text(
          text,
          style: context.text.caption.copyWith(
            color: context.ff.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(
      minWidth: AppSpacing.xxxl + AppSpacing.sm,
    ),
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      style: context.text.buttonSmall.copyWith(color: context.ff.onPrimary),
    ),
  );
}

class ImportProgressView extends StatelessWidget {
  const ImportProgressView({
    required this.progress,
    required this.total,
    super.key,
  });

  /// 0–1.
  final double progress;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final done = (progress * total).round();
    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Importing {done} of {total}…', {
                      'done': done,
                      'total': total,
                    }),
                    style: context.text.cardTitle,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: context.text.rowTitle.copyWith(
                    color: ff.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: context.motion(AppMotion.normal),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: AppSpacing.sm,
                  color: ff.primary,
                  backgroundColor: ff.divider,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImportSummaryView extends StatelessWidget {
  const ImportSummaryView({
    required this.imported,
    required this.duplicates,
    required this.failed,
    required this.failures,
    required this.title,
    required this.message,
    required this.notice,
    required this.onDone,
    super.key,
  });

  /// Null for a restore (no counts, just [message]).
  final int? imported;
  final int duplicates;
  final int failed;
  final List<String> failures;
  final String title;
  final String? message;
  final String? notice;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final ok = failed == 0;
    final counts = imported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFCard(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Column(
            children: [
              FFIconTile(
                icon: ok
                    ? FontAwesomeIcons.check
                    : FontAwesomeIcons.triangleExclamation,
                colors: ok
                    ? ModuleStyle.notes.colors
                    : ModuleStyle.vault.colors,
                size: AppSizes.iconTileLg,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: context.text.sectionTitle,
                textAlign: TextAlign.center,
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ],
              if (counts != null) ...[
                const SizedBox(height: AppSpacing.lg),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Result(
                        color: ff.success,
                        icon: FontAwesomeIcons.check,
                        count: counts,
                        label: tr('Imported'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _Result(
                        color: ff.warning,
                        icon: FontAwesomeIcons.clone,
                        count: duplicates,
                        label: tr('Already had'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _Result(
                        color: ff.danger,
                        icon: FontAwesomeIcons.xmark,
                        count: failed,
                        label: tr('Failed'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ImportSegmentBar(
                  height: AppSpacing.sm,
                  segments: [
                    (ff.success, counts),
                    (ff.warning, duplicates),
                    (ff.danger, failed),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (notice case final n?) ...[
          const SizedBox(height: AppSpacing.lg),
          FFInfoBanner(icon: FontAwesomeIcons.circleInfo, text: n),
        ],
        if (failures.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          FFGroupedList(
            label: tr('Couldn\'t import'),
            children: [
              for (final f in failures.take(20))
                FFListRow(
                  title: f,
                  leading: FFIconTile.soft(
                    icon: FontAwesomeIcons.xmark,
                    colors: ModuleStyle.scan.colors,
                    size: AppSizes.iconTileSm,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FFSecondaryButton(label: tr('Done'), onPressed: onDone),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.color,
    required this.icon,
    required this.count,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label: $count',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Column(
          children: [
            Icon(icon, size: AppSpacing.lg, color: color),
            const SizedBox(height: AppSpacing.xs),
            TweenAnimationBuilder<double>(
              tween: Tween(end: count.toDouble()),
              duration: context.motion(AppMotion.slow * 3),
              builder: (_, v, _) => Text(
                '${v.round()}',
                style: context.text.stat.copyWith(color: context.ff.ink),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: context.text.caption,
            ),
          ],
        ),
      ),
    ),
  );
}

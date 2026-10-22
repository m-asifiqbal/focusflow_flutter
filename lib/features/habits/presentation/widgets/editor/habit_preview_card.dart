/// ============================================================
/// HABIT PREVIEW CARD + QUICK START — top of the habit editor (mockup 15)
/// ============================================================
///
/// [HabitPreviewCard]: the draft as it will look — 64-pt soft icon tile
/// (tap → Customize Habit sheet), name, category tag and goal
/// ("• 8 glasses daily"). [HabitTemplateStrip]: the horizontally
/// scrolling QUICK START tiles (92 pt wide) that fill every field.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/services/habit_words.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/habit_templates.dart';

class HabitPreviewCard extends StatelessWidget {
  const HabitPreviewCard({
    required this.draft,
    required this.onCustomize,
    super.key,
  });

  final Habit draft;

  /// Opens the icon & colour sheet.
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final name = draft.name.trim();
    return FFCard(
      padding: const EdgeInsetsDirectional.all(HabitDimens.previewPadding),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: tr('Change icon and colour'),
            excludeSemantics: true,
            child: FFPressable(
              onTap: onCustomize,
              child: FFIconTile.soft(
                icon: HabitIcons.of(draft.iconKey),
                colors: draft.colors,
                size: HabitDimens.previewTile,
                radius: HabitDimens.previewRadius,
                iconSize: HabitDimens.previewIcon,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg + AppSpacing.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? tr('New habit') : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.title.copyWith(
                    fontSize: HabitDimens.previewName,
                    color: name.isEmpty ? ff.inkFaint : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FFTag(
                      HabitWords.shown(draft.category),
                      colors: HabitCategories.colorsOf(draft.category),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FFDot(color: ff.inkFaint, size: AppSpacing.xs + 1),
                        const SizedBox(width: AppSpacing.xs + 1),
                        Text(
                          draft.goalLabel,
                          style: context.text.bodySmall.copyWith(
                            color: ff.inkFaint,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HabitTemplateStrip extends StatelessWidget {
  const HabitTemplateStrip({required this.onTemplate, super.key});

  final ValueChanged<HabitTemplate> onTemplate;

  @override
  Widget build(BuildContext context) {
    // `all` is built per call (names follow the language): hold one list.
    final templates = HabitTemplates.all;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.grouped,
      ),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, t) in templates.indexed) ...[
            if (i > 0) const SizedBox(width: HabitDimens.templateGap),
            _TemplateTile(template: t, onTap: () => onTemplate(t)),
          ],
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});

  final HabitTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: HabitDimens.templateTile,
      child: FFCard(
        onTap: onTap,
        semanticLabel: tr('Use template {label}', {'label': template.label}),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md + AppSpacing.xxs,
        ),
        child: Column(
          children: [
            FFIconTile.soft(
              icon: HabitIcons.of(template.iconKey),
              colors: template.colors,
              size: HabitDimens.templateIcon,
              radius: AppRadii.tile,
              iconSize: HabitDimens.templateIconSize,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              template.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.rowTitle.copyWith(
                fontSize: HabitDimens.templateLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// QUICK CAPTURE PREVIEW ROW — "Reminder · Tomorrow 09:00 AM · #home"
/// ============================================================
///
/// What: the parsed-preview chips under the capture field: the kind in its
/// module colours, then when / repeat / priority as neutral pills and tags
/// as [FFTag]s. Wraps onto more lines at large text sizes.
/// Why: the user sees what will be created before the editor opens.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';
import 'package:focusflow/features/quick_add/domain/services/quick_capture_preview.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class QuickCapturePreviewRow extends ConsumerWidget {
  const QuickCapturePreviewRow({required this.capture, super.key});

  final QuickCapture capture;

  static ModuleStyle styleOf(QuickCaptureKind kind) => switch (kind) {
    QuickCaptureKind.note => ItemType.note.style,
    QuickCaptureKind.task => ItemType.task.style,
    QuickCaptureKind.reminder => ItemType.reminder.style,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final now = ref.watch(clockProvider).now();
    final parts = QuickCapturePreview.parts(capture, now, use24h: use24h);
    final module = styleOf(capture.kind);
    return Semantics(
      liveRegion: true,
      label:
          'Will create: '
          '${QuickCapturePreview.summary(capture, now, use24h: use24h)}',
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.xs + AppSpacing.xxs,
        runSpacing: AppSpacing.xs + AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final part in parts)
            switch (part.kind) {
              QuickCapturePartKind.kind => _Pill(
                label: part.label,
                icon: module.icon,
                colors: module.colors,
              ),
              QuickCapturePartKind.tag => FFTag(part.label, uppercase: false),
              QuickCapturePartKind.when => _Pill(
                label: part.label,
                icon: FontAwesomeIcons.solidCalendar,
              ),
              QuickCapturePartKind.repeat => _Pill(
                label: part.label,
                icon: FontAwesomeIcons.repeat,
              ),
              QuickCapturePartKind.priority => _Pill(
                label: part.label,
                icon: FontAwesomeIcons.solidFlag,
              ),
            },
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, this.colors});

  final String label;
  final IconData icon;

  /// Module colours for the kind pill; neutral otherwise.
  final ModuleColors? colors;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final b = Theme.of(context).brightness;
    final bg = colors?.softFor(b) ?? ff.surface;
    final fg = colors?.inkFor(b) ?? ff.inkMuted;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
        vertical: AppSpacing.xs + AppSpacing.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: colors == null ? Border.all(color: ff.chipBorder) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.tileGlyph - 3, color: fg),
          const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.meta.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// NOTE CARD PARTS — the small pieces of a notes-list card (screen 07)
/// ============================================================
///
/// What: card text styles, the tilted pin mark, the checklist preview
/// (filled emerald box + strike-through for done lines), the cover image,
/// the blurred placeholder of a locked note and the multi-select circle.
/// Why: shared by the masonry card and the compact list row, and kept out
/// of note_card.dart so each file stays small. A locked note never renders
/// its real text — the blur is drawn over fixed placeholder bars.
/// ============================================================
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_metrics.dart';

/// Text styles of the note card, derived from the design-system tokens
/// (sizes measured against design/07_notes_list.png).
abstract final class NoteCardText {
  /// Title — 15.5 w600 heading font.
  static TextStyle title(BuildContext context) =>
      context.text.cardTitle.copyWith(height: NoteCardMetrics.titleLineHeight);

  /// Preview — body font, muted, max 6 lines (12 pt on a 17.2 pt line,
  /// measured against the mockup).
  static TextStyle preview(BuildContext context) =>
      context.text.bodySmall.copyWith(
        fontSize: NoteCardMetrics.previewSize,
        height: NoteCardMetrics.previewLineHeight,
      );

  /// "TODAY · IDEAS".
  static TextStyle footer(BuildContext context) =>
      context.text.sectionLabel.copyWith(
        fontSize: NoteCardMetrics.footerSize,
        letterSpacing: NoteCardMetrics.footerLetterSpacing,
      );

  /// Checklist preview lines — open items a touch darker than the preview
  /// text (mockup: ink at ~60 %).
  static TextStyle checklist(BuildContext context) {
    final ff = context.ff;
    return context.text.bodySmall.copyWith(
      color: Color.lerp(ff.inkMuted, ff.ink, 0.15),
      fontSize: NoteCardMetrics.checklistSize,
      height: NoteCardMetrics.checklistLineHeight,
    );
  }
}

/// The emerald thumbtack of a pinned note (tilted, as in the mockup).
class NotePinMark extends StatelessWidget {
  const NotePinMark({this.size = NoteCardMetrics.pinMark, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Pinned',
    child: Transform.rotate(
      angle: math.pi / 5,
      child: Icon(
        FontAwesomeIcons.thumbtack,
        size: size,
        color: context.ff.primary,
      ),
    ),
  );
}

/// The lock of a note locked with the Vault PIN.
class NoteLockMark extends StatelessWidget {
  const NoteLockMark({this.size = NoteCardMetrics.lockMark, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Locked',
    child: Icon(FontAwesomeIcons.lock, size: size, color: context.ff.inkMuted),
  );
}

/// Up to [max] checklist lines with square checkboxes.
class NoteChecklistPreview extends StatelessWidget {
  const NoteChecklistPreview({required this.items, this.max = 4, super.key});

  final List<ChecklistItem> items;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = NoteCardText.checklist(context);
    final shown = items.take(max).toList();
    final more = items.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in shown)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs + 2),
            // Inline checkbox: a wrapped line flows back under the box, as
            // in the mockup ("Organic coffee / beans").
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: _CheckBox(done: item.done),
                    ),
                  ),
                  TextSpan(text: item.text),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: item.done
                  ? style.copyWith(
                      color: ff.inkFaint,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: ff.inkFaint,
                    )
                  : style,
            ),
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
            child: Text('+$more more', style: context.text.meta),
          ),
      ],
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const size = NoteCardMetrics.checkBox;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: done ? ff.primary : null,
        borderRadius: BorderRadius.circular(NoteCardMetrics.checkBoxRadius),
        border: done
            ? null
            : Border.all(
                color: ff.inkMuted,
                width: NoteCardMetrics.checkBoxBorder,
              ),
      ),
      child: done
          ? Icon(
              FontAwesomeIcons.check,
              size: NoteCardMetrics.checkGlyph,
              color: ff.onPrimary,
            )
          : null,
    );
  }
}

/// The note's cover image (relative path in app documents), 96 pt tall.
/// Renders nothing while the store loads or when the file is missing.
class NoteCover extends ConsumerWidget {
  const NoteCover({required this.path, this.height = 96, super.key});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(noteFileStoreProvider).valueOrNull?.resolve(path);
    if (file == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.statTile),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
              .round(),
          errorBuilder: (context, _, _) =>
              ColoredBox(color: context.ff.surfaceMuted),
        ),
      ),
    );
  }
}

/// Blurred placeholder lines of a locked note (no real content).
class NoteLockedPreview extends StatelessWidget {
  const NoteLockedPreview({this.lines = 3, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final color = context.ff.inkMuted.withValues(alpha: 0.35);
    return Semantics(
      label: 'Preview hidden — locked with Vault PIN',
      child: ExcludeSemantics(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: NoteCardMetrics.lockedBlurSigma,
            sigmaY: NoteCardMetrics.lockedBlurSigma,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
                  child: FractionallySizedBox(
                    widthFactor: i == lines - 1 ? 0.55 : 0.92,
                    child: Container(
                      height: NoteCardMetrics.lockedBarHeight,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top-right selection circle of multi-select mode.
class NoteSelectMark extends StatelessWidget {
  const NoteSelectMark({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const size = NoteCardMetrics.selectMark;
    return AnimatedContainer(
      duration: context.reduceMotion ? Duration.zero : AppMotion.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? ff.primary : ff.surface,
        border: Border.all(
          color: selected ? ff.primary : ff.inkFaint,
          width: NoteCardMetrics.selectBorder,
        ),
      ),
      child: selected
          ? Icon(
              FontAwesomeIcons.check,
              size: NoteCardMetrics.selectGlyph,
              color: ff.onPrimary,
            )
          : null,
    );
  }
}

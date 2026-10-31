/// ============================================================
/// NOTE PAPER — lined / grid paper behind the note body
/// ============================================================
///
/// What: [NotePaperBackground] draws the note's [NotePaper] behind the
/// editor body: rules one body line apart, sitting just under each line's
/// baseline (lined), or the same rows plus columns of the same pitch
/// (grid). The ruling fills the body's height, below the last line too.
/// The editor's styles go "ruled" at the same time ([noteQuillStyles]), so
/// the text stays on the rows. [showNotePaperPicker] is the Paper sheet of
/// the note's More menu.
/// Why: a static CustomPaint under its own repaint boundary — typing
/// repaints the text, never the paper.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_quill_styles.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

class NotePaperBackground extends StatelessWidget {
  const NotePaperBackground({
    required this.paper,
    required this.child,
    super.key,
  });

  final NotePaper paper;
  final Widget child;

  /// Where a rule sits within its row (just under the baseline of 18/1.65
  /// Nunito, so descenders cross it like on paper).
  static const double baseline = 0.86;

  @override
  Widget build(BuildContext context) {
    if (paper == NotePaper.plain) return child;
    final ff = context.ff;
    // The row follows the text scale, like the text itself.
    final row =
        MediaQuery.textScalerOf(context).scale(NoteBodyMetrics.fontSize) *
        NoteBodyMetrics.lineHeight;
    return CustomPaint(
      painter: _PaperPainter(
        paper: paper,
        row: row,
        rule: (ff.isDark ? Colors.white : ff.primaryStrong).withValues(
          alpha: ff.isDark ? 0.09 : 0.13,
        ),
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
      child: RepaintBoundary(child: child),
    );
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter({
    required this.paper,
    required this.row,
    required this.rule,
    required this.rtl,
  });

  final NotePaper paper;
  final double row;
  final Color rule;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (row <= 0) return;
    final pen = Paint()
      ..color = rule
      ..strokeWidth = 1;
    final grid = paper == NotePaper.grid;
    // Grid squares are drawn on the row lines' own grid; lined paper puts
    // each rule under its line's baseline.
    final offset = grid ? 0.0 : row * NotePaperBackground.baseline;
    for (var y = offset; y <= size.height; y += row) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
    }
    if (grid) {
      // Columns from the reading start, so the squares line up with the
      // text's starting edge in both directions.
      for (var x = 0.0; x <= size.width; x += row) {
        final at = rtl ? size.width - x : x;
        canvas.drawLine(Offset(at, 0), Offset(at, size.height), pen);
      }
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.paper != paper ||
      old.row != row ||
      old.rule != rule ||
      old.rtl != rtl;
}

/// The Paper sheet: Plain · Lined · Grid; null when dismissed.
Future<NotePaper?> showNotePaperPicker(
  BuildContext context, {
  required NotePaper current,
}) async {
  final colors = ModuleStyle.notes.colors;
  final picked = await showOptionSheet<NotePaper>(
    context,
    title: tr('Paper'),
    subtitle: tr('Lines or a grid behind this note'),
    options: [
      for (final p in NotePaper.values)
        OptionItem(
          value: p,
          label: p.label,
          icon: switch (p) {
            NotePaper.plain => FontAwesomeIcons.file,
            NotePaper.lined => FontAwesomeIcons.alignJustify,
            NotePaper.grid => FontAwesomeIcons.tableCells,
          },
          colors: colors,
        ),
    ],
    selected: current,
    accent: colors.solid,
  );
  return picked?.value;
}

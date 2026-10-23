/// ============================================================
/// NOTE TOOLBAR PARTS — swatch strip, tool cell, Undo, panel toggle
/// ============================================================
///
/// Building blocks of the editor's bottom panel (note_editor_toolbar.dart):
///   * [NoteSwatchStrip] — a sideways-scrolling row of 44-pt swatch cells
///     with a leading label ("COLOUR" / "TEXT"); the selected swatch is
///     scrolled into view when the strip appears, so a colour at the far
///     end is never hidden.
///   * [NoteToolButton] — one formatting glyph (tinted when active), with
///     an optional colour bar under it (the "Text colour" button).
///   * [NoteUndoButton] — "↺ Undo", long-press to redo.
///   * [NotePanelToggle] — the chevron that hides / shows the panel.
/// Every cell is a full 44 × 44 tap target (CLAUDE.md rule 6).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_metrics.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_quill_styles.dart';

/// One swatch of a [NoteSwatchStrip].
class NoteSwatchData {
  const NoteSwatchData({
    required this.id,
    required this.color,
    required this.label,
    this.outlined = false,
    this.glyph,
  });

  /// Stable id (stored hex / text-colour value) — also the widget key.
  final String id;
  final Color color;

  /// Spoken name ("Mint note colour").
  final String label;

  /// Draw a hairline ring (white card / "Default" text colour).
  final bool outlined;

  /// Optional glyph in the circle (the "Default" text colour's "A").
  final IconData? glyph;
}

class NoteSwatchStrip extends StatefulWidget {
  const NoteSwatchStrip({
    required this.label,
    required this.swatches,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// Small caps label before the swatches ("COLOUR").
  final String label;
  final List<NoteSwatchData> swatches;

  /// Id of the selected swatch (null = none).
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<NoteSwatchStrip> createState() => _NoteSwatchStripState();
}

class _NoteSwatchStripState extends State<NoteSwatchStrip> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return SizedBox(
      height: AppSizes.minTap,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md,
                end: AppSpacing.sm,
              ),
              child: ExcludeSemantics(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: context.text.sectionLabel.copyWith(
                    fontSize: NoteEditorMetrics.colourLabelSize,
                  ),
                ),
              ),
            ),
            for (final s in widget.swatches)
              _Swatch(
                key: s.id == widget.selected ? _selectedKey : ValueKey(s.id),
                data: s,
                selected: s.id == widget.selected,
                ring: ff.success,
                hairline: ff.divider,
                onTap: () => widget.onSelect(s.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.data,
    required this.selected,
    required this.ring,
    required this.hairline,
    required this.onTap,
    super.key,
  });

  final NoteSwatchData data;
  final bool selected;
  final Color ring;
  final Color hairline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = NoteEditorMetrics.swatch;
    final glyph = data.glyph;
    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(AppMotion.fast),
              curve: AppMotion.curve,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: data.color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: ring,
                        width: NoteEditorMetrics.swatchSelectedBorder,
                      )
                    : data.outlined
                    ? Border.all(
                        color: hairline,
                        width: NoteEditorMetrics.swatchHairline,
                      )
                    : null,
              ),
              child: glyph == null
                  ? null
                  : Icon(
                      glyph,
                      size: NoteEditorMetrics.swatchGlyph,
                      color: context.ff.surface,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class NoteToolButton extends StatelessWidget {
  const NoteToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.bar,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// Colour bar under the glyph (the current text colour).
  final Color? bar;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final bar = this.bar;
    final glyph = Icon(
      icon,
      size: NoteEditorMetrics.toolIcon,
      color: selected ? ff.success : noteBodyInk(ff),
    );
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          height: AppSizes.minTap,
          child: bar == null
              ? glyph
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    glyph,
                    const SizedBox(height: AppSpacing.xxs),
                    AnimatedContainer(
                      duration: context.motion(AppMotion.fast),
                      width: NoteEditorMetrics.toolIcon,
                      height: NoteEditorMetrics.colourBar,
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class NoteUndoButton extends StatelessWidget {
  const NoteUndoButton({
    required this.canUndo,
    required this.onUndo,
    required this.onRedo,
    super.key,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      enabled: canUndo,
      label: tr('Undo'),
      hint: tr('Long-press to redo'),
      excludeSemantics: true,
      child: FFPressable(
        onTap: canUndo ? onUndo : null,
        onLongPress: onRedo,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTap,
            minWidth: AppSizes.minTap,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
            ),
            child: AnimatedOpacity(
              opacity: canUndo ? 1 : 0.45,
              duration: context.motion(AppMotion.fast),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FontAwesomeIcons.rotateLeft,
                    size: NoteEditorMetrics.undoIcon,
                    color: ff.primary,
                  ),
                  const SizedBox(width: NoteEditorMetrics.undoGap),
                  Text(
                    tr('Undo'),
                    maxLines: 1,
                    style: context.text.rowTitle.copyWith(
                      fontSize: NoteEditorMetrics.undoLabelSize,
                      fontWeight: FontWeight.w800,
                      color: ff.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chevron that hides (down) / shows (up) the formatting panel.
class NotePanelToggle extends StatelessWidget {
  const NotePanelToggle({
    required this.collapsed,
    required this.onTap,
    super.key,
  });

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: collapsed
          ? tr('Show formatting panel')
          : tr('Hide formatting panel'),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: AnimatedRotation(
              turns: collapsed ? 0.5 : 0,
              duration: context.motion(AppMotion.normal),
              curve: AppMotion.curve,
              child: Icon(
                FontAwesomeIcons.chevronDown,
                size: NoteEditorMetrics.toggleIcon,
                color: ff.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

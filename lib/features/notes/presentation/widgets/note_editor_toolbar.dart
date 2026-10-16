/// ============================================================
/// NOTE EDITOR TOOLBAR — colour swatches + Undo, formatting buttons
/// ============================================================
///
/// The rounded bottom panel of screen 08 (sits above the keyboard):
///   row 1  "COLOUR" · white / mint / amber / blue / pink / violet · Undo
///   row 2  Heading · Bold · Italic · Bullets · Checklist · Quote · Image ·
///          Voice
/// Active formats at the cursor are tinted with the accent. Long-press
/// Undo to redo. Callbacks only — the screen applies them to Quill.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_metrics.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_quill_styles.dart';

/// Formatting buttons of the toolbar (Image / Voice are separate actions).
enum NoteFormat {
  heading('Heading', FontAwesomeIcons.heading),
  bold('Bold', FontAwesomeIcons.bold),
  italic('Italic', FontAwesomeIcons.italic),
  bullets('Bullet list', FontAwesomeIcons.listUl),
  checklist('Checklist', FontAwesomeIcons.listCheck),
  quote('Quote', FontAwesomeIcons.quoteLeft);

  const NoteFormat(this.label, this.icon);

  final String label;
  final IconData icon;
}

class NoteEditorToolbar extends StatelessWidget {
  const NoteEditorToolbar({
    required this.colorHex,
    required this.onColor,
    required this.canUndo,
    required this.onUndo,
    required this.onRedo,
    required this.active,
    required this.onFormat,
    required this.onImage,
    required this.onVoice,
    this.listening = false,
    super.key,
  });

  /// Stored note colour (null = white).
  final String? colorHex;
  final ValueChanged<String> onColor;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final Set<NoteFormat> active;
  final ValueChanged<NoteFormat> onFormat;
  final VoidCallback onImage;
  final VoidCallback onVoice;

  /// Dictation running (mic tinted, label "Stop dictation").
  final bool listening;

  static const double radius = 26;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    // The icon row sits just above the home indicator (mockup).
    final bottom = math.max(
      AppSpacing.sm,
      MediaQuery.paddingOf(context).bottom - AppSpacing.lg - AppSpacing.xxs,
    );
    // Room for 8 × 44-pt tool cells; up to 8 pt side inset when it fits.
    final side =
        ((MediaQuery.sizeOf(context).width -
                    NoteFormat.values.length * AppSizes.minTap -
                    2 * AppSizes.minTap) /
                2)
            .clamp(AppSpacing.xs, AppSpacing.sm);
    return Container(
      decoration: BoxDecoration(
        color: ff.tabBar,
        border: Border.all(color: ff.surfaceBorder),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
        boxShadow: [
          for (final s in ff.cardShadow)
            BoxShadow(
              color: s.color,
              blurRadius: s.blurRadius,
              offset: Offset(0, -s.offset.dy.abs() / 2),
            ),
        ],
      ),
      // Narrow outer inset so the 8 tool cells keep 44 pt even at 360 pt.
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        AppSpacing.sm,
        side,
        bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.screen - AppSpacing.md - side,
            ),
            child: _ColourRow(
              colorHex: colorHex,
              onColor: onColor,
              canUndo: canUndo,
              onUndo: onUndo,
              onRedo: onRedo,
            ),
          ),
          Row(
            children: [
              for (final f in NoteFormat.values)
                _ToolButton(
                  icon: f.icon,
                  label: f.label,
                  selected: active.contains(f),
                  onTap: () => onFormat(f),
                ),
              _ToolButton(
                icon: FontAwesomeIcons.solidImage,
                label: 'Add image',
                onTap: onImage,
              ),
              _ToolButton(
                icon: FontAwesomeIcons.microphone,
                label: listening ? 'Stop dictation' : 'Dictate',
                selected: listening,
                onTap: onVoice,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColourRow extends StatelessWidget {
  const _ColourRow({
    required this.colorHex,
    required this.onColor,
    required this.canUndo,
    required this.onUndo,
    required this.onRedo,
  });

  final String? colorHex;
  final ValueChanged<String> onColor;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  /// Swatches + Undo row. Every swatch cell is a full 44 × 44 tap target
  /// (rule 6) around the small visual circle; the "COLOUR" label is
  /// dropped when it doesn't fit, and the swatches scroll sideways on very
  /// narrow screens / large text rather than shrink below 44.
  static const double height = AppSizes.minTap;
  static const double pitch = AppSizes.minTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final brightness = Theme.of(context).brightness;
    final selected = (colorHex ?? NoteColors.hexes.first).toUpperCase();
    final undo = Semantics(
      button: true,
      enabled: canUndo,
      label: 'Undo',
      hint: 'Long-press to redo',
      excludeSemantics: true,
      child: FFPressable(
        onTap: canUndo ? onUndo : null,
        onLongPress: onRedo,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: height,
            minWidth: AppSizes.minTap,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: Opacity(
              opacity: canUndo ? 1 : 0.45,
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
                    'Undo',
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

    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const count = 6;
              final label = Text(
                'COLOUR',
                maxLines: 1,
                style: context.text.sectionLabel.copyWith(
                  fontSize: NoteEditorMetrics.colourLabelSize,
                ),
              );
              final labelWidth = _textWidth(context, label);
              final showLabel =
                  c.maxWidth - labelWidth - 2 * AppSpacing.md >= count * pitch;
              final swatches = [
                for (final hex in NoteColors.hexes)
                  _Swatch(
                    color: NoteColors.background(hex, brightness),
                    selected: hex == selected,
                    white: hex == NoteColors.hexes.first,
                    width: pitch,
                    size: NoteEditorMetrics.swatch,
                    label: _colourName(hex),
                    onTap: () => onColor(hex),
                  ),
              ];
              if (c.maxWidth < count * pitch) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: swatches),
                );
              }
              return Row(
                children: [
                  if (showLabel) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.md,
                      ),
                      child: ExcludeSemantics(child: label),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  ...swatches,
                ],
              );
            },
          ),
        ),
        undo,
      ],
    );
  }

  static double _textWidth(BuildContext context, Text text) {
    final painter = TextPainter(
      text: TextSpan(text: text.data, style: text.style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  static String _colourName(String hex) => switch (hex) {
    'D1FAE5' => 'Mint',
    'FEF3C7' => 'Amber',
    'DBEAFE' => 'Blue',
    'FCE7F3' => 'Pink',
    'EDE9FE' => 'Violet',
    _ => 'White',
  };
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.white,
    required this.width,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool white;
  final double width;
  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label note colour',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: _ColourRow.height,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: ff.success,
                        width: NoteEditorMetrics.swatchSelectedBorder,
                      )
                    : white
                    ? Border.all(color: ff.divider, width: 1.5)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Expanded(
      child: Semantics(
        button: true,
        toggled: selected,
        label: label,
        excludeSemantics: true,
        child: FFPressable(
          onTap: onTap,
          scale: 0.9,
          child: SizedBox(
            height: AppSizes.minTap,
            child: Icon(
              icon,
              size: NoteEditorMetrics.toolIcon,
              color: selected ? ff.success : noteBodyInk(ff),
            ),
          ),
        ),
      ),
    );
  }
}

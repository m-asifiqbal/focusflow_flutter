/// ============================================================
/// NOTE EDITOR TOOLBAR — colours + Undo + hide, formatting buttons
/// ============================================================
///
/// The rounded bottom panel of screen 08 (sits above the keyboard):
///   row 1  "COLOUR" · note colours (scrolls sideways) · Undo · ⌄ hide
///          — or, while "Text colour" is on, "TEXT" · Default · 9 colours
///   row 2  Heading · Bold · Italic · Text colour · Bullets · Numbers ·
///          Checklist · Quote, then Image · Voice pinned at the end. When
///          44-pt cells don't fit, the formats scroll (half a cell peeks
///          out so the scroll is obvious) — Image / Voice never do.
/// Hidden, the panel shrinks to one slim row (Undo · ⌃ show) so the note
/// gets the room. Active formats at the cursor are tinted with the accent.
/// Long-press Undo to redo. Callbacks only — the view applies them to
/// Quill, and rebuilds this panel only when [NoteToolState] changes.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_quill_styles.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_toolbar_parts.dart';

/// Formatting buttons of the toolbar (Text colour / Image / Voice are
/// separate actions).
enum NoteFormat {
  heading(FontAwesomeIcons.heading),
  bold(FontAwesomeIcons.bold),
  italic(FontAwesomeIcons.italic),
  bullets(FontAwesomeIcons.listUl),
  numbered(FontAwesomeIcons.listOl),
  checklist(FontAwesomeIcons.listCheck),
  quote(FontAwesomeIcons.quoteLeft);

  const NoteFormat(this.icon);

  /// Button label in the active language.
  String get label => switch (this) {
    NoteFormat.heading => tr('Heading'),
    NoteFormat.bold => tr('Bold'),
    NoteFormat.italic => tr('Italic'),
    NoteFormat.bullets => tr('Bullet list'),
    NoteFormat.numbered => tr('Numbered list'),
    NoteFormat.checklist => tr('Checklist'),
    NoteFormat.quote => tr('Quote'),
  };

  final IconData icon;
}

/// What the panel shows for the cursor: Undo state, active formats and
/// the text colour (null = default ink). Value-equal, so the panel only
/// rebuilds when one of these actually changes — not on every keystroke.
@immutable
class NoteToolState {
  const NoteToolState({
    this.canUndo = false,
    this.formats = const {},
    this.textColor,
  });

  final bool canUndo;
  final Set<NoteFormat> formats;
  final String? textColor;

  @override
  bool operator ==(Object other) =>
      other is NoteToolState &&
      other.canUndo == canUndo &&
      other.textColor == textColor &&
      setEquals(other.formats, formats);

  @override
  int get hashCode =>
      Object.hash(canUndo, textColor, Object.hashAllUnordered(formats));
}

class NoteEditorToolbar extends StatefulWidget {
  const NoteEditorToolbar({
    required this.colorHex,
    required this.onColor,
    required this.tools,
    required this.onUndo,
    required this.onRedo,
    required this.onFormat,
    required this.onTextColor,
    required this.onImage,
    required this.onVoice,
    required this.collapsed,
    required this.onCollapsed,
    this.listening = false,
    super.key,
  });

  /// Stored note colour (null = white).
  final String? colorHex;
  final ValueChanged<String> onColor;
  final NoteToolState tools;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final ValueChanged<NoteFormat> onFormat;

  /// A text colour was picked (null = back to the default ink).
  final ValueChanged<String?> onTextColor;
  final VoidCallback onImage;
  final VoidCallback onVoice;

  /// Panel hidden (one slim row).
  final bool collapsed;
  final ValueChanged<bool> onCollapsed;

  /// Dictation running (mic tinted, label "Stop dictation").
  final bool listening;

  static const double radius = 26;

  /// Id of the "Default" text-colour swatch.
  static const String defaultInk = 'default';

  @override
  State<NoteEditorToolbar> createState() => _NoteEditorToolbarState();
}

class _NoteEditorToolbarState extends State<NoteEditorToolbar> {
  /// Row 1 shows text colours instead of note colours.
  bool _textMode = false;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    // The icon row sits just above the home indicator (mockup).
    final bottom = math.max(
      AppSpacing.sm,
      MediaQuery.paddingOf(context).bottom - AppSpacing.lg - AppSpacing.xxs,
    );
    final collapsed = widget.collapsed;
    final top = Row(
      children: [
        Expanded(
          child: collapsed
              ? const SizedBox.shrink()
              : AnimatedSwitcher(
                  duration: context.motion(AppMotion.fast),
                  child: _textMode
                      ? _textColours(context)
                      : _noteColours(context),
                ),
        ),
        NoteUndoButton(
          canUndo: widget.tools.canUndo,
          onUndo: widget.onUndo,
          onRedo: widget.onRedo,
        ),
        NotePanelToggle(
          collapsed: collapsed,
          onTap: () => widget.onCollapsed(!collapsed),
        ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: ff.tabBar,
        border: Border.all(color: ff.surfaceBorder),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NoteEditorToolbar.radius),
        ),
        boxShadow: [
          for (final s in ff.cardShadow)
            BoxShadow(
              color: s.color,
              blurRadius: s.blurRadius,
              offset: Offset(0, -s.offset.dy.abs() / 2),
            ),
        ],
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        bottom,
      ),
      child: AnimatedSize(
        duration: context.motion(AppMotion.normal),
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [top, if (!collapsed) _tools(context)],
        ),
      ),
    );
  }

  Widget _noteColours(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return NoteSwatchStrip(
      key: const ValueKey('note-colours'),
      label: tr('COLOUR'),
      selected: (widget.colorHex ?? NoteColors.hexes.first).toUpperCase(),
      onSelect: widget.onColor,
      swatches: [
        for (final hex in NoteColors.hexes)
          NoteSwatchData(
            id: hex,
            color: NoteColors.background(hex, brightness),
            outlined: hex == NoteColors.hexes.first,
            label: tr('{label} note colour', {'label': NoteColors.name(hex)}),
          ),
      ],
    );
  }

  Widget _textColours(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return NoteSwatchStrip(
      key: const ValueKey('text-colours'),
      label: tr('TEXT'),
      selected: widget.tools.textColor ?? NoteEditorToolbar.defaultInk,
      onSelect: (id) =>
          widget.onTextColor(id == NoteEditorToolbar.defaultInk ? null : id),
      swatches: [
        NoteSwatchData(
          id: NoteEditorToolbar.defaultInk,
          color: noteBodyInk(context.ff),
          outlined: true,
          glyph: FontAwesomeIcons.font,
          label: tr('Default text colour'),
        ),
        for (final (value, _, _) in NoteTextColors.swatches)
          NoteSwatchData(
            id: value,
            color: NoteTextColors.display(value, brightness),
            label: tr('{label} text colour', {
              'label': NoteTextColors.name(value),
            }),
          ),
      ],
    );
  }

  Widget _tools(BuildContext context) {
    final ff = context.ff;
    final active = widget.tools.formats;
    final colour = widget.tools.textColor;
    NoteToolButton format(NoteFormat f) => NoteToolButton(
      icon: f.icon,
      label: f.label,
      selected: active.contains(f),
      onTap: () => widget.onFormat(f),
    );
    final formats = [
      format(NoteFormat.heading),
      format(NoteFormat.bold),
      format(NoteFormat.italic),
      NoteToolButton(
        icon: FontAwesomeIcons.font,
        label: tr('Text colour'),
        selected: _textMode,
        bar: colour == null
            ? noteBodyInk(ff)
            : NoteTextColors.display(colour, ff.brightness),
        onTap: () => setState(() => _textMode = !_textMode),
      ),
      format(NoteFormat.bullets),
      format(NoteFormat.numbered),
      format(NoteFormat.checklist),
      format(NoteFormat.quote),
    ];
    // Inserting things stays in reach: Image / Voice never scroll away.
    final pinned = [
      NoteToolButton(
        icon: FontAwesomeIcons.solidImage,
        label: tr('Add image'),
        onTap: widget.onImage,
      ),
      NoteToolButton(
        icon: FontAwesomeIcons.microphone,
        label: widget.listening ? tr('Stop dictation') : tr('Dictate'),
        selected: widget.listening,
        onTap: widget.onVoice,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final all = [...formats, ...pinned];
        if (c.maxWidth >= all.length * AppSizes.minTap) {
          return Row(children: [for (final b in all) Expanded(child: b)]);
        }
        // The formats scroll in ≥ 44-pt cells, sized so half a cell peeks
        // out at the end (the scroll is obvious without a hint).
        final room = c.maxWidth - pinned.length * AppSizes.minTap;
        final fit = (room / AppSizes.minTap - 0.5).floorToDouble();
        final cell = room / (math.max(fit, 1) + 0.5);
        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final b in formats) SizedBox(width: cell, child: b),
                  ],
                ),
              ),
            ),
            for (final b in pinned) SizedBox(width: AppSizes.minTap, child: b),
          ],
        );
      },
    );
  }
}

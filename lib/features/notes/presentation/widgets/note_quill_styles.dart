/// ============================================================
/// NOTE QUILL STYLES — how the note body (Quill) looks on screen 08
/// ============================================================
///
/// Paragraphs 15.5/1.75 Nunito, H3 headings Lexend 18, emerald square
/// checkboxes (checked lines struck through and faded), quote blocks with
/// a 4-pt emerald start border in italics, and rounded image embeds read
/// from the note's attachments. Everything comes from theme tokens, so
/// dark mode and the accent colour work for free.
/// ============================================================
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_metrics.dart';

/// Body sizes of the editor (paragraphs 17/1.7 — a notch above the design
/// spec's 15.5 for comfortable reading; H3 19.5).
abstract final class NoteBodyMetrics {
  static const double fontSize = 17;
  static const double lineHeight = 1.7;
  static const double headingSize = 19.5;
  static const double checkbox = 15;

  /// Leading column of list lines (checkbox + gap).
  static const double listIndent = 24;
  static const double quoteBorder = 4;
  static const double quoteIndent = 13;
}

/// Paragraph ink of the body — softer than titles (mockup).
Color noteBodyInk(FFColors ff) =>
    ff.ink.withValues(alpha: ff.isDark ? 0.82 : 0.74);

/// Quill styles for the note body in the current theme.
DefaultStyles noteQuillStyles(BuildContext context) {
  final ff = context.ff;
  final text = context.text;
  final rtl = Directionality.of(context) == TextDirection.rtl;
  final body = text.body.copyWith(
    fontSize: NoteBodyMetrics.fontSize,
    height: NoteBodyMetrics.lineHeight,
    color: noteBodyInk(ff),
    decoration: TextDecoration.none,
  );
  final heading = text.sectionTitle.copyWith(
    fontSize: NoteBodyMetrics.headingSize,
    height: 1.4,
    color: ff.ink,
  );
  const none = HorizontalSpacing(0, 0);
  final quoteSide = BorderSide(
    width: NoteBodyMetrics.quoteBorder,
    color: ff.success,
  );
  DefaultTextBlockStyle block(TextStyle s, VerticalSpacing v) =>
      DefaultTextBlockStyle(s, none, v, VerticalSpacing.zero, null);

  const p = NoteEditorMetrics.paragraphSpace;
  const headingSpace = VerticalSpacing(
    NoteEditorMetrics.headingSpaceBefore,
    NoteEditorMetrics.headingSpaceAfter,
  );
  final paragraph = block(body, const VerticalSpacing(p, p));
  return DefaultStyles.getInstance(context).merge(
    DefaultStyles(
      paragraph: paragraph,
      h1: block(
        heading.copyWith(fontSize: NoteEditorMetrics.h1Size),
        headingSpace,
      ),
      h2: block(
        heading.copyWith(fontSize: NoteEditorMetrics.h2Size),
        headingSpace,
      ),
      h3: block(
        heading,
        const VerticalSpacing(
          NoteEditorMetrics.h3Space,
          NoteEditorMetrics.h3Space,
        ),
      ),
      bold: TextStyle(fontWeight: FontWeight.w700, color: ff.ink),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
      link: TextStyle(
        color: ff.primary,
        decoration: TextDecoration.underline,
        decorationColor: ff.primary,
      ),
      placeHolder: block(
        body.copyWith(color: ff.inkFaint),
        const VerticalSpacing(p, p),
      ),
      lists: DefaultListBlockStyle(
        body,
        none,
        // Checked / unchecked lines form separate blocks, so the block
        // spacing sets most checklist gaps; lineSpacing applies inside a
        // run of same-kind lines (36-pt pitch, mockup).
        const VerticalSpacing(3, 3),
        const VerticalSpacing(4, 5),
        null,
        NoteCheckboxBuilder(ff),
        indentWidthBuilder: _indentWidth(rtl),
      ),
      quote: DefaultTextBlockStyle(
        body.copyWith(fontStyle: FontStyle.italic, color: ff.inkMuted),
        none,
        const VerticalSpacing(p, p),
        const VerticalSpacing(p, p),
        BoxDecoration(
          border: rtl ? Border(right: quoteSide) : Border(left: quoteSide),
        ),
      ),
      leading: block(body.copyWith(color: ff.inkMuted), VerticalSpacing.zero),
    ),
  );
}

/// List / quote indents of the mockup (Quill's defaults are 2× font size).
LeadingBlockIndentWidth _indentWidth(bool rtl) =>
    (block, context, count, numberPointWidth) {
      final attrs = block.style.attributes;
      final level = (attrs[Attribute.indent.key]?.value as int?) ?? 0;
      final extra = level * NoteBodyMetrics.listIndent;
      final width = attrs.containsKey(Attribute.blockQuote.key)
          ? NoteBodyMetrics.quoteIndent + NoteBodyMetrics.quoteBorder
          : attrs[Attribute.list.key] == Attribute.ol
          ? numberPointWidth(NoteBodyMetrics.fontSize, count)
          : NoteBodyMetrics.listIndent;
      return rtl
          ? HorizontalSpacing(0, width + extra)
          : HorizontalSpacing(width + extra, 0);
    };

/// Checked checklist lines: struck through and faded (line attribute).
TextStyle? noteCustomStyle(Attribute attribute, FFColors ff) {
  if (attribute == Attribute.checked) {
    return TextStyle(
      decoration: TextDecoration.lineThrough,
      decorationColor: ff.inkFaint,
      color: ff.inkFaint,
    );
  }
  return null;
}

/// Emerald square checkbox of checklist lines (radius 4).
///
/// Tap target: Quill lays the leading widget out in the list indent column
/// (24 pt wide × the line height, ~31 pt) and hit-tests it only inside the
/// line, so the opaque detector fills that whole cell — it cannot grow to
/// 44 × 44 without widening the indent past the mockup's 24 pt.
class NoteCheckboxBuilder implements QuillCheckboxBuilder {
  const NoteCheckboxBuilder(this.ff);

  final FFColors ff;

  @override
  Widget build({
    required BuildContext context,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
  }) {
    const size = NoteBodyMetrics.checkbox;
    return Semantics(
      checked: isChecked,
      label: 'Checklist item',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!isChecked),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isChecked ? ff.success : null,
              borderRadius: BorderRadius.circular(AppRadii.tileSm / 2),
              border: Border.all(color: ff.success, width: 2),
            ),
            child: isChecked
                ? Icon(FontAwesomeIcons.check, size: 8, color: ff.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Image embeds (`{"insert": {"image": "attachments/<id>.jpg"}}`) drawn
/// from the app documents directory; a missing file shows a placeholder.
class NoteImageEmbedBuilder extends EmbedBuilder {
  const NoteImageEmbedBuilder(this.resolve);

  /// Relative path → file (null while the store is loading / invalid path).
  final File? Function(String relativePath) resolve;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final ff = context.ff;
    final path = embedContext.node.value.data;
    final file = path is String ? resolve(path) : null;
    final placeholder = Container(
      height: 140,
      color: ff.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(FontAwesomeIcons.image, color: ff.inkFaint, size: 28),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Semantics(
        image: true,
        label: 'Note image',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: file == null
              ? placeholder
              : Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  // Decode at screen width, not at camera resolution: a
                  // 12 MP photo would otherwise be a ~48 MB bitmap.
                  cacheWidth:
                      (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

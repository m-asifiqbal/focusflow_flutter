/// ============================================================
/// FF HIGHLIGHTED TEXT — search-result text with matched terms marked
/// ============================================================
///
/// Every whitespace-separated term of [query] is matched case-insensitively
/// and drawn on a rounded `ff.highlight` background (global search, 06).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class FFHighlightedText extends StatelessWidget {
  const FFHighlightedText(
    this.text, {
    required this.query,
    this.style,
    this.highlightColor,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    super.key,
  });

  final String text;
  final String query;

  /// Defaults to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Defaults to `ff.highlight`.
  final Color? highlightColor;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;

  /// Splits [text] into (segment, isMatch) runs for [query].
  static List<(String, bool)> segments(String text, String query) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (terms.isEmpty || text.isEmpty) return [(text, false)];
    terms.sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(terms.join('|'), caseSensitive: false);
    final out = <(String, bool)>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start == m.end) continue;
      if (m.start > last) out.add((text.substring(last, m.start), false));
      out.add((text.substring(m.start, m.end), true));
      last = m.end;
    }
    if (last < text.length) out.add((text.substring(last), false));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final bg = highlightColor ?? context.ff.highlight;
    final parts = segments(text, query);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final (segment, match) in parts)
            if (!match)
              TextSpan(text: segment)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                // RichText already scales WidgetSpan children by the text
                // scaler, so the inner Text must not scale a second time.
                child: MediaQuery.withNoTextScaling(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      segment,
                      style: base.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: text,
    );
  }
}
